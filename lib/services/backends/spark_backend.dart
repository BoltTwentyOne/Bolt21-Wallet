import 'dart:async';
import 'dart:io';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart' as spark;
import '../../utils/secure_logger.dart';
import 'lightning_backend.dart';

/// Spark backend implementation - Bitcoin-native L2
class SparkBackend implements LightningBackend {
  spark.BreezSdk? _sdk;
  bool _isConnected = false;
  String? _currentWalletId;
  StreamController<BackendEvent>? _eventController;

  @override
  LightningBackendType get backendType => LightningBackendType.spark;

  @override
  String get backendName => 'Spark';

  @override
  bool get supportsBolt12Receive => false; // Spark doesn't support BOLT12 receive yet

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> initialize({
    required String walletId,
    required String mnemonic,
    required String apiKey,
    required String workingDir,
  }) async {
    if (_isConnected && _currentWalletId == walletId) return;
    if (_isConnected) await disconnect();

    try {
      SecureLogger.info('Initializing Spark backend for wallet $walletId...', tag: 'Spark');
      await Directory(workingDir).create(recursive: true);

      final seed = spark.Seed.mnemonic(mnemonic: mnemonic, passphrase: null);
      final config = spark.defaultConfig(network: spark.Network.mainnet);

      final connectRequest = spark.ConnectRequest(
        config: config,
        seed: seed,
        storageDir: workingDir,
        apiKey: apiKey,
      );

      _sdk = await spark.connect(request: connectRequest);
      _isConnected = true;
      _currentWalletId = walletId;
      _setupEventStream();

      SecureLogger.info('Spark backend initialized for wallet $walletId', tag: 'Spark');
    } catch (e, stack) {
      SecureLogger.error('Failed to initialize Spark backend', error: e, stackTrace: stack, tag: 'Spark');
      rethrow;
    }
  }

  void _setupEventStream() {
    _eventController?.close();
    _eventController = StreamController<BackendEvent>.broadcast();

    _sdk?.addEventListener().listen((event) {
      if (event is spark.SdkEvent_PaymentSucceeded) {
        final payment = _convertPayment(event.payment);
        _eventController?.add(payment.direction == PaymentDirection.receive
            ? PaymentReceivedEvent(payment)
            : PaymentSentEvent(payment));
      } else if (event is spark.SdkEvent_PaymentFailed) {
        _eventController?.add(PaymentFailedEvent(_convertPayment(event.payment)));
      } else if (event is spark.SdkEvent_Synced) {
        _eventController?.add(const SyncedEvent());
      }
    });
  }

  @override
  Future<void> disconnect() async {
    if (_sdk != null) {
      await _sdk!.disconnect();
      _sdk = null;
      _isConnected = false;
      _currentWalletId = null;
      _eventController?.close();
      _eventController = null;
    }
  }

  @override
  Future<UnifiedWalletInfo> getWalletInfo() async {
    _ensureConnected();
    final info = await _sdk!.getInfo(request: const spark.GetInfoRequest());
    return UnifiedWalletInfo(balanceSat: info.balanceSats);
  }

  @override
  Future<String> generateBolt11Invoice({required BigInt amountSat, String? description}) async {
    _ensureConnected();
    final request = spark.ReceivePaymentRequest(
      paymentMethod: spark.ReceivePaymentMethod.bolt11Invoice(
        description: description ?? 'Bolt21',
        amountSats: amountSat,
      ),
    );
    final response = await _sdk!.receivePayment(request: request);
    return response.destination;
  }

  @override
  Future<String?> generateBolt12Offer() async => null; // Not supported

  @override
  Future<String> getOnChainAddress() async {
    _ensureConnected();
    final request = spark.ReceivePaymentRequest(
      paymentMethod: spark.ReceivePaymentMethod.bitcoinAddress(),
    );
    final response = await _sdk!.receivePayment(request: request);
    return response.destination;
  }

  @override
  Future<ParsedInput> parseInput(String input) async {
    _ensureConnected();
    final result = await _sdk!.parse(input: input);

    return switch (result) {
      spark.InputType_Bolt11Invoice(field0: final inv) => Bolt11Input(
          invoice: input,
          amountSat: inv.amountMsat != null ? inv.amountMsat! ~/ BigInt.from(1000) : null,
          description: inv.description,
        ),
      spark.InputType_Bolt12Offer(field0: final offer) => Bolt12OfferInput(
          offer: input,
          description: offer.description,
        ),
      spark.InputType_BitcoinAddress(field0: final addr) => BitcoinAddressInput(
          address: addr.address,
          amountSat: addr.amountSat,
        ),
      spark.InputType_LnUrlPay(field0: final data) => LnurlPayInput(
          url: input,
          minSat: data.minSendableSat,
          maxSat: data.maxSendableSat,
          description: data.metadataStr,
        ),
      _ => UnknownInput(input),
    };
  }

  @override
  Future<SendResult> sendPayment({required String destination, BigInt? amountSat}) async {
    _ensureConnected();
    try {
      final prepareRequest = spark.PrepareSendPaymentRequest(
        paymentRequest: destination,
        amount: amountSat,
      );
      final prepareResponse = await _sdk!.prepareSendPayment(request: prepareRequest);
      final sendRequest = spark.SendPaymentRequest(prepareResponse: prepareResponse);
      final response = await _sdk!.sendPayment(request: sendRequest);

      return SendResult.success(
        paymentId: response.payment.id,
        feeSat: response.payment.fees,
      );
    } catch (e) {
      return SendResult.failure(e.toString());
    }
  }

  @override
  Future<List<UnifiedPayment>> listPayments() async {
    _ensureConnected();
    final response = await _sdk!.listPayments(request: const spark.ListPaymentsRequest());
    return response.payments.map(_convertPayment).toList();
  }

  @override
  Stream<BackendEvent> get events {
    _eventController ??= StreamController<BackendEvent>.broadcast();
    return _eventController!.stream;
  }

  @override
  Future<UnifiedFees> getRecommendedFees() async {
    _ensureConnected();
    final fees = await _sdk!.recommendedFees();
    return UnifiedFees(
      fastSatPerVbyte: fees.fastestFee.toInt(),
      mediumSatPerVbyte: fees.halfHourFee.toInt(),
      slowSatPerVbyte: fees.hourFee.toInt(),
    );
  }

  @override
  Future<void> deleteWalletData() async {}

  UnifiedPayment _convertPayment(spark.Payment payment) {
    return UnifiedPayment(
      id: payment.id,
      direction: payment.paymentType == spark.PaymentType.receive
          ? PaymentDirection.receive
          : PaymentDirection.send,
      state: switch (payment.status) {
        spark.PaymentStatus.pending => PaymentState.pending,
        spark.PaymentStatus.completed => PaymentState.complete,
        spark.PaymentStatus.failed => PaymentState.failed,
      },
      amountSat: payment.amount,
      feesSat: payment.fees,
      timestamp: DateTime.fromMillisecondsSinceEpoch(payment.timestamp.toInt() * 1000),
      methodType: switch (payment.details) {
        spark.PaymentDetails_Lightning() => PaymentMethodType.lightning,
        spark.PaymentDetails_Spark() => PaymentMethodType.spark,
        spark.PaymentDetails_Bitcoin() => PaymentMethodType.onchain,
        _ => PaymentMethodType.spark,
      },
    );
  }

  void _ensureConnected() {
    if (!_isConnected || _sdk == null) throw Exception('Spark backend not connected');
  }
}

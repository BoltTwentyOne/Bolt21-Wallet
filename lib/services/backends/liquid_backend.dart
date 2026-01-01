import 'dart:async';
import 'dart:io';
import 'package:flutter_breez_liquid/flutter_breez_liquid.dart' as liquid;
import '../config_service.dart';
import '../../utils/secure_logger.dart';
import 'lightning_backend.dart';

/// Liquid backend implementation using Breez SDK Liquid
///
/// Features:
/// - Wrapped BTC (L-BTC) on Liquid sidechain
/// - Full BOLT12 support (send and receive)
/// - Submarine swaps for Lightning compatibility
/// - Federated security model
class LiquidBackend implements LightningBackend {
  liquid.BreezSdkLiquid? _sdk;
  bool _isConnected = false;
  String? _currentWalletId;
  StreamController<BackendEvent>? _eventController;

  @override
  LightningBackendType get backendType => LightningBackendType.liquid;

  @override
  String get backendName => 'Liquid';

  @override
  bool get supportsBolt12Receive => true;

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

    if (_isConnected) {
      await disconnect();
    }

    try {
      SecureLogger.info('Initializing Liquid backend for wallet $walletId...', tag: 'Liquid');

      // Ensure directory exists
      await Directory(workingDir).create(recursive: true);

      // Get default config
      final defaultCfg = liquid.defaultConfig(
        network: liquid.LiquidNetwork.mainnet,
        breezApiKey: apiKey,
      );

      final config = liquid.Config(
        liquidExplorer: defaultCfg.liquidExplorer,
        bitcoinExplorer: defaultCfg.bitcoinExplorer,
        workingDir: workingDir,
        network: defaultCfg.network,
        paymentTimeoutSec: defaultCfg.paymentTimeoutSec,
        syncServiceUrl: defaultCfg.syncServiceUrl,
        zeroConfMaxAmountSat: defaultCfg.zeroConfMaxAmountSat,
        breezApiKey: defaultCfg.breezApiKey,
        externalInputParsers: defaultCfg.externalInputParsers,
        useDefaultExternalInputParsers: defaultCfg.useDefaultExternalInputParsers,
        onchainFeeRateLeewaySat: defaultCfg.onchainFeeRateLeewaySat,
        assetMetadata: defaultCfg.assetMetadata,
        sideswapApiKey: defaultCfg.sideswapApiKey,
        useMagicRoutingHints: defaultCfg.useMagicRoutingHints,
        onchainSyncPeriodSec: defaultCfg.onchainSyncPeriodSec,
        onchainSyncRequestTimeoutSec: defaultCfg.onchainSyncRequestTimeoutSec,
      );

      final connectRequest = liquid.ConnectRequest(
        mnemonic: mnemonic,
        config: config,
      );

      _sdk = await liquid.connect(req: connectRequest);
      _isConnected = true;
      _currentWalletId = walletId;

      // Setup event stream
      _setupEventStream();

      SecureLogger.info('Liquid backend initialized for wallet $walletId', tag: 'Liquid');
    } catch (e, stack) {
      SecureLogger.error('Failed to initialize Liquid backend', error: e, stackTrace: stack, tag: 'Liquid');
      rethrow;
    }
  }

  void _setupEventStream() {
    _eventController?.close();
    _eventController = StreamController<BackendEvent>.broadcast();

    _sdk?.addEventListener().listen((event) {
      if (event is liquid.SdkEvent_PaymentSucceeded) {
        final payment = _convertPayment(event.details);
        if (payment.direction == PaymentDirection.receive) {
          _eventController?.add(PaymentReceivedEvent(payment));
        } else {
          _eventController?.add(PaymentSentEvent(payment));
        }
      } else if (event is liquid.SdkEvent_PaymentFailed) {
        final payment = _convertPayment(event.details);
        _eventController?.add(PaymentFailedEvent(payment));
      } else if (event is liquid.SdkEvent_Synced) {
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
    final info = await _sdk!.getInfo();
    return UnifiedWalletInfo(
      balanceSat: info.walletInfo.balanceSat,
      pendingReceiveSat: info.walletInfo.pendingReceiveSat,
      pendingSendSat: info.walletInfo.pendingSendSat,
    );
  }

  @override
  Future<String> generateBolt11Invoice({
    required BigInt amountSat,
    String? description,
  }) async {
    _ensureConnected();

    final prepareRequest = liquid.PrepareReceiveRequest(
      paymentMethod: liquid.PaymentMethod.lightning,
      amount: liquid.ReceiveAmount.bitcoin(payerAmountSat: amountSat),
    );

    final prepareResponse = await _sdk!.prepareReceivePayment(req: prepareRequest);

    final receiveRequest = liquid.ReceivePaymentRequest(
      prepareResponse: prepareResponse,
      description: description,
    );

    final response = await _sdk!.receivePayment(req: receiveRequest);
    return response.destination;
  }

  @override
  Future<String?> generateBolt12Offer() async {
    _ensureConnected();

    final prepareRequest = liquid.PrepareReceiveRequest(
      paymentMethod: liquid.PaymentMethod.bolt12Offer,
    );

    final prepareResponse = await _sdk!.prepareReceivePayment(req: prepareRequest);

    final receiveRequest = liquid.ReceivePaymentRequest(
      prepareResponse: prepareResponse,
    );

    final response = await _sdk!.receivePayment(req: receiveRequest);
    return response.destination;
  }

  @override
  Future<String> getOnChainAddress() async {
    _ensureConnected();

    final prepareRequest = liquid.PrepareReceiveRequest(
      paymentMethod: liquid.PaymentMethod.bitcoinAddress,
    );

    final prepareResponse = await _sdk!.prepareReceivePayment(req: prepareRequest);

    final receiveRequest = liquid.ReceivePaymentRequest(
      prepareResponse: prepareResponse,
    );

    final response = await _sdk!.receivePayment(req: receiveRequest);
    return response.destination;
  }

  @override
  Future<ParsedInput> parseInput(String input) async {
    _ensureConnected();
    final result = await _sdk!.parse(input: input);

    return switch (result) {
      liquid.InputType_Bolt11(invoice: final inv) => Bolt11Input(
          invoice: input,
          amountSat: inv.amountMsat != null ? inv.amountMsat! ~/ BigInt.from(1000) : null,
          description: inv.description,
          expiry: inv.expiry,
        ),
      liquid.InputType_Bolt12Offer(offer: final offer) => Bolt12OfferInput(
          offer: input,
          description: offer.description,
          minAmountSat: offer.minAmount?.amountMsat != null
              ? offer.minAmount!.amountMsat! ~/ BigInt.from(1000)
              : null,
        ),
      liquid.InputType_BitcoinAddress(address: final addr) => BitcoinAddressInput(
          address: addr.address,
          amountSat: addr.amountSat,
        ),
      liquid.InputType_LiquidAddress(address: final addr) => BitcoinAddressInput(
          address: addr.address,
          amountSat: addr.amountSat,
        ),
      liquid.InputType_LnUrlPay(data: final data) => LnurlPayInput(
          url: input,
          minSat: data.minSendableSat,
          maxSat: data.maxSendableSat,
          description: data.metadataStr,
        ),
      _ => UnknownInput(input),
    };
  }

  @override
  Future<SendResult> sendPayment({
    required String destination,
    BigInt? amountSat,
  }) async {
    _ensureConnected();

    try {
      final prepareRequest = liquid.PrepareSendRequest(
        destination: destination,
        amount: amountSat != null
            ? liquid.PayAmount.bitcoin(receiverAmountSat: amountSat)
            : null,
      );

      final prepareResponse = await _sdk!.prepareSendPayment(req: prepareRequest);

      final sendRequest = liquid.SendPaymentRequest(
        prepareResponse: prepareResponse,
      );

      final response = await _sdk!.sendPayment(req: sendRequest);

      return SendResult.success(
        paymentId: response.payment.txId,
        feeSat: response.payment.feesSat,
      );
    } catch (e) {
      return SendResult.failure(e.toString());
    }
  }

  @override
  Future<List<UnifiedPayment>> listPayments() async {
    _ensureConnected();
    final request = liquid.ListPaymentsRequest();
    final payments = await _sdk!.listPayments(req: request);
    return payments.map(_convertPayment).toList();
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
  Future<void> deleteWalletData() async {
    // Wallet data is in the working directory, which is managed externally
  }

  UnifiedPayment _convertPayment(liquid.Payment payment) {
    return UnifiedPayment(
      id: payment.txId ?? payment.timestamp.toString(),
      direction: payment.paymentType == liquid.PaymentType.receive
          ? PaymentDirection.receive
          : PaymentDirection.send,
      state: switch (payment.status) {
        liquid.PaymentState.pending => PaymentState.pending,
        liquid.PaymentState.complete => PaymentState.complete,
        liquid.PaymentState.failed => PaymentState.failed,
        _ => PaymentState.pending,
      },
      amountSat: payment.amountSat,
      feesSat: payment.feesSat,
      timestamp: DateTime.fromMillisecondsSinceEpoch(payment.timestamp.toInt() * 1000),
      description: payment.description,
      methodType: switch (payment.details) {
        liquid.PaymentDetails_Lightning() => PaymentMethodType.lightning,
        liquid.PaymentDetails_Liquid() => PaymentMethodType.liquid,
        liquid.PaymentDetails_Bitcoin() => PaymentMethodType.onchain,
        _ => PaymentMethodType.lightning,
      },
    );
  }

  void _ensureConnected() {
    if (!_isConnected || _sdk == null) {
      throw Exception('Liquid backend not connected');
    }
  }
}

/// Abstract interface for Lightning backend implementations
///
/// Bolt21 supports multiple backends:
/// - Liquid: Wrapped BTC (L-BTC), supports BOLT12 receive
/// - Spark: Native BTC, lower fees, no BOLT12 receive yet
///
/// Each wallet chooses its backend at creation time.
library;

/// Backend type enum
enum LightningBackendType {
  liquid,
  spark,
}

/// Unified payment info across backends
class UnifiedPayment {
  final String id;
  final PaymentDirection direction;
  final PaymentState state;
  final BigInt amountSat;
  final BigInt feesSat;
  final DateTime timestamp;
  final String? description;
  final PaymentMethodType methodType;

  UnifiedPayment({
    required this.id,
    required this.direction,
    required this.state,
    required this.amountSat,
    required this.feesSat,
    required this.timestamp,
    this.description,
    required this.methodType,
  });
}

enum PaymentDirection { send, receive }
enum PaymentState { pending, complete, failed }
enum PaymentMethodType { lightning, onchain, spark, liquid }

/// Unified wallet info across backends
class UnifiedWalletInfo {
  final BigInt balanceSat;
  final BigInt pendingReceiveSat;
  final BigInt pendingSendSat;

  UnifiedWalletInfo({
    required this.balanceSat,
    this.pendingReceiveSat = BigInt.zero,
    this.pendingSendSat = BigInt.zero,
  });
}

/// Unified fee recommendations
class UnifiedFees {
  final int fastSatPerVbyte;
  final int mediumSatPerVbyte;
  final int slowSatPerVbyte;

  UnifiedFees({
    required this.fastSatPerVbyte,
    required this.mediumSatPerVbyte,
    required this.slowSatPerVbyte,
  });
}

/// Backend event for payment notifications
sealed class BackendEvent {
  const BackendEvent();
}

class PaymentReceivedEvent extends BackendEvent {
  final UnifiedPayment payment;
  const PaymentReceivedEvent(this.payment);
}

class PaymentSentEvent extends BackendEvent {
  final UnifiedPayment payment;
  const PaymentSentEvent(this.payment);
}

class PaymentFailedEvent extends BackendEvent {
  final UnifiedPayment payment;
  const PaymentFailedEvent(this.payment);
}

class SyncedEvent extends BackendEvent {
  const SyncedEvent();
}

/// Abstract Lightning backend interface
///
/// All backend implementations must implement this interface.
abstract class LightningBackend {
  /// Backend type identifier
  LightningBackendType get backendType;

  /// Human-readable backend name
  String get backendName;

  /// Whether this backend supports BOLT12 receive
  bool get supportsBolt12Receive;

  /// Initialize the backend with wallet credentials
  Future<void> initialize({
    required String walletId,
    required String mnemonic,
    required String apiKey,
    required String workingDir,
  });

  /// Disconnect and cleanup
  Future<void> disconnect();

  /// Check if connected
  bool get isConnected;

  /// Get wallet info (balance, etc.)
  Future<UnifiedWalletInfo> getWalletInfo();

  /// Generate a BOLT11 invoice for receiving
  Future<String> generateBolt11Invoice({
    required BigInt amountSat,
    String? description,
  });

  /// Generate a BOLT12 offer (if supported)
  /// Returns null if not supported by this backend
  Future<String?> generateBolt12Offer();

  /// Get on-chain Bitcoin address for receiving
  Future<String> getOnChainAddress();

  /// Parse any payment input (BOLT11, BOLT12, address, etc.)
  Future<ParsedInput> parseInput(String input);

  /// Send a payment
  Future<SendResult> sendPayment({
    required String destination,
    BigInt? amountSat,
  });

  /// List payment history
  Future<List<UnifiedPayment>> listPayments();

  /// Stream of payment events
  Stream<BackendEvent> get events;

  /// Get recommended fees for on-chain transactions
  Future<UnifiedFees> getRecommendedFees();

  /// Delete wallet data from disk
  Future<void> deleteWalletData();
}

/// Parsed input types
sealed class ParsedInput {
  const ParsedInput();
}

class Bolt11Input extends ParsedInput {
  final String invoice;
  final BigInt? amountSat;
  final String? description;
  final int? expiry;

  const Bolt11Input({
    required this.invoice,
    this.amountSat,
    this.description,
    this.expiry,
  });
}

class Bolt12OfferInput extends ParsedInput {
  final String offer;
  final String? description;
  final BigInt? minAmountSat;

  const Bolt12OfferInput({
    required this.offer,
    this.description,
    this.minAmountSat,
  });
}

class BitcoinAddressInput extends ParsedInput {
  final String address;
  final BigInt? amountSat;
  final String? label;

  const BitcoinAddressInput({
    required this.address,
    this.amountSat,
    this.label,
  });
}

class LightningAddressInput extends ParsedInput {
  final String address;

  const LightningAddressInput({required this.address});
}

class LnurlPayInput extends ParsedInput {
  final String url;
  final BigInt minSat;
  final BigInt maxSat;
  final String? description;

  const LnurlPayInput({
    required this.url,
    required this.minSat,
    required this.maxSat,
    this.description,
  });
}

class UnknownInput extends ParsedInput {
  final String raw;
  const UnknownInput(this.raw);
}

/// Send payment result
class SendResult {
  final bool success;
  final String? paymentId;
  final BigInt? feeSat;
  final String? error;

  SendResult({
    required this.success,
    this.paymentId,
    this.feeSat,
    this.error,
  });

  factory SendResult.success({String? paymentId, BigInt? feeSat}) {
    return SendResult(success: true, paymentId: paymentId, feeSat: feeSat);
  }

  factory SendResult.failure(String error) {
    return SendResult(success: false, error: error);
  }
}

import 'dart:io';
import 'package:bip39/bip39.dart' as bip39;
import 'package:path_provider/path_provider.dart';
import 'backends/lightning_backend.dart';
import 'backends/liquid_backend.dart';
import 'backends/spark_backend.dart';
import 'config_service.dart';
import '../utils/secure_logger.dart';

/// Service for managing Lightning operations across multiple backends
///
/// Bolt21 supports multiple Lightning backends:
/// - Liquid: Wrapped BTC (L-BTC), full BOLT12 support
/// - Spark: Native BTC, lower fees, no BOLT12 receive yet
///
/// Each wallet chooses its backend at creation time and can switch later.
class LightningService {
  LightningBackend? _backend;
  String? _currentWalletId;
  LightningBackendType? _currentBackendType;

  bool get isInitialized => _backend?.isConnected ?? false;
  String? get currentWalletId => _currentWalletId;
  LightningBackendType? get currentBackendType => _currentBackendType;

  /// Whether the current backend supports BOLT12 receive
  bool get supportsBolt12Receive => _backend?.supportsBolt12Receive ?? false;

  /// Initialize the service with a specific backend
  /// [walletId] - Unique wallet identifier for isolated data directory
  /// [mnemonic] - Seed phrase (required for new wallets)
  /// [backendType] - Which backend implementation to use
  Future<void> initialize({
    required String walletId,
    required String mnemonic,
    required LightningBackendType backendType,
  }) async {
    // If already initialized with same wallet and backend, skip
    if (isInitialized &&
        _currentWalletId == walletId &&
        _currentBackendType == backendType) {
      return;
    }

    // If switching wallets or backends, disconnect first
    if (isInitialized &&
        (_currentWalletId != walletId || _currentBackendType != backendType)) {
      await disconnect();
    }

    try {
      // Ensure config is loaded
      await ConfigService.instance.initialize();

      SecureLogger.info(
        'Initializing ${_backendTypeToString(backendType)} backend for wallet $walletId...',
        tag: 'LightningService',
      );

      // Create the appropriate backend instance
      _backend = _createBackend(backendType);
      _currentBackendType = backendType;

      // Get working directory for this wallet and backend
      final directory = await getApplicationDocumentsDirectory();
      final backendName = _backendTypeToString(backendType).toLowerCase();
      final workingDir = '${directory.path}/${backendName}_wallet_$walletId';

      // Initialize the backend
      await _backend!.initialize(
        walletId: walletId,
        mnemonic: mnemonic,
        apiKey: ConfigService.instance.breezApiKey,
        workingDir: workingDir,
      );

      _currentWalletId = walletId;

      SecureLogger.info(
        '${_backendTypeToString(backendType)} backend initialized for wallet $walletId',
        tag: 'LightningService',
      );
    } catch (e, stack) {
      SecureLogger.error(
        'Failed to initialize Lightning service',
        error: e,
        stackTrace: stack,
        tag: 'LightningService',
      );
      rethrow;
    }
  }

  /// Generate a new mnemonic seed phrase (12 words)
  String generateMnemonic() {
    return bip39.generateMnemonic(strength: 128); // 128 bits = 12 words
  }

  /// Get wallet info including balance
  Future<UnifiedWalletInfo> getWalletInfo() async {
    _ensureInitialized();
    return await _backend!.getWalletInfo();
  }

  /// Generate a BOLT11 invoice for receiving
  Future<String> generateBolt11Invoice({
    required BigInt amountSat,
    String? description,
  }) async {
    _ensureInitialized();
    return await _backend!.generateBolt11Invoice(
      amountSat: amountSat,
      description: description,
    );
  }

  /// Generate a BOLT12 offer (reusable payment address)
  /// Returns null if the current backend doesn't support BOLT12 receive
  Future<String?> generateBolt12Offer() async {
    _ensureInitialized();
    return await _backend!.generateBolt12Offer();
  }

  /// Get on-chain Bitcoin address for receiving
  Future<String> getOnChainAddress() async {
    _ensureInitialized();
    return await _backend!.getOnChainAddress();
  }

  /// Parse any payment input (BOLT11, BOLT12, BIP21, Lightning Address, etc.)
  Future<ParsedInput> parseInput(String input) async {
    _ensureInitialized();
    return await _backend!.parseInput(input);
  }

  /// Send a payment (works with BOLT11, BOLT12, Lightning Address, etc.)
  Future<SendResult> sendPayment({
    required String destination,
    BigInt? amountSat,
  }) async {
    _ensureInitialized();
    return await _backend!.sendPayment(
      destination: destination,
      amountSat: amountSat,
    );
  }

  /// List all payments
  Future<List<UnifiedPayment>> listPayments() async {
    _ensureInitialized();
    return await _backend!.listPayments();
  }

  /// Stream of payment events
  Stream<BackendEvent> get events {
    _ensureInitialized();
    return _backend!.events;
  }

  /// Get recommended on-chain fees
  Future<UnifiedFees> getRecommendedFees() async {
    _ensureInitialized();
    return await _backend!.getRecommendedFees();
  }

  /// Disconnect the current backend
  Future<void> disconnect() async {
    if (_backend != null) {
      await _backend!.disconnect();
      _backend = null;
      _currentWalletId = null;
      _currentBackendType = null;
    }
  }

  /// Delete a wallet's data directory from disk
  /// SECURITY: Must be called when deleting a wallet to prevent data remnants
  Future<void> deleteWalletDirectory(String walletId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // Delete directories for all possible backends
      for (final backendType in LightningBackendType.values) {
        final backendName = _backendTypeToString(backendType).toLowerCase();
        final walletDir = Directory('${directory.path}/${backendName}_wallet_$walletId');

        if (await walletDir.exists()) {
          await walletDir.delete(recursive: true);
          SecureLogger.info(
            'Deleted $backendName wallet directory for $walletId',
            tag: 'LightningService',
          );
        }
      }
    } catch (e, stack) {
      SecureLogger.error(
        'Failed to delete wallet directory',
        error: e,
        stackTrace: stack,
        tag: 'LightningService',
      );
      rethrow;
    }
  }

  /// Create a backend instance based on the type
  LightningBackend _createBackend(LightningBackendType type) {
    return switch (type) {
      LightningBackendType.liquid => LiquidBackend(),
      LightningBackendType.spark => SparkBackend(),
    };
  }

  /// Convert backend type to human-readable string
  String _backendTypeToString(LightningBackendType type) {
    return switch (type) {
      LightningBackendType.liquid => 'Liquid',
      LightningBackendType.spark => 'Spark',
    };
  }

  void _ensureInitialized() {
    if (!isInitialized || _backend == null) {
      throw Exception('Lightning service not initialized');
    }
  }
}

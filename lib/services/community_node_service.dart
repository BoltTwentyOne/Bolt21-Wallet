import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';
import '../utils/secure_logger.dart';

/// SECURITY: Safe integer parsing for community node responses
int _safeParseInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) {
    final parsed = int.tryParse(value);
    return parsed ?? defaultValue;
  }
  return defaultValue;
}

/// Service for routing payments through the Bolt21 Community Node
///
/// This allows users to route payments through a community-operated
/// Lightning node for potentially lower fees, with fallback to Breez.
class CommunityNodeService {
  static const _communityNodeUrlKey = 'bolt21_community_node_url';
  static const _communityNodeEnabledKey = 'bolt21_community_node_enabled';

  // Default community node URL
  // Set up community.bolt21.io to point to your node's proxy
  // Users can override this in settings
  static const String defaultNodeUrl = 'https://community.bolt21.io';

  String? _nodeUrl;
  bool _isEnabled = false;
  CommunityNodeStatus? _cachedStatus;

  bool get isEnabled => _isEnabled;
  String? get nodeUrl => _nodeUrl;
  CommunityNodeStatus? get status => _cachedStatus;

  /// Initialize and check if community node is enabled
  Future<void> initialize() async {
    _isEnabled = await SecureStorageService.read(_communityNodeEnabledKey) == 'true';
    _nodeUrl = await SecureStorageService.read(_communityNodeUrlKey) ?? defaultNodeUrl;

    if (_isEnabled) {
      await checkStatus();
    }
  }

  /// Enable community node routing
  Future<void> enable() async {
    await SecureStorageService.write(_communityNodeEnabledKey, 'true');
    _isEnabled = true;
    await checkStatus();
  }

  /// Disable community node routing
  Future<void> disable() async {
    await SecureStorageService.write(_communityNodeEnabledKey, 'false');
    _isEnabled = false;
    _cachedStatus = null;
  }

  /// Set custom node URL (for advanced users)
  /// SECURITY: Validates URL format, enforces HTTPS, blocks private networks
  Future<void> setNodeUrl(String url) async {
    // SECURITY: Validate URL format
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw ArgumentError('Invalid URL format');
    }

    // SECURITY: Enforce HTTPS only (prevent protocol downgrade attacks)
    if (uri.scheme != 'https') {
      throw ArgumentError('Only HTTPS URLs allowed for security');
    }

    // SECURITY: Block localhost and private IP ranges (SSRF protection)
    final host = uri.host.toLowerCase();
    final blockedPatterns = [
      'localhost',
      '127.', '0.0.0.0',
      '192.168.', '10.',
      '172.16.', '172.17.', '172.18.', '172.19.',
      '172.20.', '172.21.', '172.22.', '172.23.',
      '172.24.', '172.25.', '172.26.', '172.27.',
      '172.28.', '172.29.', '172.30.', '172.31.',
      '169.254.', // Link-local
      '::1', '[::1]', // IPv6 localhost
      'fc00:', 'fd00:', // IPv6 private
    ];

    for (final pattern in blockedPatterns) {
      if (host.contains(pattern) || host.startsWith(pattern)) {
        throw ArgumentError('Private network URLs are blocked for security');
      }
    }

    // SECURITY: Validate domain has valid TLD
    if (!host.contains('.') || host.endsWith('.')) {
      throw ArgumentError('Invalid domain name');
    }

    await SecureStorageService.write(_communityNodeUrlKey, url);
    _nodeUrl = url;
    SecureLogger.info('Community node URL updated', tag: 'Community');
  }

  /// Check community node status
  Future<CommunityNodeStatus?> checkStatus() async {
    if (_nodeUrl == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_nodeUrl/status'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // SECURITY: Defensive JSON parsing
        try {
          final json = jsonDecode(response.body);
          if (json is Map<String, dynamic>) {
            _cachedStatus = CommunityNodeStatus.fromJson(json);
            SecureLogger.info('Community node online: ${_cachedStatus?.alias}', tag: 'Community');
            return _cachedStatus;
          }
        } on FormatException catch (e) {
          SecureLogger.warn('Community node: Malformed status response', tag: 'Community');
        }
      }
    } catch (e) {
      SecureLogger.warn('Community node offline: $e', tag: 'Community');
      _cachedStatus = null;
    }

    return null;
  }

  /// Pay invoice via community node
  /// Returns payment result or null if failed
  Future<CommunityPaymentResult?> payInvoice({
    required String invoice,
    int? amountSat,
  }) async {
    if (!_isEnabled || _nodeUrl == null) return null;

    try {
      final body = <String, dynamic>{'invoice': invoice};
      if (amountSat != null) {
        body['amount'] = amountSat;
      }

      final response = await http.post(
        Uri.parse('$_nodeUrl/pay'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 65)); // LND timeout is 60s

      // SECURITY: Defensive JSON parsing
      Map<String, dynamic> json;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          return CommunityPaymentResult(success: false, error: 'Invalid response format');
        }
        json = decoded;
      } on FormatException {
        return CommunityPaymentResult(success: false, error: 'Malformed response');
      }

      if (response.statusCode == 200 && json['success'] == true) {
        // SECURITY: Safe parsing for numeric fields
        final feeSat = _safeParseInt(json['feeSat']);
        final amountSat = _safeParseInt(json['amountSat']);
        SecureLogger.info(
          'Payment via community node: $amountSat sats (fee: $feeSat)',
          tag: 'Community',
        );
        return CommunityPaymentResult(
          success: true,
          paymentHash: json['paymentHash']?.toString(),
          feeSat: feeSat,
          amountSat: amountSat,
        );
      } else {
        SecureLogger.warn('Community node payment failed: ${json['error']}', tag: 'Community');
        return CommunityPaymentResult(
          success: false,
          error: json['error']?.toString() ?? 'Unknown error',
        );
      }
    } catch (e) {
      SecureLogger.warn('Community node request failed: $e', tag: 'Community');
      return null; // Return null to trigger fallback
    }
  }

  /// Generate invoice via community node
  Future<String?> createInvoice({
    required int amountSat,
    String? memo,
  }) async {
    if (!_isEnabled || _nodeUrl == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_nodeUrl/invoice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amountSat,
          'memo': memo ?? 'Bolt21',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // SECURITY: Defensive JSON parsing
        try {
          final json = jsonDecode(response.body);
          if (json is Map<String, dynamic>) {
            return json['invoice']?.toString();
          }
        } on FormatException {
          SecureLogger.warn('Community node: Malformed invoice response', tag: 'Community');
        }
      }
    } catch (e) {
      SecureLogger.warn('Community node invoice failed: $e', tag: 'Community');
    }

    return null;
  }
}

/// Community node status info
class CommunityNodeStatus {
  final bool online;
  final String? alias;
  final int channels;
  final int spendable;
  final int receivable;
  final int feeRatePpm;

  CommunityNodeStatus({
    required this.online,
    this.alias,
    this.channels = 0,
    this.spendable = 0,
    this.receivable = 0,
    this.feeRatePpm = 0,
  });

  factory CommunityNodeStatus.fromJson(Map<String, dynamic> json) {
    // SECURITY: Safe parsing for all numeric fields
    return CommunityNodeStatus(
      online: json['online'] == true,
      alias: json['alias']?.toString(),
      channels: _safeParseInt(json['channels']),
      spendable: _safeParseInt(json['spendable']),
      receivable: _safeParseInt(json['receivable']),
      feeRatePpm: _safeParseInt(json['feeRatePpm']),
    );
  }
}

/// Result of a community node payment
class CommunityPaymentResult {
  final bool success;
  final String? paymentHash;
  final int feeSat;
  final int amountSat;
  final String? error;

  CommunityPaymentResult({
    required this.success,
    this.paymentHash,
    this.feeSat = 0,
    this.amountSat = 0,
    this.error,
  });
}

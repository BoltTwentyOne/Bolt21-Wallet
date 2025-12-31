import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/secure_logger.dart';

/// Service for fetching Bitcoin price
class PriceService {
  static final PriceService instance = PriceService._();
  PriceService._();

  double? _btcPriceUsd;
  DateTime? _lastFetch;

  double? get btcPriceUsd => _btcPriceUsd;

  /// Fetch current BTC price in USD
  Future<void> fetchBtcPrice() async {
    // Cache for 5 minutes
    if (_lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < const Duration(minutes: 5)) {
      return;
    }

    try {
      // Use CoinGecko API (free, no API key needed)
      final response = await http.get(
        Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newPrice = (data['bitcoin']['usd'] as num).toDouble();

        // SECURITY: Sanity check - reject extreme price changes (likely MITM)
        if (_btcPriceUsd != null) {
          final percentChange = ((newPrice - _btcPriceUsd!) / _btcPriceUsd!).abs();
          if (percentChange > 0.5) {
            SecureLogger.warn(
              'Price change too large (${(percentChange * 100).toStringAsFixed(1)}%), possible manipulation',
              tag: 'Price',
            );
            return; // Keep old price, don't trust suspicious data
          }
        }

        // SECURITY: Absolute bounds check (reject obviously fake prices)
        if (newPrice < 1000 || newPrice > 10000000) {
          SecureLogger.warn('BTC price out of realistic range: \$$newPrice', tag: 'Price');
          return;
        }

        _btcPriceUsd = newPrice;
        _lastFetch = DateTime.now();
        SecureLogger.info('BTC price updated: \$$_btcPriceUsd', tag: 'Price');
      }
    } catch (e) {
      SecureLogger.warn('Failed to fetch BTC price: $e', tag: 'Price');
      // Keep old price if fetch fails
    }
  }

  /// Convert sats to USD
  double? satsToUsd(int sats) {
    if (_btcPriceUsd == null) return null;
    return (sats / 100000000) * _btcPriceUsd!;
  }

  /// Convert USD to sats
  int? usdToSats(double usd) {
    if (_btcPriceUsd == null) return null;
    return ((usd / _btcPriceUsd!) * 100000000).round();
  }

  /// Convert sats to BTC
  double satsToBtc(int sats) {
    return sats / 100000000;
  }

  /// Format BTC value
  String formatBtc(double btc) {
    if (btc >= 1) {
      return '${btc.toStringAsFixed(4)} BTC';
    } else if (btc >= 0.001) {
      return '${(btc * 1000).toStringAsFixed(4)} mBTC';
    } else {
      return '${(btc * 100000000).toInt()} sats';
    }
  }

  /// Format USD value
  String formatUsd(double usd) {
    return '\$${usd.toStringAsFixed(2)}';
  }
}

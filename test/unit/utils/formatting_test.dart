import 'package:flutter_test/flutter_test.dart';

/// Formatting utility tests
/// Tests number formatting, currency display, and string formatting

void main() {
  group('Satoshi Formatting', () {
    String formatSats(int sats) {
      if (sats < 1000) return '$sats';
      if (sats < 1000000) return '${(sats / 1000).toStringAsFixed(sats % 1000 == 0 ? 0 : 1)}k';
      if (sats < 1000000000) return '${(sats / 1000000).toStringAsFixed(sats % 1000000 == 0 ? 0 : 2)}M';
      return '${(sats / 1000000000).toStringAsFixed(2)}B';
    }

    test('formats small amounts without suffix', () {
      expect(formatSats(0), equals('0'));
      expect(formatSats(1), equals('1'));
      expect(formatSats(100), equals('100'));
      expect(formatSats(999), equals('999'));
    });

    test('formats thousands with k suffix', () {
      expect(formatSats(1000), equals('1k'));
      expect(formatSats(5000), equals('5k'));
      expect(formatSats(10000), equals('10k'));
      expect(formatSats(50000), equals('50k'));
      expect(formatSats(100000), equals('100k'));
      expect(formatSats(999000), equals('999k'));
    });

    test('formats millions with M suffix', () {
      expect(formatSats(1000000), equals('1M'));
      expect(formatSats(5000000), equals('5M'));
      expect(formatSats(100000000), equals('100M')); // 1 BTC
      expect(formatSats(500000000), equals('500M'));
    });

    test('formats billions with B suffix', () {
      expect(formatSats(1000000000), equals('1.00B'));
      expect(formatSats(2100000000000000), equals('2100000.00B')); // 21M BTC
    });
  });

  group('BTC Formatting', () {
    String formatBtc(int sats) {
      final btc = sats / 100000000;
      if (btc >= 1) return '${btc.toStringAsFixed(8)} BTC';
      if (btc >= 0.001) return '${(btc * 1000).toStringAsFixed(5)} mBTC';
      return '$sats sats';
    }

    test('formats sats for small amounts', () {
      expect(formatBtc(1), equals('1 sats'));
      expect(formatBtc(100), equals('100 sats'));
      expect(formatBtc(99999), equals('99999 sats'));
    });

    test('formats mBTC for medium amounts', () {
      expect(formatBtc(100000), equals('1.00000 mBTC'));
      expect(formatBtc(500000), equals('5.00000 mBTC'));
      expect(formatBtc(1000000), equals('10.00000 mBTC'));
    });

    test('formats BTC for large amounts', () {
      expect(formatBtc(100000000), equals('1.00000000 BTC'));
      expect(formatBtc(500000000), equals('5.00000000 BTC'));
      expect(formatBtc(2100000000000000), equals('21000000.00000000 BTC'));
    });
  });

  group('USD Formatting', () {
    String formatUsd(double amount) {
      if (amount >= 1000000) {
        return '\$${(amount / 1000000).toStringAsFixed(2)}M';
      }
      if (amount >= 1000) {
        return '\$${(amount / 1000).toStringAsFixed(2)}k';
      }
      return '\$${amount.toStringAsFixed(2)}';
    }

    test('formats small amounts', () {
      expect(formatUsd(0.00), equals('\$0.00'));
      expect(formatUsd(0.50), equals('\$0.50'));
      expect(formatUsd(1.00), equals('\$1.00'));
      expect(formatUsd(9.99), equals('\$9.99'));
      expect(formatUsd(100.00), equals('\$100.00'));
      expect(formatUsd(999.99), equals('\$999.99'));
    });

    test('formats thousands', () {
      expect(formatUsd(1000.00), equals('\$1.00k'));
      expect(formatUsd(5000.00), equals('\$5.00k'));
      expect(formatUsd(50000.00), equals('\$50.00k'));
      expect(formatUsd(999999.99), equals('\$1000.00k'));
    });

    test('formats millions', () {
      expect(formatUsd(1000000.00), equals('\$1.00M'));
      expect(formatUsd(5000000.00), equals('\$5.00M'));
    });
  });

  group('Number with Commas', () {
    String formatWithCommas(int number) {
      final str = number.toString();
      final result = StringBuffer();
      for (int i = 0; i < str.length; i++) {
        if (i > 0 && (str.length - i) % 3 == 0) {
          result.write(',');
        }
        result.write(str[i]);
      }
      return result.toString();
    }

    test('formats numbers under 1000 without commas', () {
      expect(formatWithCommas(0), equals('0'));
      expect(formatWithCommas(1), equals('1'));
      expect(formatWithCommas(100), equals('100'));
      expect(formatWithCommas(999), equals('999'));
    });

    test('formats thousands with single comma', () {
      expect(formatWithCommas(1000), equals('1,000'));
      expect(formatWithCommas(9999), equals('9,999'));
    });

    test('formats millions with two commas', () {
      expect(formatWithCommas(1000000), equals('1,000,000'));
      expect(formatWithCommas(9999999), equals('9,999,999'));
    });

    test('formats billions with three commas', () {
      expect(formatWithCommas(1000000000), equals('1,000,000,000'));
    });

    test('formats max sats', () {
      expect(formatWithCommas(2100000000000000), equals('2,100,000,000,000,000'));
    });
  });

  group('Time Formatting', () {
    String formatDuration(Duration duration) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final seconds = duration.inSeconds % 60;

      if (hours > 0) {
        return '${hours}h ${minutes}m';
      }
      if (minutes > 0) {
        return '${minutes}:${seconds.toString().padLeft(2, '0')}';
      }
      return '${seconds}s';
    }

    test('formats seconds only', () {
      expect(formatDuration(const Duration(seconds: 5)), equals('5s'));
      expect(formatDuration(const Duration(seconds: 30)), equals('30s'));
      expect(formatDuration(const Duration(seconds: 59)), equals('59s'));
    });

    test('formats minutes and seconds', () {
      expect(formatDuration(const Duration(minutes: 1)), equals('1:00'));
      expect(formatDuration(const Duration(minutes: 1, seconds: 30)), equals('1:30'));
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), equals('59:59'));
    });

    test('formats hours and minutes', () {
      expect(formatDuration(const Duration(hours: 1)), equals('1h 0m'));
      expect(formatDuration(const Duration(hours: 1, minutes: 30)), equals('1h 30m'));
      expect(formatDuration(const Duration(hours: 24)), equals('24h 0m'));
    });
  });

  group('Date Formatting', () {
    String formatRelativeTime(DateTime dateTime) {
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) return 'just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      if (difference.inDays < 30) return '${difference.inDays ~/ 7}w ago';
      if (difference.inDays < 365) return '${difference.inDays ~/ 30}mo ago';
      return '${difference.inDays ~/ 365}y ago';
    }

    test('formats just now', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now.subtract(const Duration(seconds: 30))), equals('just now'));
    });

    test('formats minutes ago', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now.subtract(const Duration(minutes: 5))), equals('5m ago'));
      expect(formatRelativeTime(now.subtract(const Duration(minutes: 30))), equals('30m ago'));
    });

    test('formats hours ago', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now.subtract(const Duration(hours: 2))), equals('2h ago'));
      expect(formatRelativeTime(now.subtract(const Duration(hours: 12))), equals('12h ago'));
    });

    test('formats days ago', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now.subtract(const Duration(days: 1))), equals('1d ago'));
      expect(formatRelativeTime(now.subtract(const Duration(days: 5))), equals('5d ago'));
    });

    test('formats weeks ago', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now.subtract(const Duration(days: 7))), equals('1w ago'));
      expect(formatRelativeTime(now.subtract(const Duration(days: 21))), equals('3w ago'));
    });

    test('formats months ago', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now.subtract(const Duration(days: 30))), equals('1mo ago'));
      expect(formatRelativeTime(now.subtract(const Duration(days: 180))), equals('6mo ago'));
    });

    test('formats years ago', () {
      final now = DateTime.now();
      expect(formatRelativeTime(now.subtract(const Duration(days: 365))), equals('1y ago'));
      expect(formatRelativeTime(now.subtract(const Duration(days: 730))), equals('2y ago'));
    });
  });

  group('Address Truncation', () {
    String truncateAddress(String address, {int prefixLength = 8, int suffixLength = 6}) {
      if (address.length <= prefixLength + suffixLength + 3) return address;
      return '${address.substring(0, prefixLength)}...${address.substring(address.length - suffixLength)}';
    }

    test('truncates long addresses', () {
      const address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
      expect(truncateAddress(address), equals('bc1qar0s...wf5mdq'));
    });

    test('does not truncate short addresses', () {
      const address = 'bc1qshort';
      expect(truncateAddress(address), equals(address));
    });

    test('uses custom prefix/suffix lengths', () {
      const address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
      expect(truncateAddress(address, prefixLength: 4, suffixLength: 4), equals('bc1q...5mdq'));
    });
  });

  group('Invoice Truncation', () {
    String truncateInvoice(String invoice, {int maxLength = 30}) {
      if (invoice.length <= maxLength) return invoice;
      return '${invoice.substring(0, maxLength)}...';
    }

    test('truncates long invoices', () {
      const invoice = 'lnbc1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg';
      expect(truncateInvoice(invoice), equals('lnbc1pvjluezsp5zyg3zyg3zyg3zyg...'));
    });

    test('does not truncate short invoices', () {
      const invoice = 'lnbc1pvjluez';
      expect(truncateInvoice(invoice), equals(invoice));
    });
  });

  group('Hash Formatting', () {
    String formatHash(String hash, {int visibleChars = 8}) {
      if (hash.length <= visibleChars * 2) return hash;
      return '${hash.substring(0, visibleChars)}...${hash.substring(hash.length - visibleChars)}';
    }

    test('formats payment hash', () {
      const hash = 'abc123def456abc123def456abc123def456abc123def456abc123def456abcd';
      expect(formatHash(hash), equals('abc123de...f456abcd'));
    });

    test('handles short hashes', () {
      const hash = 'abc123';
      expect(formatHash(hash), equals('abc123'));
    });
  });

  group('Fee Rate Formatting', () {
    String formatFeeRate(int satPerVbyte) {
      return '$satPerVbyte sat/vB';
    }

    String formatFeePpm(int ppm) {
      final percent = ppm / 10000;
      return '${percent.toStringAsFixed(2)}%';
    }

    test('formats sat/vB rate', () {
      expect(formatFeeRate(1), equals('1 sat/vB'));
      expect(formatFeeRate(10), equals('10 sat/vB'));
      expect(formatFeeRate(100), equals('100 sat/vB'));
    });

    test('formats ppm to percentage', () {
      expect(formatFeePpm(100), equals('0.01%'));
      expect(formatFeePpm(1000), equals('0.10%'));
      expect(formatFeePpm(10000), equals('1.00%'));
    });
  });
}

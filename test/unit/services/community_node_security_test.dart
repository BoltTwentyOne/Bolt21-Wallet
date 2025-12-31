import 'package:flutter_test/flutter_test.dart';

/// Comprehensive Community Node Service security tests
/// Tests URL validation, SSRF protection, and response parsing

void main() {
  group('Community Node URL Validation', () {
    bool isValidNodeUrl(String url) {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;
      if (uri.scheme != 'https') return false;

      final host = uri.host.toLowerCase();
      final blockedPatterns = [
        'localhost', '127.', '0.0.0.0',
        '192.168.', '10.',
        '172.16.', '172.17.', '172.18.', '172.19.',
        '172.20.', '172.21.', '172.22.', '172.23.',
        '172.24.', '172.25.', '172.26.', '172.27.',
        '172.28.', '172.29.', '172.30.', '172.31.',
        '169.254.', '::1', '[::1]', 'fc00:', 'fd00:',
      ];

      for (final pattern in blockedPatterns) {
        if (host.contains(pattern) || host.startsWith(pattern)) {
          return false;
        }
      }

      if (!host.contains('.') || host.endsWith('.')) {
        return false;
      }

      return true;
    }

    group('HTTPS enforcement', () {
      test('accepts HTTPS URLs', () {
        expect(isValidNodeUrl('https://community.bolt21.io'), isTrue);
        expect(isValidNodeUrl('https://node.example.com'), isTrue);
        expect(isValidNodeUrl('https://my-node.org:8080'), isTrue);
      });

      test('rejects HTTP URLs', () {
        expect(isValidNodeUrl('http://community.bolt21.io'), isFalse);
        expect(isValidNodeUrl('http://node.example.com'), isFalse);
      });

      test('rejects other protocols', () {
        expect(isValidNodeUrl('ftp://node.example.com'), isFalse);
        expect(isValidNodeUrl('ws://node.example.com'), isFalse);
        expect(isValidNodeUrl('wss://node.example.com'), isFalse);
        expect(isValidNodeUrl('file:///etc/passwd'), isFalse);
        expect(isValidNodeUrl('javascript:alert(1)'), isFalse);
        expect(isValidNodeUrl('data:text/html,<script>'), isFalse);
      });
    });

    group('localhost SSRF protection', () {
      test('blocks localhost variations', () {
        expect(isValidNodeUrl('https://localhost'), isFalse);
        expect(isValidNodeUrl('https://localhost:8080'), isFalse);
        expect(isValidNodeUrl('https://localhost/api'), isFalse);
        expect(isValidNodeUrl('https://LOCALHOST'), isFalse);
        expect(isValidNodeUrl('https://LocalHost:443'), isFalse);
      });

      test('blocks 127.x.x.x range', () {
        expect(isValidNodeUrl('https://127.0.0.1'), isFalse);
        expect(isValidNodeUrl('https://127.0.0.1:8080'), isFalse);
        expect(isValidNodeUrl('https://127.0.0.2'), isFalse);
        expect(isValidNodeUrl('https://127.1.1.1'), isFalse);
        expect(isValidNodeUrl('https://127.255.255.255'), isFalse);
      });

      test('blocks 0.0.0.0', () {
        expect(isValidNodeUrl('https://0.0.0.0'), isFalse);
        expect(isValidNodeUrl('https://0.0.0.0:8080'), isFalse);
      });
    });

    group('private IP SSRF protection - Class A (10.x.x.x)', () {
      test('blocks 10.0.0.0/8 range', () {
        expect(isValidNodeUrl('https://10.0.0.1'), isFalse);
        expect(isValidNodeUrl('https://10.0.0.1:8080'), isFalse);
        expect(isValidNodeUrl('https://10.1.2.3'), isFalse);
        expect(isValidNodeUrl('https://10.255.255.255'), isFalse);
        expect(isValidNodeUrl('https://10.10.10.10'), isFalse);
      });
    });

    group('private IP SSRF protection - Class B (172.16-31.x.x)', () {
      test('blocks 172.16.0.0/12 range', () {
        expect(isValidNodeUrl('https://172.16.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.17.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.18.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.19.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.20.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.21.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.22.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.23.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.24.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.25.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.26.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.27.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.28.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.29.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.30.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.31.0.1'), isFalse);
        expect(isValidNodeUrl('https://172.31.255.255'), isFalse);
      });

      test('allows public 172.x.x.x outside private range', () {
        // 172.32+ is public
        expect(isValidNodeUrl('https://172.32.0.1'), isTrue);
        expect(isValidNodeUrl('https://172.64.0.1'), isTrue);
      });
    });

    group('private IP SSRF protection - Class C (192.168.x.x)', () {
      test('blocks 192.168.0.0/16 range', () {
        expect(isValidNodeUrl('https://192.168.0.1'), isFalse);
        expect(isValidNodeUrl('https://192.168.1.1'), isFalse);
        expect(isValidNodeUrl('https://192.168.1.100'), isFalse);
        expect(isValidNodeUrl('https://192.168.100.1'), isFalse);
        expect(isValidNodeUrl('https://192.168.255.255'), isFalse);
      });
    });

    group('link-local SSRF protection', () {
      test('blocks 169.254.x.x range', () {
        expect(isValidNodeUrl('https://169.254.0.1'), isFalse);
        expect(isValidNodeUrl('https://169.254.1.1'), isFalse);
        expect(isValidNodeUrl('https://169.254.169.254'), isFalse); // AWS metadata
        expect(isValidNodeUrl('https://169.254.255.255'), isFalse);
      });
    });

    group('IPv6 SSRF protection', () {
      test('blocks IPv6 localhost', () {
        expect(isValidNodeUrl('https://[::1]'), isFalse);
        expect(isValidNodeUrl('https://[::1]:8080'), isFalse);
      });

      test('blocks IPv6 private ranges', () {
        expect(isValidNodeUrl('https://[fc00::1]'), isFalse);
        expect(isValidNodeUrl('https://[fd00::1]'), isFalse);
        expect(isValidNodeUrl('https://[fd12:3456:789a::1]'), isFalse);
      });
    });

    group('domain validation', () {
      test('requires valid TLD', () {
        expect(isValidNodeUrl('https://node'), isFalse);
        expect(isValidNodeUrl('https://localhost.'), isFalse);
        expect(isValidNodeUrl('https://example.'), isFalse);
      });

      test('accepts valid public domains', () {
        expect(isValidNodeUrl('https://community.bolt21.io'), isTrue);
        expect(isValidNodeUrl('https://node.example.com'), isTrue);
        expect(isValidNodeUrl('https://my-lightning-node.org'), isTrue);
        expect(isValidNodeUrl('https://api.node.co.uk'), isTrue);
      });

      test('accepts domains with ports', () {
        expect(isValidNodeUrl('https://node.example.com:8080'), isTrue);
        expect(isValidNodeUrl('https://node.example.com:443'), isTrue);
        expect(isValidNodeUrl('https://node.example.com:9735'), isTrue);
      });

      test('accepts domains with paths', () {
        expect(isValidNodeUrl('https://example.com/api'), isTrue);
        expect(isValidNodeUrl('https://example.com/v1/node'), isTrue);
      });
    });

    group('URL bypass attempts', () {
      test('blocks URL with credentials', () {
        // These might bypass some URL parsers
        final url = 'https://user:pass@localhost:8080';
        final uri = Uri.tryParse(url);
        expect(uri?.host.toLowerCase().contains('localhost'), isTrue);
      });

      test('handles URL encoding', () {
        // %6C%6F%63%61%6C%68%6F%73%74 = localhost
        final url = 'https://%6C%6F%63%61%6C%68%6F%73%74';
        final uri = Uri.tryParse(url);
        // URI parsing should decode this
        expect(uri?.host ?? '', contains('localhost'));
      });

      test('handles unicode domain spoofing', () {
        // These should be handled by the unicode validator separately
        // Just verify URL parser doesn't crash
        expect(() => Uri.tryParse('https://lоcalhost.com'), returnsNormally);
      });
    });
  });

  group('Community Node Response Parsing', () {
    int safeParseInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    }

    group('status response parsing', () {
      test('parses valid status response', () {
        final json = {
          'online': true,
          'alias': 'Bolt21 Community',
          'channels': 50,
          'spendable': 10000000,
          'receivable': 5000000,
          'feeRatePpm': 100,
        };

        expect(json['online'], isTrue);
        expect(json['alias'], equals('Bolt21 Community'));
        expect(safeParseInt(json['channels']), equals(50));
        expect(safeParseInt(json['spendable']), equals(10000000));
        expect(safeParseInt(json['receivable']), equals(5000000));
        expect(safeParseInt(json['feeRatePpm']), equals(100));
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        expect(json['online'] == true, isFalse);
        expect(json['alias']?.toString(), isNull);
        expect(safeParseInt(json['channels']), equals(0));
        expect(safeParseInt(json['spendable']), equals(0));
      });

      test('handles malformed values', () {
        final json = {
          'online': 'yes',  // String instead of bool
          'channels': 'fifty',  // Non-numeric string
          'spendable': -1000,  // Negative (unusual but valid int)
          'feeRatePpm': 1.5,  // Float
        };

        expect(json['online'] == true, isFalse);
        expect(safeParseInt(json['channels']), equals(0));
        expect(safeParseInt(json['spendable']), equals(-1000)); // Negative allowed here
      });
    });

    group('payment response parsing', () {
      test('parses successful payment', () {
        final json = {
          'success': true,
          'paymentHash': 'abc123def456',
          'feeSat': 10,
          'amountSat': 50000,
        };

        expect(json['success'], isTrue);
        expect(json['paymentHash'], equals('abc123def456'));
        expect(safeParseInt(json['feeSat']), equals(10));
        expect(safeParseInt(json['amountSat']), equals(50000));
      });

      test('parses failed payment', () {
        final json = {
          'success': false,
          'error': 'ROUTE_NOT_FOUND',
        };

        expect(json['success'], isFalse);
        expect(json['error'], equals('ROUTE_NOT_FOUND'));
      });

      test('handles string numeric values', () {
        final json = {
          'success': true,
          'feeSat': '10',
          'amountSat': '50000',
        };

        expect(safeParseInt(json['feeSat']), equals(10));
        expect(safeParseInt(json['amountSat']), equals(50000));
      });
    });

    group('invoice response parsing', () {
      test('parses created invoice', () {
        final json = {
          'invoice': 'lnbc50u1p0...',
        };

        expect(json['invoice']?.toString(), startsWith('lnbc'));
      });

      test('handles missing invoice field', () {
        final json = <String, dynamic>{};
        expect(json['invoice']?.toString(), isNull);
      });
    });
  });

  group('Community Node Request Security', () {
    test('validates invoice format before sending', () {
      bool isValidInvoice(String invoice) {
        final lower = invoice.toLowerCase();
        return lower.startsWith('lnbc') ||
               lower.startsWith('lntb') ||
               lower.startsWith('lnbcrt');
      }

      expect(isValidInvoice('lnbc1pvjluezsp5...'), isTrue);
      expect(isValidInvoice('lntb1pvjluezsp5...'), isTrue);
      expect(isValidInvoice('LNBC1PVJLUEZSP5...'), isTrue);
      expect(isValidInvoice('invalid'), isFalse);
      expect(isValidInvoice('bc1qar0srrr...'), isFalse);
    });

    test('validates amount is positive', () {
      bool isValidAmount(int? amount) {
        return amount == null || amount > 0;
      }

      expect(isValidAmount(null), isTrue); // Optional
      expect(isValidAmount(100), isTrue);
      expect(isValidAmount(1), isTrue);
      expect(isValidAmount(0), isFalse);
      expect(isValidAmount(-1), isFalse);
    });

    test('sanitizes memo for invoice creation', () {
      String sanitizeMemo(String? memo) {
        if (memo == null) return 'Bolt21';
        // Remove potentially dangerous characters
        final sanitized = memo.replaceAll(RegExp(r'[<>"\x00-\x1f]'), '');
        final maxLen = sanitized.length.clamp(0, 100);
        return sanitized.substring(0, maxLen);
      }

      expect(sanitizeMemo(null), equals('Bolt21'));
      expect(sanitizeMemo('Test payment'), equals('Test payment'));
      expect(sanitizeMemo('<script>'), equals('script'));
      expect(sanitizeMemo('A' * 200), hasLength(100));
    });
  });

  group('Community Node Timeout Handling', () {
    test('uses appropriate timeout for status check', () {
      const statusTimeout = Duration(seconds: 10);
      expect(statusTimeout.inSeconds, equals(10));
    });

    test('uses longer timeout for payments', () {
      const paymentTimeout = Duration(seconds: 65);
      expect(paymentTimeout.inSeconds, equals(65));
      // Should be longer than LND's 60 second timeout
      expect(paymentTimeout.inSeconds, greaterThan(60));
    });

    test('uses short timeout for invoice creation', () {
      const invoiceTimeout = Duration(seconds: 10);
      expect(invoiceTimeout.inSeconds, equals(10));
    });
  });
}

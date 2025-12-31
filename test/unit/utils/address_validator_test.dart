import 'package:flutter_test/flutter_test.dart';

/// Comprehensive Address Validator tests
/// Tests unicode attack prevention, format validation, and input sanitization

void main() {
  group('Unicode Lookalike Detection', () {
    bool containsUnicodeLookalikes(String input) {
      final dangerousPatterns = RegExp(
        r'[\u0400-\u04FF'  // Cyrillic
        r'\u0370-\u03FF'   // Greek
        r'\u200B-\u200F'   // Zero-width spaces
        r'\u202A-\u202E'   // RTL/LTR overrides
        r'\u2060-\u2064'   // Invisible operators
        r'\uFEFF'          // BOM
        r'\u00A0'          // Non-breaking space
        r'\u3000'          // Ideographic space
        r']'
      );
      return dangerousPatterns.hasMatch(input);
    }

    group('Cyrillic lookalikes', () {
      test('detects Cyrillic а (U+0430) vs Latin a', () {
        expect(containsUnicodeLookalikes('а'), isTrue); // Cyrillic
        expect(containsUnicodeLookalikes('a'), isFalse); // Latin
      });

      test('detects Cyrillic е (U+0435) vs Latin e', () {
        expect(containsUnicodeLookalikes('е'), isTrue);
        expect(containsUnicodeLookalikes('e'), isFalse);
      });

      test('detects Cyrillic о (U+043E) vs Latin o', () {
        expect(containsUnicodeLookalikes('о'), isTrue);
        expect(containsUnicodeLookalikes('o'), isFalse);
      });

      test('detects Cyrillic с (U+0441) vs Latin c', () {
        expect(containsUnicodeLookalikes('с'), isTrue);
        expect(containsUnicodeLookalikes('c'), isFalse);
      });

      test('detects Cyrillic р (U+0440) vs Latin p', () {
        expect(containsUnicodeLookalikes('р'), isTrue);
        expect(containsUnicodeLookalikes('p'), isFalse);
      });

      test('detects mixed Cyrillic in otherwise Latin string', () {
        expect(containsUnicodeLookalikes('lnbс1pvjluez'), isTrue); // с is Cyrillic
        expect(containsUnicodeLookalikes('lnbc1pvjluez'), isFalse); // All Latin
      });

      test('detects Cyrillic capital letters', () {
        expect(containsUnicodeLookalikes('А'), isTrue); // Cyrillic A
        expect(containsUnicodeLookalikes('A'), isFalse); // Latin A
        expect(containsUnicodeLookalikes('В'), isTrue); // Cyrillic V (looks like B)
        expect(containsUnicodeLookalikes('Н'), isTrue); // Cyrillic N (looks like H)
      });
    });

    group('Greek lookalikes', () {
      test('detects Greek α (U+03B1) vs Latin a', () {
        expect(containsUnicodeLookalikes('α'), isTrue);
        expect(containsUnicodeLookalikes('a'), isFalse);
      });

      test('detects Greek ο (U+03BF) vs Latin o', () {
        expect(containsUnicodeLookalikes('ο'), isTrue);
        expect(containsUnicodeLookalikes('o'), isFalse);
      });

      test('detects Greek ρ (U+03C1) vs Latin p', () {
        expect(containsUnicodeLookalikes('ρ'), isTrue);
        expect(containsUnicodeLookalikes('p'), isFalse);
      });
    });

    group('invisible characters', () {
      test('detects zero-width space (U+200B)', () {
        expect(containsUnicodeLookalikes('abc\u200Bdef'), isTrue);
        expect(containsUnicodeLookalikes('abcdef'), isFalse);
      });

      test('detects zero-width non-joiner (U+200C)', () {
        expect(containsUnicodeLookalikes('abc\u200Cdef'), isTrue);
      });

      test('detects zero-width joiner (U+200D)', () {
        expect(containsUnicodeLookalikes('abc\u200Ddef'), isTrue);
      });

      test('detects left-to-right mark (U+200E)', () {
        expect(containsUnicodeLookalikes('abc\u200Edef'), isTrue);
      });

      test('detects right-to-left mark (U+200F)', () {
        expect(containsUnicodeLookalikes('abc\u200Fdef'), isTrue);
      });
    });

    group('directional overrides', () {
      test('detects left-to-right embedding (U+202A)', () {
        expect(containsUnicodeLookalikes('abc\u202Adef'), isTrue);
      });

      test('detects right-to-left embedding (U+202B)', () {
        expect(containsUnicodeLookalikes('abc\u202Bdef'), isTrue);
      });

      test('detects pop directional formatting (U+202C)', () {
        expect(containsUnicodeLookalikes('abc\u202Cdef'), isTrue);
      });

      test('detects left-to-right override (U+202D)', () {
        expect(containsUnicodeLookalikes('abc\u202Ddef'), isTrue);
      });

      test('detects right-to-left override (U+202E)', () {
        expect(containsUnicodeLookalikes('abc\u202Edef'), isTrue);
      });

      test('detects RTL attack that reverses display', () {
        // This would display "moc.rekcatta" as "attacker.com"
        final rtlAttack = '\u202Emoc.rekcatta\u202C';
        expect(containsUnicodeLookalikes(rtlAttack), isTrue);
      });
    });

    group('other invisible operators', () {
      test('detects word joiner (U+2060)', () {
        expect(containsUnicodeLookalikes('abc\u2060def'), isTrue);
      });

      test('detects function application (U+2061)', () {
        expect(containsUnicodeLookalikes('abc\u2061def'), isTrue);
      });

      test('detects invisible separator (U+2063)', () {
        expect(containsUnicodeLookalikes('abc\u2063def'), isTrue);
      });

      test('detects BOM (U+FEFF)', () {
        expect(containsUnicodeLookalikes('\uFEFFabc'), isTrue);
        expect(containsUnicodeLookalikes('abc\uFEFF'), isTrue);
      });

      test('detects non-breaking space (U+00A0)', () {
        expect(containsUnicodeLookalikes('abc\u00A0def'), isTrue);
        expect(containsUnicodeLookalikes('abc def'), isFalse); // Regular space OK
      });
    });

    group('valid ASCII addresses', () {
      test('accepts valid Bitcoin addresses', () {
        expect(containsUnicodeLookalikes('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'), isFalse);
        expect(containsUnicodeLookalikes('1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2'), isFalse);
        expect(containsUnicodeLookalikes('3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy'), isFalse);
      });

      test('accepts valid BOLT11 invoices', () {
        expect(containsUnicodeLookalikes('lnbc1pvjluezsp5zyg3zyg3zyg'), isFalse);
        expect(containsUnicodeLookalikes('lntb1pvjluezsp5zyg3zyg3zyg'), isFalse);
      });

      test('accepts valid BOLT12 offers', () {
        expect(containsUnicodeLookalikes('lno1qgsyxjtl6luzd9t3pr62xr7eemp6awnejusgf6gw45q75vcfqqqqqqq'), isFalse);
      });

      test('accepts alphanumeric strings', () {
        expect(containsUnicodeLookalikes('abc123XYZ'), isFalse);
        expect(containsUnicodeLookalikes('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'), isFalse);
      });
    });
  });

  group('Payment Type Detection', () {
    String? detectPaymentType(String input) {
      final lower = input.toLowerCase().trim();
      if (lower.startsWith('lno')) {
        return 'BOLT12 Offer';
      } else if (lower.startsWith('lnbc') || lower.startsWith('lntb') || lower.startsWith('lnbcrt')) {
        return 'BOLT11 Invoice';
      } else if (lower.startsWith('bitcoin:') || lower.startsWith('bc1') ||
                 lower.startsWith('1') || lower.startsWith('3')) {
        return 'On-chain';
      }
      return null;
    }

    group('BOLT12 offers', () {
      test('detects lno prefix', () {
        expect(detectPaymentType('lno1qgsyxjtl6luzd9t3pr62xr7eemp6awnejusgf6gw45q75vcfqqqqqqq'), equals('BOLT12 Offer'));
      });

      test('handles uppercase', () {
        expect(detectPaymentType('LNO1QGSYXJTL6...'), equals('BOLT12 Offer'));
      });

      test('handles whitespace', () {
        expect(detectPaymentType('  lno1qgsyxjtl6...  '), equals('BOLT12 Offer'));
      });
    });

    group('BOLT11 invoices', () {
      test('detects mainnet invoices (lnbc)', () {
        expect(detectPaymentType('lnbc1pvjluezsp5zyg3zyg3zyg'), equals('BOLT11 Invoice'));
      });

      test('detects testnet invoices (lntb)', () {
        expect(detectPaymentType('lntb1pvjluezsp5zyg3zyg3zyg'), equals('BOLT11 Invoice'));
      });

      test('detects regtest invoices (lnbcrt)', () {
        expect(detectPaymentType('lnbcrt1pvjluezsp5zyg3zyg3zyg'), equals('BOLT11 Invoice'));
      });

      test('handles uppercase', () {
        expect(detectPaymentType('LNBC1PVJLUEZSP5...'), equals('BOLT11 Invoice'));
      });
    });

    group('On-chain addresses', () {
      test('detects bech32 addresses (bc1)', () {
        expect(detectPaymentType('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'), equals('On-chain'));
      });

      test('detects P2PKH addresses (1...)', () {
        expect(detectPaymentType('1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2'), equals('On-chain'));
      });

      test('detects P2SH addresses (3...)', () {
        expect(detectPaymentType('3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy'), equals('On-chain'));
      });

      test('detects BIP21 URIs', () {
        expect(detectPaymentType('bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'), equals('On-chain'));
        expect(detectPaymentType('bitcoin:1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2?amount=1'), equals('On-chain'));
      });
    });

    group('unknown formats', () {
      test('returns null for empty input', () {
        expect(detectPaymentType(''), isNull);
        expect(detectPaymentType('   '), isNull);
      });

      test('returns null for invalid prefixes', () {
        expect(detectPaymentType('invalid'), isNull);
        expect(detectPaymentType('http://example.com'), isNull);
        expect(detectPaymentType('lightning:lnbc...'), isNull);
      });
    });
  });

  group('Address Sanitization', () {
    String sanitizeAddress(String input) {
      // Remove control characters except newlines
      return input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '').trim();
    }

    test('removes null bytes', () {
      expect(sanitizeAddress('abc\x00def'), equals('abcdef'));
    });

    test('removes control characters', () {
      expect(sanitizeAddress('abc\x01\x02\x03def'), equals('abcdef'));
      expect(sanitizeAddress('\x07bell'), equals('bell'));
    });

    test('removes DEL character', () {
      expect(sanitizeAddress('abc\x7Fdef'), equals('abcdef'));
    });

    test('preserves newlines and tabs', () {
      // We might want to preserve these in some contexts
      expect(sanitizeAddress('abc\ndef'), equals('abc\ndef'));
      expect(sanitizeAddress('abc\tdef'), equals('abc\tdef'));
    });

    test('trims whitespace', () {
      expect(sanitizeAddress('  abc  '), equals('abc'));
      expect(sanitizeAddress('\t\nabc\n\t'), equals('abc'));
    });

    test('handles normal addresses unchanged', () {
      const address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
      expect(sanitizeAddress(address), equals(address));
    });
  });

  group('QR Code Validation', () {
    String? validateQrCode(String? rawValue) {
      if (rawValue == null || rawValue.isEmpty) return null;

      const maxLength = 4096;
      if (rawValue.length > maxLength) return null;

      // Check for dangerous unicode
      final dangerousPatterns = RegExp(r'[\u0400-\u04FF\u0370-\u03FF\u200B-\u200F\u202A-\u202E]');
      if (dangerousPatterns.hasMatch(rawValue)) return null;

      // Sanitize control characters
      final sanitized = rawValue.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

      return sanitized.trim();
    }

    test('rejects null input', () {
      expect(validateQrCode(null), isNull);
    });

    test('rejects empty input', () {
      expect(validateQrCode(''), isNull);
    });

    test('rejects oversized QR codes (>4KB)', () {
      final oversized = 'a' * 5000;
      expect(validateQrCode(oversized), isNull);
    });

    test('accepts normal-sized QR codes', () {
      final normal = 'lnbc1' + 'a' * 300;
      expect(validateQrCode(normal), isNotNull);
      expect(validateQrCode(normal)!.length, equals(normal.length));
    });

    test('rejects Cyrillic lookalikes', () {
      expect(validateQrCode('lnbс1pvjluez'), isNull); // с is Cyrillic
    });

    test('rejects RTL override attacks', () {
      expect(validateQrCode('bc1q\u202Eattacker'), isNull);
    });

    test('rejects zero-width characters', () {
      expect(validateQrCode('bc1q\u200Babcd'), isNull);
    });

    test('sanitizes control characters', () {
      final result = validateQrCode('bc1q\x00\x01abcd');
      expect(result, equals('bc1qabcd'));
    });

    test('trims whitespace', () {
      expect(validateQrCode('  bc1qabcd  '), equals('bc1qabcd'));
    });
  });

  group('Amount Validation', () {
    BigInt? validateAmount(String input) {
      final trimmed = input.trim();
      if (!RegExp(r'^\d+$').hasMatch(trimmed)) return null;

      final parsed = BigInt.tryParse(trimmed);
      if (parsed == null || parsed <= BigInt.zero) return null;

      const maxSats = 2100000000000000;
      if (parsed > BigInt.from(maxSats)) return null;

      return parsed;
    }

    group('valid amounts', () {
      test('accepts 1 sat (minimum)', () {
        expect(validateAmount('1'), equals(BigInt.one));
      });

      test('accepts typical amounts', () {
        expect(validateAmount('100'), equals(BigInt.from(100)));
        expect(validateAmount('50000'), equals(BigInt.from(50000)));
        expect(validateAmount('1000000'), equals(BigInt.from(1000000)));
      });

      test('accepts 21M BTC in sats (maximum)', () {
        expect(validateAmount('2100000000000000'), equals(BigInt.from(2100000000000000)));
      });
    });

    group('invalid amounts', () {
      test('rejects zero', () {
        expect(validateAmount('0'), isNull);
      });

      test('rejects negative amounts', () {
        expect(validateAmount('-1'), isNull);
        expect(validateAmount('-100'), isNull);
      });

      test('rejects amounts exceeding 21M BTC', () {
        expect(validateAmount('2100000000000001'), isNull);
        expect(validateAmount('9999999999999999999'), isNull);
      });

      test('rejects empty input', () {
        expect(validateAmount(''), isNull);
        expect(validateAmount('   '), isNull);
      });
    });

    group('injection prevention', () {
      test('rejects letters', () {
        expect(validateAmount('100abc'), isNull);
        expect(validateAmount('abc100'), isNull);
        expect(validateAmount('abc'), isNull);
      });

      test('rejects special characters', () {
        expect(validateAmount('100!'), isNull);
        expect(validateAmount('100@#'), isNull);
        expect(validateAmount(r'$100'), isNull);
      });

      test('rejects decimals', () {
        expect(validateAmount('100.50'), isNull);
        expect(validateAmount('1.0'), isNull);
        expect(validateAmount('.5'), isNull);
      });

      test('rejects scientific notation', () {
        expect(validateAmount('1e10'), isNull);
        expect(validateAmount('1E6'), isNull);
      });

      test('rejects SQL injection', () {
        expect(validateAmount("1; DROP TABLE"), isNull);
        expect(validateAmount("1' OR '1'='1"), isNull);
      });

      test('rejects XSS attempts', () {
        expect(validateAmount('<script>'), isNull);
        expect(validateAmount('100<img src=x>'), isNull);
      });

      test('rejects unit suffixes', () {
        expect(validateAmount('100 sats'), isNull);
        expect(validateAmount('100sats'), isNull);
        expect(validateAmount('1 BTC'), isNull);
      });
    });
  });
}

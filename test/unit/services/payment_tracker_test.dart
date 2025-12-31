import 'package:flutter_test/flutter_test.dart';

/// Payment Tracker Service tests
/// Tests cumulative payment tracking for biometric bypass prevention

void main() {
  group('Payment Tracker - Biometric Threshold', () {
    const biometricThresholdSats = 100000;
    const windowDurationMs = 5 * 60 * 1000; // 5 minutes

    // Simulating PaymentTrackerService
    List<Map<String, dynamic>> payments = [];

    void recordPayment(int amount) {
      payments.add({
        'amount': amount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }

    void pruneOldPayments(int currentTimeMs) {
      payments.removeWhere((p) =>
        currentTimeMs - (p['timestamp'] as int) > windowDurationMs
      );
    }

    int getCumulativeAmount() {
      return payments.fold(0, (sum, p) => sum + (p['amount'] as int));
    }

    bool shouldRequireBiometric(int newAmount) {
      if (newAmount >= biometricThresholdSats) return true;
      final cumulative = getCumulativeAmount();
      return (cumulative + newAmount) >= biometricThresholdSats;
    }

    setUp(() {
      payments = [];
    });

    group('single payment threshold', () {
      test('requires biometric for payment >= 100k sats', () {
        expect(shouldRequireBiometric(100000), isTrue);
        expect(shouldRequireBiometric(100001), isTrue);
        expect(shouldRequireBiometric(500000), isTrue);
        expect(shouldRequireBiometric(1000000), isTrue);
      });

      test('does not require biometric for payment < 100k sats', () {
        expect(shouldRequireBiometric(99999), isFalse);
        expect(shouldRequireBiometric(50000), isFalse);
        expect(shouldRequireBiometric(1000), isFalse);
        expect(shouldRequireBiometric(1), isFalse);
      });

      test('boundary: exactly 100k requires biometric', () {
        expect(shouldRequireBiometric(100000), isTrue);
      });

      test('boundary: 99,999 does not require biometric', () {
        expect(shouldRequireBiometric(99999), isFalse);
      });
    });

    group('cumulative tracking', () {
      test('tracks payments within window', () {
        recordPayment(30000);
        expect(getCumulativeAmount(), equals(30000));

        recordPayment(40000);
        expect(getCumulativeAmount(), equals(70000));

        recordPayment(20000);
        expect(getCumulativeAmount(), equals(90000));
      });

      test('triggers biometric when cumulative exceeds threshold', () {
        recordPayment(50000);
        expect(shouldRequireBiometric(50000), isTrue); // 50k + 50k = 100k
      });

      test('triggers biometric on third payment pushing over threshold', () {
        recordPayment(30000);
        expect(shouldRequireBiometric(30000), isFalse); // 30k + 30k = 60k

        recordPayment(30000);
        expect(shouldRequireBiometric(30000), isFalse); // 60k + 30k = 90k

        recordPayment(30000);
        expect(shouldRequireBiometric(15000), isTrue); // 90k + 15k = 105k
      });
    });

    group('split payment attack prevention', () {
      test('detects split payment attack: 10 x 10k in window', () {
        // Attacker tries to bypass by splitting 100k into 10 x 10k payments
        for (int i = 0; i < 9; i++) {
          recordPayment(10000);
        }
        expect(getCumulativeAmount(), equals(90000));
        expect(shouldRequireBiometric(10000), isTrue); // 90k + 10k = 100k
      });

      test('detects split payment attack: 5 x 20k', () {
        for (int i = 0; i < 4; i++) {
          recordPayment(20000);
        }
        expect(getCumulativeAmount(), equals(80000));
        expect(shouldRequireBiometric(20000), isTrue); // 80k + 20k = 100k
      });

      test('detects split payment attack: 2 x 50k', () {
        recordPayment(50000);
        expect(shouldRequireBiometric(50000), isTrue);
      });

      test('detects attack just under individual threshold', () {
        recordPayment(99000);
        expect(shouldRequireBiometric(99000), isTrue); // 99k + 99k = 198k
      });
    });

    group('window expiration', () {
      test('prunes payments older than window', () {
        // Simulate old payments
        final now = DateTime.now().millisecondsSinceEpoch;
        payments.add({'amount': 50000, 'timestamp': now - windowDurationMs - 1000});

        pruneOldPayments(now);
        expect(getCumulativeAmount(), equals(0));
      });

      test('keeps payments within window', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        payments.add({'amount': 50000, 'timestamp': now - (windowDurationMs ~/ 2)});

        pruneOldPayments(now);
        expect(getCumulativeAmount(), equals(50000));
      });

      test('resets after window expires', () {
        final now = DateTime.now().millisecondsSinceEpoch;

        // Add payment at edge of window
        payments.add({'amount': 90000, 'timestamp': now - windowDurationMs + 1000});

        pruneOldPayments(now);
        expect(getCumulativeAmount(), equals(90000));
        expect(shouldRequireBiometric(10000), isTrue);

        // Wait for window to expire
        pruneOldPayments(now + 2000);
        expect(getCumulativeAmount(), equals(0));
        expect(shouldRequireBiometric(10000), isFalse);
      });
    });

    group('edge cases', () {
      test('handles zero amount', () {
        expect(shouldRequireBiometric(0), isFalse);
      });

      test('handles very small amounts', () {
        expect(shouldRequireBiometric(1), isFalse);
        recordPayment(1);
        expect(getCumulativeAmount(), equals(1));
      });

      test('handles maximum sats (21M BTC)', () {
        expect(shouldRequireBiometric(2100000000000000), isTrue);
      });

      test('handles rapid sequential payments', () {
        for (int i = 0; i < 100; i++) {
          recordPayment(1000);
        }
        expect(getCumulativeAmount(), equals(100000));
        expect(shouldRequireBiometric(1), isTrue);
      });

      test('tracks after threshold triggered and reset', () {
        recordPayment(50000);
        recordPayment(50000);
        expect(getCumulativeAmount(), equals(100000));

        // Clear all payments (simulating window reset)
        payments.clear();
        expect(getCumulativeAmount(), equals(0));
        expect(shouldRequireBiometric(50000), isFalse);
      });
    });

    group('concurrent payment handling', () {
      test('correctly sums overlapping payments', () {
        final now = DateTime.now().millisecondsSinceEpoch;

        // Payments at different times within window
        payments.add({'amount': 25000, 'timestamp': now - 240000}); // 4 min ago
        payments.add({'amount': 25000, 'timestamp': now - 180000}); // 3 min ago
        payments.add({'amount': 25000, 'timestamp': now - 120000}); // 2 min ago
        payments.add({'amount': 25000, 'timestamp': now - 60000});  // 1 min ago

        pruneOldPayments(now);
        expect(getCumulativeAmount(), equals(100000));
        expect(shouldRequireBiometric(1), isTrue);
      });
    });
  });

  group('Payment Tracker - Record Keeping', () {
    test('records payment amount correctly', () {
      final payments = <int>[];
      void record(int amt) => payments.add(amt);

      record(50000);
      record(25000);
      record(10000);

      expect(payments, equals([50000, 25000, 10000]));
      expect(payments.fold(0, (a, b) => a + b), equals(85000));
    });

    test('maintains order of payments', () {
      final payments = <int>[];
      [100, 200, 300, 400, 500].forEach(payments.add);

      expect(payments.first, equals(100));
      expect(payments.last, equals(500));
    });
  });
}

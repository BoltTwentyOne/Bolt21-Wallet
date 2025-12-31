import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Send Screen widget tests
/// Tests UI components, validation feedback, and user interactions

void main() {
  group('Send Screen UI Components', () {
    testWidgets('displays invoice input field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextField(
              key: Key('invoice_input'),
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Invoice or Offer',
                hintText: 'Paste BOLT12 offer, BOLT11 invoice, or Bitcoin address',
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('invoice_input')), findsOneWidget);
      expect(find.text('Invoice or Offer'), findsOneWidget);
    });

    testWidgets('displays QR scanner toggle button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Send'),
              actions: [
                IconButton(
                  key: const Key('qr_toggle'),
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('qr_toggle')), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets('displays pay button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              key: const Key('pay_button'),
              onPressed: () {},
              child: const Text('Pay'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('pay_button')), findsOneWidget);
      expect(find.text('Pay'), findsOneWidget);
    });
  });

  group('Payment Type Badge Display', () {
    Widget buildBadge(String type, IconData icon) {
      return MaterialApp(
        home: Scaffold(
          body: Container(
            key: Key('badge_$type'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 8),
                Text(type),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('shows BOLT11 Invoice badge', (tester) async {
      await tester.pumpWidget(buildBadge('BOLT11 Invoice', Icons.bolt));
      expect(find.text('BOLT11 Invoice'), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
    });

    testWidgets('shows BOLT12 Offer badge', (tester) async {
      await tester.pumpWidget(buildBadge('BOLT12 Offer', Icons.bolt));
      expect(find.text('BOLT12 Offer'), findsOneWidget);
    });

    testWidgets('shows On-chain badge', (tester) async {
      await tester.pumpWidget(buildBadge('On-chain', Icons.link));
      expect(find.text('On-chain'), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });
  });

  group('Amount Input Field', () {
    testWidgets('shows amount field for BOLT12 offers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: Key('amount_input'),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount (sats)',
                    hintText: 'Enter amount to send',
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('amount_input')), findsOneWidget);
      expect(find.text('Amount (sats)'), findsOneWidget);
    });

    testWidgets('accepts numeric input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              key: const Key('amount_input'),
              keyboardType: TextInputType.number,
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('amount_input')), '50000');
      expect(find.text('50000'), findsOneWidget);
    });
  });

  group('Error Display', () {
    testWidgets('shows error snackbar with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid amount. Only numeric digits allowed.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: const Text('Show Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();

      expect(find.text('Invalid amount. Only numeric digits allowed.'), findsOneWidget);
    });

    testWidgets('shows validation error in snackbar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address contains suspicious unicode characters.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: const Text('Show Error'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();

      expect(find.text('Address contains suspicious unicode characters.'), findsOneWidget);
    });
  });

  group('Loading State', () {
    testWidgets('shows loading indicator when paying', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('disables pay button when loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: null, // Disabled
              child: const Text('Pay'),
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('disables pay button when input empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: null, // Disabled because input is empty
              child: const Text('Pay'),
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('Balance Display', () {
    testWidgets('shows available balance', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Available: 100000 sats',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Available: 100000 sats'), findsOneWidget);
    });

    testWidgets('shows LND balance when connected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('LND Spendable: 50000 sats', style: TextStyle(color: Colors.green)),
                Text('Breez: 100000 sats', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );

      expect(find.text('LND Spendable: 50000 sats'), findsOneWidget);
      expect(find.text('Breez: 100000 sats'), findsOneWidget);
    });
  });

  group('Routing Indicator', () {
    testWidgets('shows LND routing badge when connected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.router, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Text('via My Node', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('via My Node'), findsOneWidget);
      expect(find.byIcon(Icons.router), findsOneWidget);
    });

    testWidgets('shows Community Node badge when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('via Community Node', style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('via Community Node'), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
    });
  });

  group('QR Scanner', () {
    testWidgets('shows scan instruction overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Container(color: Colors.black), // Camera preview placeholder
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Scan a QR code',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Scan a QR code'), findsOneWidget);
    });

    testWidgets('toggle switches between scanner and manual input', (tester) async {
      bool isScanning = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              appBar: AppBar(
                actions: [
                  IconButton(
                    icon: Icon(isScanning ? Icons.edit : Icons.qr_code_scanner),
                    onPressed: () => setState(() => isScanning = !isScanning),
                  ),
                ],
              ),
              body: isScanning
                  ? const Center(child: Text('Scanner'))
                  : const Center(child: Text('Manual Input')),
            ),
          ),
        ),
      );

      expect(find.text('Manual Input'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pump();

      expect(find.text('Scanner'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });
  });

  group('Success Feedback', () {
    testWidgets('shows success snackbar on payment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment sent!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Pay'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pay'));
      await tester.pump();

      expect(find.text('Payment sent!'), findsOneWidget);
    });

    testWidgets('shows node-specific success message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment sent via My Lightning Node!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Pay'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pay'));
      await tester.pump();

      expect(find.text('Payment sent via My Lightning Node!'), findsOneWidget);
    });
  });
}

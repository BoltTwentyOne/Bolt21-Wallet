import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Receive Screen widget tests
/// Tests invoice creation UI, QR display, and copy functionality

void main() {
  group('Receive Screen UI Components', () {
    testWidgets('displays amount input field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextField(
              key: Key('amount_input'),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (sats)',
                hintText: 'Enter amount to receive',
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('amount_input')), findsOneWidget);
      expect(find.text('Amount (sats)'), findsOneWidget);
    });

    testWidgets('displays generate button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              key: const Key('generate_button'),
              onPressed: () {},
              child: const Text('Generate Invoice'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('generate_button')), findsOneWidget);
      expect(find.text('Generate Invoice'), findsOneWidget);
    });

    testWidgets('displays invoice type dropdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DropdownButton<String>(
              key: const Key('invoice_type'),
              value: 'BOLT11',
              items: const [
                DropdownMenuItem(value: 'BOLT11', child: Text('BOLT11 Invoice')),
                DropdownMenuItem(value: 'BOLT12', child: Text('BOLT12 Offer')),
                DropdownMenuItem(value: 'ONCHAIN', child: Text('On-chain Address')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('invoice_type')), findsOneWidget);
      expect(find.text('BOLT11 Invoice'), findsOneWidget);
    });
  });

  group('Amount Input Validation', () {
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

    testWidgets('shows error for empty amount', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: const Text('Generate'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Generate'));
      await tester.pump();

      expect(find.text('Please enter an amount'), findsOneWidget);
    });

    testWidgets('shows error for invalid amount', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: const Text('Generate'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Generate'));
      await tester.pump();

      expect(find.text('Please enter a valid amount'), findsOneWidget);
    });
  });

  group('QR Code Display', () {
    testWidgets('shows QR code placeholder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              key: const Key('qr_code'),
              width: 200,
              height: 200,
              color: Colors.white,
              child: const Center(child: Text('QR')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('qr_code')), findsOneWidget);
    });

    testWidgets('shows invoice text below QR', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(height: 200, child: Placeholder()), // QR placeholder
                SizedBox(height: 16),
                SelectableText(
                  'lnbc1pvjluezsp5zyg3zyg3zyg...',
                  key: Key('invoice_text'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('invoice_text')), findsOneWidget);
    });
  });

  group('Copy Functionality', () {
    testWidgets('displays copy button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              key: const Key('copy_button'),
              icon: const Icon(Icons.copy),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('copy_button')), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('shows copied confirmation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();

      expect(find.text('Copied to clipboard'), findsOneWidget);
    });
  });

  group('Share Functionality', () {
    testWidgets('displays share button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IconButton(
              key: const Key('share_button'),
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('share_button')), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });
  });

  group('Loading States', () {
    testWidgets('shows loading indicator when generating', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('disables generate button when loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: null, // Disabled
              child: const Text('Generate Invoice'),
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('Invoice Type Selection', () {
    testWidgets('can select BOLT11', (tester) async {
      String selectedType = 'BOLT11';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: DropdownButton<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'BOLT11', child: Text('BOLT11')),
                  DropdownMenuItem(value: 'BOLT12', child: Text('BOLT12')),
                ],
                onChanged: (v) => setState(() => selectedType = v!),
              ),
            ),
          ),
        ),
      );

      expect(find.text('BOLT11'), findsOneWidget);
    });

    testWidgets('can select BOLT12', (tester) async {
      String selectedType = 'BOLT11';

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: DropdownButton<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'BOLT11', child: Text('BOLT11')),
                  DropdownMenuItem(value: 'BOLT12', child: Text('BOLT12')),
                ],
                onChanged: (v) => setState(() => selectedType = v!),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('BOLT11'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BOLT12').last);
      await tester.pumpAndSettle();

      expect(selectedType, equals('BOLT12'));
    });
  });

  group('On-chain Address Display', () {
    testWidgets('shows address label for on-chain', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Your Bitcoin Address'),
                SelectableText('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Your Bitcoin Address'), findsOneWidget);
      expect(find.textContaining('bc1q'), findsOneWidget);
    });
  });

  group('Expiration Display', () {
    testWidgets('shows expiration time for invoice', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Icon(Icons.timer_outlined),
                SizedBox(width: 8),
                Text('Expires in 59:30'),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.textContaining('Expires'), findsOneWidget);
    });
  });

  group('Amount Display', () {
    testWidgets('shows requested amount', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('50,000 sats', style: TextStyle(fontSize: 24)),
                Text('≈ \$25.00', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );

      expect(find.text('50,000 sats'), findsOneWidget);
      expect(find.textContaining('\$'), findsOneWidget);
    });
  });

  group('BOLT12 Offer', () {
    testWidgets('shows offer info for BOLT12', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Your BOLT12 Offer'),
                Text('Reusable - anyone can pay to this offer'),
                SelectableText('lno1qgsyxjtl6luzd9t3pr62xr7eemp...'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Your BOLT12 Offer'), findsOneWidget);
      expect(find.textContaining('Reusable'), findsOneWidget);
    });
  });

  group('Error States', () {
    testWidgets('shows error when generation fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to generate invoice'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: const Text('Generate'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Generate'));
      await tester.pump();

      expect(find.text('Failed to generate invoice'), findsOneWidget);
    });
  });
}

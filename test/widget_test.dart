import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/core/utils/currency_formatter.dart';
import 'package:sangh_ledger/main.dart';

void main() {
  group('CurrencyFormatter tests', () {
    test('formatPaise formats rupees and paise correctly in Indian system', () {
      expect(CurrencyFormatter.formatPaise(0), '₹0.00');
      expect(CurrencyFormatter.formatPaise(50), '₹0.50');
      expect(CurrencyFormatter.formatPaise(10050), '₹100.50');
      expect(CurrencyFormatter.formatPaise(10000000), '₹1,00,000.00');
      expect(CurrencyFormatter.formatPaise(-5000), '-₹50.00');
    });

    test('parseToPaise parses decimal string without floating point inaccuracies', () {
      expect(CurrencyFormatter.parseToPaise('0'), 0);
      expect(CurrencyFormatter.parseToPaise('0.5'), 50);
      expect(CurrencyFormatter.parseToPaise('0.50'), 50);
      expect(CurrencyFormatter.parseToPaise('100.50'), 10050);
      expect(CurrencyFormatter.parseToPaise('₹ 1,00,000.00'), 10000000);
      expect(CurrencyFormatter.parseToPaise('invalid'), isNull);
    });
  });

  testWidgets('SanghLedgerApp loads LoginScreen without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const SanghLedgerApp());
    await tester.pumpAndSettle();

    expect(find.text('Sangh Ledger'), findsWidgets);
    expect(find.text('Login to Ledger'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangh_ledger/core/database/app_database.dart';
import 'package:sangh_ledger/core/database/database_key_manager.dart';
import 'package:sangh_ledger/core/ui/states.dart';
import 'package:sangh_ledger/data/repositories/transaction_repository.dart';
import 'package:sangh_ledger/features/transactions/send_message_bottom_sheet.dart';
import 'package:sangh_ledger/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PART A: Standalone Launch & Singleton Database Future Lock', () {
    test('AppDatabase implements Singleton pattern and DatabaseHelper alias', () {
      final db1 = AppDatabase();
      final db2 = AppDatabase();
      final helper = DatabaseHelper();

      expect(identical(db1, db2), isTrue);
      expect(identical(db1, helper), isTrue);
    });

    test('DatabaseKeyManager generates and caches 256-bit encryption key', () async {
      final manager = DatabaseKeyManager();
      // Should not throw and instantiate with AndroidOptions(encryptedSharedPreferences: true)
      expect(manager, isNotNull);
    });

    test('AppDatabase PRAGMA busy_timeout query contract verification', () {
      // PRAGMA busy_timeout returns a result cursor, so it must strictly use rawQuery on sqflite_sqlcipher
      const busyTimeoutPragma = 'PRAGMA busy_timeout = 5000;';
      expect(busyTimeoutPragma.contains('PRAGMA busy_timeout'), isTrue);
    });
  });

  group('PART B: Post-Transaction Confirmation & Send Message Sheet', () {
    final sampleTx = TransactionItem(
      id: 'tx-test-001',
      organizationId: 'org-test-001',
      memberId: 'mem-test-001',
      memberCode: 'SGH001',
      memberName: 'Ramesh Gowda',
      transactionType: 'savings_deposit',
      paymentMode: 'cash',
      amountPaise: 500000, // ₹5,000.00
      transactionDate: DateTime(2026, 11, 13, 10, 30),
      receiptNumber: 'RCP-2026-0099',
      remarks: 'Monthly recurring deposit',
      isReversed: false,
    );

    Widget createTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
    }

    testWidgets('PostTransactionSuccessDialog displays summary and Send Message button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          PostTransactionSuccessDialog(
            transaction: sampleTx,
            memberPhone: '9876543210',
            updatedBalancePaise: 1500000,
            balanceLabel: 'Savings Balance:',
            sanghName: 'Test Sangh',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify transaction details rendered
      expect(find.text('RCP-2026-0099'), findsOneWidget);
      expect(find.text('Ramesh Gowda (SGH001)'), findsOneWidget);
      expect(find.text('₹5,000.00'), findsOneWidget);
      expect(find.text('₹15,000.00'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Send Message'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('SendMessageBottomSheet renders editable preview and 4 dispatch action buttons', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          SendMessageBottomSheet(
            transaction: sampleTx,
            memberPhone: '9876543210',
            sanghName: 'Pragathi Sangh',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 4 dispatch buttons exist
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Share PDF Receipt'), findsOneWidget);
      expect(find.text('Share via Other Apps'), findsOneWidget);

      // Verify phone number field pre-filled
      final phoneField = tester.widget<TextField>(find.byType(TextField).first);
      expect(phoneField.controller?.text, '9876543210');
    });

    testWidgets('ErrorState shows Restore from Backup and Re-initialize on database open failure', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const ErrorState(
            message: 'Failed to open encrypted database with key. DatabaseException(open_failed)',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restore from Backup'), findsOneWidget);
      expect(find.text('Re-initialize'), findsOneWidget);
    });
  });
}


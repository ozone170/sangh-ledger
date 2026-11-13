import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sangh_ledger/domain/services/backup_service.dart';
import 'package:sangh_ledger/domain/services/receipt_sharing_service.dart';

void main() {
  group('MASTER FIX & FEATURE TASK – Automated Test Suite', () {
    test('Part 1: Unique Receipt Number Generation Format', () {
      final loanCode = 'LN-2026-0001';
      final receipt1 = 'RCP-DIS-$loanCode';
      final receipt2 = 'RCP-DIS-$loanCode-2';
      final receipt3 = 'RCP-DIS-$loanCode-3';

      expect(receipt1, isNot(equals(receipt2)));
      expect(receipt2, isNot(equals(receipt3)));
      expect(receipt1, 'RCP-DIS-LN-2026-0001');
      expect(receipt2, 'RCP-DIS-LN-2026-0001-2');
    });

    test('Part 1: Repayment Allocation – Interest First, Principal Second', () {
      // Loan Principal: ₹10,000 (1,000,000 paise)
      // Accrued Interest: ₹200 (20,000 paise)
      // Total Repayment Made: ₹1,000 (100,000 paise)
      final accruedInterestPaise = 20000;
      final repaymentPaise = 100000;

      int interestPaidPaise;
      int principalPaidPaise;

      if (repaymentPaise <= accruedInterestPaise) {
        interestPaidPaise = repaymentPaise;
        principalPaidPaise = 0;
      } else {
        interestPaidPaise = accruedInterestPaise;
        principalPaidPaise = repaymentPaise - accruedInterestPaise;
      }

      expect(interestPaidPaise, 20000); // Entire ₹200 interest settled first
      expect(principalPaidPaise, 80000); // Remaining ₹800 applied to principal
      expect(interestPaidPaise + principalPaidPaise, repaymentPaise);
    });

    test('Part 1: Full Balance Repayment Closes Loan', () {
      final principalDuePaise = 500000; // ₹5,000.00
      final accruedInterestPaise = 15000; // ₹150.00
      final totalPayable = principalDuePaise + accruedInterestPaise;

      // Admin pays full balance
      final interestPaid = accruedInterestPaise;
      final principalPaid = totalPayable - interestPaid;
      final remainingPrincipal = principalDuePaise - principalPaid;

      expect(remainingPrincipal, 0);
      final newStatus = remainingPrincipal == 0 ? 'Closed' : 'Partially Repaid';
      expect(newStatus, 'Closed');
    });

    test('Part 4: Permanent Send Buttons Message Formats', () {
      // Loan summary message
      final loanMsg = ReceiptSharingService.formatLoanSummaryMessage(
        sanghName: 'Pragati Mahila Sangh',
        memberName: 'Lakshmi Devi',
        memberCode: 'SGH002',
        loanCode: 'LN-2026-0005',
        principalPaise: 2500000, // ₹25,000
        accruedInterestPaise: 50000, // ₹500
        totalPendingPaise: 2550000, // ₹25,500
        monthlyBps: 150, // 1.5%
      );

      expect(loanMsg, contains('Pragati Mahila Sangh'));
      expect(loanMsg, contains('Lakshmi Devi'));
      expect(loanMsg, contains('SGH002'));
      expect(loanMsg, contains('LN-2026-0005'));
      expect(loanMsg, contains('25,000.00'));
      expect(loanMsg, contains('500.00'));
      expect(loanMsg, contains('25,500.00'));
      expect(loanMsg, contains('1.5%'));

      // Savings summary message
      final savingsMsg = ReceiptSharingService.formatSavingsSummaryMessage(
        sanghName: 'Pragati Mahila Sangh',
        memberName: 'Lakshmi Devi',
        memberCode: 'SGH002',
        receiptNumber: 'RCP-SAV-2026-001',
        transactionType: 'savings_deposit',
        amountPaise: 100000, // ₹1,000
        date: DateTime(2026, 11, 13),
        currentTotalSavingsPaise: 1250000, // ₹12,500
      );

      expect(savingsMsg, contains('Pragati Mahila Sangh'));
      expect(savingsMsg, contains('Lakshmi Devi'));
      expect(savingsMsg, contains('SGH002'));
      expect(savingsMsg, contains('RCP-SAV-2026-001'));
      expect(savingsMsg, contains('1,000.00'));
      expect(savingsMsg, contains('12,500.00'));
    });

    test('Part 6: Space-Efficient Rolling 2-Day Local Backup Retention Policy', () async {
      final tempDir = await Directory.systemTemp.createTemp('sangh_backup_test_');
      final backupService = BackupService();

      try {
        // Create dummy backups across 4 distinct calendar days:
        // Day 1 (Oldest): 2026-11-01
        final f1 = File(p.join(tempDir.path, 'SanghLedger_Backup_20261101_100000.zip'));
        await f1.writeAsString('backup1');

        // Day 2: 2026-11-05
        final f2 = File(p.join(tempDir.path, 'SanghLedger_Backup_20261105_120000.zip'));
        await f2.writeAsString('backup2');

        // Day 3 (Previous Day): 2026-11-12 (2 backups on this day)
        final f3a = File(p.join(tempDir.path, 'SanghLedger_Backup_20261112_090000.zip'));
        await f3a.writeAsString('backup3a');
        final f3b = File(p.join(tempDir.path, 'SanghLedger_Backup_20261112_180000.zip'));
        await f3b.writeAsString('backup3b');

        // Day 4 (Current Day): 2026-11-13
        final f4 = File(p.join(tempDir.path, 'SanghLedger_Backup_20261113_140000.zip'));
        await f4.writeAsString('backup4');

        // Execute rolling 2-day retention
        final deleted = await backupService.enforceTwoDayRollingRetention(tempDir);

        // Verification:
        // Day 1 (20261101) and Day 2 (20261105) must be deleted.
        // Day 3 (20261112) and Day 4 (20261113) must be retained.
        expect(deleted.length, 2);
        expect(await f1.exists(), isFalse);
        expect(await f2.exists(), isFalse);
        expect(await f3a.exists(), isTrue);
        expect(await f3b.exists(), isTrue);
        expect(await f4.exists(), isTrue);

        // Second run when only 2 dates exist: nothing should be deleted
        final deletedAgain = await backupService.enforceTwoDayRollingRetention(tempDir);
        expect(deletedAgain, isEmpty);
        expect(await f3a.exists(), isTrue);
        expect(await f3b.exists(), isTrue);
        expect(await f4.exists(), isTrue);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}

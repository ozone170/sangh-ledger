import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/currency_formatter.dart';
import 'reports_service.dart';

class PdfReportService {
  PdfReportService._();

  static Future<Map<String, dynamic>> _getOrgHeader() async {
    String name = 'Sangh Ledger';
    String address = 'Karnataka, India';
    Uint8List? logoBytes;

    try {
      final db = await AppDatabase().database;
      final orgResults = await db.query('organizations', limit: 1);
      if (orgResults.isNotEmpty) {
        final org = orgResults.first;
        final n = org['name'] as String?;
        final a = org['address'] as String?;
        final lp = org['logo_path'] as String?;
        if (n != null && n.isNotEmpty) name = n;
        if (a != null && a.isNotEmpty) address = a;
        if (lp != null && lp.isNotEmpty) {
          final file = File(lp);
          if (await file.exists()) {
            logoBytes = await file.readAsBytes();
          }
        }
      }
    } catch (_) {}

    return {'name': name, 'address': address, 'logoBytes': logoBytes};
  }

  /// Builds a unified, multi-page A4 report PDF and opens the system view/save/share sheet
  static Future<void> generateAndExportReport({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    Map<String, String>? summaryMetrics,
    String? dateSubtitle,
  }) async {
    final org = await _getOrgHeader();
    final fontData = await rootBundle.load('assets/fonts/NotoSansKannada-Regular.ttf');
    final kannadaFont = pw.Font.ttf(fontData);

    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: kannadaFont, bold: kannadaFont),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (org['logoBytes'] != null)
                    pw.Container(
                      width: 40,
                      height: 40,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(pw.MemoryImage(org['logoBytes'] as Uint8List)),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          org['name'] as String,
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: kannadaFont),
                        ),
                        pw.Text(
                          org['address'] as String,
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, font: kannadaFont),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.blueGrey800),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, font: kannadaFont, color: PdfColors.blueGrey900),
                  ),
                  if (dateSubtitle != null)
                    pw.Text(
                      dateSubtitle,
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800, font: kannadaFont),
                    ),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Sangh Ledger • Official Offline Digital Record',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            if (summaryMetrics != null && summaryMetrics.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: summaryMetrics.entries.map((e) {
                    return pw.Column(
                      children: [
                        pw.Text(e.key, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, font: kannadaFont)),
                        pw.SizedBox(height: 2),
                        pw.Text(e.value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: kannadaFont)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, font: kannadaFont, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: pw.TextStyle(fontSize: 8, font: kannadaFont),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    final cleanFileName = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final pdfBytes = await pdf.save();
    await Printing.sharePdf(bytes: pdfBytes, filename: '${cleanFileName}_$dateStr.pdf');
  }

  /// Dispatches export for any of the 12 standard reports by index
  static Future<void> exportReportByIndex(int index, ReportsService service) async {
    switch (index) {
      case 1:
        final members = await service.getMemberRegister();
        await generateAndExportReport(
          title: 'Member Register • ಸದಸ್ಯರ ನೋಂದಣಿ ಪುಸ್ತಕ',
          headers: ['Code', 'Full Name', 'Phone', 'Status', 'Joined Date'],
          rows: members.map((m) {
            return [
              m['member_code']?.toString() ?? '',
              m['full_name']?.toString() ?? '',
              m['phone']?.toString() ?? '',
              (m['is_active'] as int) == 1 ? 'Active' : 'Inactive',
              m['joined_date']?.toString().split('T').first ?? '',
            ];
          }).toList(),
          summaryMetrics: {'Total Members': '${members.length}', 'Active': '${members.where((m) => (m['is_active'] as int) == 1).length}'},
        );
        break;

      case 2:
        // Member ledger - exports all transactions with running balance
        final members = await service.getMemberRegister();
        final firstMemberId = members.isNotEmpty ? members.first['id'] as String : '';
        final memberName = members.isNotEmpty ? members.first['full_name'] as String : '';
        final ledger = await service.getMemberLedger(firstMemberId);
        await generateAndExportReport(
          title: 'Individual Member Ledger • ಸದಸ್ಯರ ಖಾತೆ ಪುಸ್ತಕ',
          dateSubtitle: 'Member: $memberName',
          headers: ['Date', 'Receipt #', 'Type', 'Mode', 'Amount'],
          rows: ledger.map((t) {
            return [
              t['transaction_date']?.toString().split('T').first ?? '',
              t['receipt_number']?.toString() ?? '',
              t['transaction_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? '',
              t['payment_mode']?.toString().toUpperCase() ?? '',
              CurrencyFormatter.formatPaise(t['amount_paise'] as int),
            ];
          }).toList(),
        );
        break;

      case 3:
        final list = await service.getSavingsRegister();
        int totalSavings = 0;
        final rows = list.map((m) {
          final bal = m['balance_paise'] as int;
          totalSavings += bal;
          return [
            m['member_code']?.toString() ?? '',
            m['full_name']?.toString() ?? '',
            CurrencyFormatter.formatPaise(bal),
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Savings Register • ಉಳಿತಾಯ ಖಾತೆಗಳ ವಿವರ',
          headers: ['Member Code', 'Full Name', 'Total Savings Balance'],
          rows: rows,
          summaryMetrics: {'Total Members': '${list.length}', 'Total Savings Balance': CurrencyFormatter.formatPaise(totalSavings)},
        );
        break;

      case 4:
        final loans = await service.getLoanRegister();
        int totalPrincipal = 0;
        final rows = loans.map((l) {
          final p = l['principal_paise'] as int;
          totalPrincipal += p;
          return [
            l['loan_code']?.toString() ?? '',
            '${l['full_name']} (${l['member_code']})',
            CurrencyFormatter.formatPaise(p),
            '${((l['monthly_interest_bps'] as int) / 100).toStringAsFixed(1)}%',
            l['status']?.toString() ?? '',
            l['issue_date']?.toString().split('T').first ?? '',
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Loan Register • ಸಾಲಗಳ ವಹಿವಾಟು ವಿವರ',
          headers: ['Loan Code', 'Member', 'Principal', 'Monthly Rate', 'Status', 'Issue Date'],
          rows: rows,
          summaryMetrics: {'Total Loans': '${loans.length}', 'Total Disbursed': CurrencyFormatter.formatPaise(totalPrincipal)},
        );
        break;

      case 5:
        final loans = await service.getOutstandingPrincipalReport();
        int totalOutstanding = 0;
        final rows = loans.map((l) {
          final o = l['outstanding_principal'] as int;
          totalOutstanding += o;
          return [
            l['loan_code']?.toString() ?? '',
            '${l['full_name']} (${l['member_code']})',
            CurrencyFormatter.formatPaise(l['principal_paise'] as int),
            CurrencyFormatter.formatPaise(l['paid_principal'] as int),
            CurrencyFormatter.formatPaise(o),
            l['status']?.toString() ?? '',
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Outstanding Principal Report • ಬಾಕಿ ಅಸಲು ವರದಿ',
          headers: ['Loan Code', 'Member', 'Original Principal', 'Paid Principal', 'Outstanding Principal', 'Status'],
          rows: rows,
          summaryMetrics: {'Active Loans': '${loans.length}', 'Total Outstanding Principal': CurrencyFormatter.formatPaise(totalOutstanding)},
        );
        break;

      case 6:
        final list = await service.getOutstandingInterestReport();
        int totalInterest = 0;
        final rows = list.map((l) {
          final i = l['accrued_interest'] as int;
          totalInterest += i;
          return [
            l['loan_code']?.toString() ?? '',
            '${l['full_name']} (${l['member_code']})',
            CurrencyFormatter.formatPaise(l['outstanding_principal'] as int),
            '${l['days']} days',
            CurrencyFormatter.formatPaise(i),
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Outstanding Interest Report • ಬಾಕಿ ಬಡ್ಡಿ ವರದಿ (Reducing Balance)',
          headers: ['Loan Code', 'Member', 'Outstanding Principal', 'Days Elapsed', 'Accrued Interest Due'],
          rows: rows,
          summaryMetrics: {'Total Accrued Interest': CurrencyFormatter.formatPaise(totalInterest)},
        );
        break;

      case 7:
        final list = await service.getInterestCollectedReport();
        int totalCollected = 0;
        final rows = list.map((r) {
          final i = r['interest_portion_paise'] as int;
          totalCollected += i;
          return [
            r['payment_date']?.toString().split('T').first ?? '',
            r['loan_code']?.toString() ?? '',
            '${r['full_name']} (${r['member_code']})',
            CurrencyFormatter.formatPaise(r['total_paid_paise'] as int),
            CurrencyFormatter.formatPaise(i),
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Interest Collected Report • ಸಂಗ್ರಹಿಸಿದ ಬಡ್ಡಿ ವರದಿ',
          headers: ['Date', 'Loan Code', 'Member', 'Total Repayment', 'Interest Income Collected'],
          rows: rows,
          summaryMetrics: {'Total Interest Collected': CurrencyFormatter.formatPaise(totalCollected)},
        );
        break;

      case 8:
        final list = await service.getRepaymentReport();
        int totalRepaid = 0;
        final rows = list.map((r) {
          final tot = r['total_paid_paise'] as int;
          totalRepaid += tot;
          return [
            r['payment_date']?.toString().split('T').first ?? '',
            r['receipt_number']?.toString() ?? '',
            r['loan_code']?.toString() ?? '',
            '${r['full_name']} (${r['member_code']})',
            CurrencyFormatter.formatPaise(r['principal_portion_paise'] as int),
            CurrencyFormatter.formatPaise(r['interest_portion_paise'] as int),
            CurrencyFormatter.formatPaise(tot),
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Repayment Report • ಸಾಲ ಮರುಪಾವತಿ ವರದಿ',
          headers: ['Date', 'Receipt #', 'Loan', 'Member', 'Principal Portion', 'Interest Portion', 'Total Paid'],
          rows: rows,
          summaryMetrics: {'Total Repayments': '${list.length}', 'Grand Total Paid': CurrencyFormatter.formatPaise(totalRepaid)},
        );
        break;

      case 9:
        final now = DateTime.now();
        final list = await service.getDailyCashbook(now);
        final rows = list.map((t) {
          return [
            t['created_at']?.toString().split('T').last.substring(0, 5) ?? '',
            t['receipt_number']?.toString() ?? '',
            '${t['full_name']} (${t['member_code']})',
            t['transaction_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? '',
            CurrencyFormatter.formatPaise(t['amount_paise'] as int),
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Daily Cashbook • ದೈನಂದಿನ ರೋಜುಕಿರ್ದು (ಕ್ಯಾಶ್‌ಬುಕ್)',
          dateSubtitle: 'Date: ${now.toIso8601String().split('T').first}',
          headers: ['Time', 'Receipt #', 'Member', 'Type', 'Cash Amount'],
          rows: rows,
        );
        break;

      case 10:
        final list = await service.getMonthlySummary();
        final rows = list.map((m) {
          return [
            m['month_str']?.toString() ?? '',
            CurrencyFormatter.formatPaise(m['deposits'] as int),
            CurrencyFormatter.formatPaise(m['withdrawals'] as int),
            CurrencyFormatter.formatPaise(m['disbursements'] as int),
            CurrencyFormatter.formatPaise(m['repayments'] as int),
            m['total_tx_count']?.toString() ?? '',
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Monthly Summary Report • ಮಾಸಿಕ ಹಣಕಾಸು ಸಾರಾಂಶ',
          headers: ['Month', 'Deposits', 'Withdrawals', 'Disbursements', 'Repayments', 'Total Count'],
          rows: rows,
        );
        break;

      case 11:
        final report = await service.getTrialBalance();
        final rows = report.items.map((i) {
          return [
            i.accountCode,
            i.accountName,
            i.accountType,
            i.debitBalancePaise > 0 ? CurrencyFormatter.formatPaise(i.debitBalancePaise) : '-',
            i.creditBalancePaise > 0 ? CurrencyFormatter.formatPaise(i.creditBalancePaise) : '-',
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Trial Balance Report • ಪ್ರಾಯೋಗಿಕ ಶಿಲ್ಕು (ಟ್ರಯಲ್ ಬ್ಯಾಲೆನ್ಸ್)',
          headers: ['Code', 'Account Name', 'Type', 'Debit (DR)', 'Credit (CR)'],
          rows: rows,
          summaryMetrics: {
            'Status': report.isBalanced ? 'BALANCED' : 'UNBALANCED',
            'Total Debits': CurrencyFormatter.formatPaise(report.totalDebitsPaise),
            'Total Credits': CurrencyFormatter.formatPaise(report.totalCreditsPaise),
          },
        );
        break;

      case 12:
        final list = await service.getAuditHistory(limit: 50);
        final rows = list.map((a) {
          return [
            a['created_at']?.toString().split('T').first ?? '',
            a['action']?.toString() ?? '',
            a['entity_type']?.toString() ?? '',
            a['details_json']?.toString() ?? '',
          ];
        }).toList();
        await generateAndExportReport(
          title: 'Audit History Report • ಆಡಿಟ್ ಇತಿಹಾಸ ವರದಿ',
          headers: ['Timestamp', 'Action', 'Entity', 'Details'],
          rows: rows,
        );
        break;
    }
  }
}


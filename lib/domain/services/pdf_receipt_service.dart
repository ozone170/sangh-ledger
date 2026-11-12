import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/transaction_repository.dart';

class PdfReceiptService {
  PdfReceiptService._();

  /// Generates a PDF receipt document for any transaction
  static Future<Uint8List> generateReceiptPdf({
    required String sanghName,
    required String sanghAddress,
    required TransactionItem transaction,
    String? allocationDetails,
    bool isKannada = false,
  }) async {
    final pdf = pw.Document();

    // Load NotoSansKannada font
    final fontData = await rootBundle.load('assets/fonts/NotoSansKannada-Regular.ttf');
    final kannadaFont = pw.Font.ttf(fontData);

    final title = isKannada ? 'ರಸೀದಿ' : 'PAYMENT RECEIPT';
    final sangh = sanghName.isNotEmpty ? sanghName : (isKannada ? 'ಸಂಘ ಲೆಡ್ಜರ್' : 'Sangh Ledger');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(base: kannadaFont, bold: kannadaFont),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    sangh,
                    style: pw.TextStyle(font: kannadaFont, fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    sanghAddress,
                    style: pw.TextStyle(font: kannadaFont, fontSize: 10, color: PdfColors.grey700),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1),
                pw.Center(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(font: kannadaFont, fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Receipt No: ${transaction.receiptNumber}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Date: ${transaction.transactionDate.toIso8601String().substring(0, 10)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text('Transaction ID: ${transaction.id}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 12),
                _pdfRow('Member Code:', transaction.memberCode, kannadaFont),
                _pdfRow('Member Name:', transaction.memberName, kannadaFont),
                _pdfRow('Transaction Type:', transaction.transactionType.replaceAll('_', ' ').toUpperCase(), kannadaFont),
                _pdfRow('Payment Mode:', transaction.paymentMode.toUpperCase(), kannadaFont),
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Amount (INR):', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      CurrencyFormatter.formatPaise(transaction.amountPaise),
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                if (allocationDetails != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Text('Allocation: $allocationDetails', style: const pw.TextStyle(fontSize: 10)),
                ],
                if (transaction.remarks != null && transaction.remarks!.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('Remarks: ${transaction.remarks}', style: const pw.TextStyle(fontSize: 10)),
                ],
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 20),
                        pw.Text('____________________', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Member Signature', style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 20),
                        pw.Text('____________________', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Prints or shares receipt directly via Android Print sheet
  static Future<void> printReceipt({
    required String sanghName,
    required String sanghAddress,
    required TransactionItem transaction,
    String? allocationDetails,
    bool isKannada = false,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      sanghName: sanghName,
      sanghAddress: sanghAddress,
      transaction: transaction,
      allocationDetails: allocationDetails,
      isKannada: isKannada,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Receipt_${transaction.receiptNumber}.pdf',
    );
  }
}

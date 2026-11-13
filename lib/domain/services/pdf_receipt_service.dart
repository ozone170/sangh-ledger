import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/transaction_repository.dart';
import 'pdf_branding_header.dart';
import 'pdf_font_loader.dart';

class PdfReceiptService {
  PdfReceiptService._();

  /// Generates a PDF receipt document for any transaction with unified organization header & logo
  static Future<Uint8List> generateReceiptPdf({
    String sanghName = '',
    String sanghAddress = '',
    required TransactionItem transaction,
    String? allocationDetails,
    bool isKannada = false,
  }) async {
    final pdf = pw.Document();

    final org = await PdfBrandingHeader.loadOrgHeader(
      fallbackName: sanghName.isNotEmpty && sanghName != 'Sangh Ledger' ? sanghName : null,
      fallbackAddress: sanghAddress.isNotEmpty && sanghAddress != 'Karnataka, India' ? sanghAddress : null,
    );

    final resolvedName = org.name;
    final resolvedAddress = org.address;
    final contactPhone = org.contactPhone;
    final registrationNumber = org.registrationNumber;
    final logoBytes = org.logoBytes;

    final themeData = await PdfFontLoader.getThemeData();
    final title = isKannada ? 'ರಸೀದಿ' : 'PAYMENT RECEIPT';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: themeData,
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
                if (logoBytes != null)
                  pw.Center(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      width: 48,
                      height: 48,
                      child: pw.Image(pw.MemoryImage(logoBytes)),
                    ),
                  ),
                pw.Center(
                  child: pw.Text(
                    resolvedName,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    resolvedAddress,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ),
                if (contactPhone.isNotEmpty || registrationNumber != null)
                  pw.Center(
                    child: pw.Text(
                      [
                        if (contactPhone.isNotEmpty) 'Mobile: $contactPhone',
                        if (registrationNumber != null) 'Reg. No: $registrationNumber',
                      ].join(' • '),
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1),
                pw.Center(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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
                _pdfRow(isKannada ? 'ಸದಸ್ಯರ ಕೋಡ್:' : 'Member Code:', transaction.memberCode),
                _pdfRow(isKannada ? 'ಸದಸ್ಯರ ಹೆಸರು:' : 'Member Name:', transaction.memberName),
                _pdfRow(isKannada ? 'ವಹಿವಾಟಿನ ಪ್ರಕಾರ:' : 'Transaction Type:', transaction.transactionType.replaceAll('_', ' ').toUpperCase()),
                _pdfRow(isKannada ? 'ಪಾವತಿ ವಿಧಾನ:' : 'Payment Mode:', transaction.paymentMode.toUpperCase()),
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(isKannada ? 'ಮೊತ್ತ (ರೂ.):' : 'Amount (INR):', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
                    pw.Text(
                      'Generated on ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      isKannada ? 'ಅಧಿಕೃತ ಸಹಿ' : 'Authorized Signatory',
                      style: const pw.TextStyle(fontSize: 10),
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

  static pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  /// Exports and triggers system share sheet for the transaction receipt PDF
  static Future<void> shareReceiptPdf({
    String sanghName = '',
    String sanghAddress = '',
    required TransactionItem transaction,
    String? allocationDetails,
    bool isKannada = false,
  }) async {
    final bytes = await generateReceiptPdf(
      sanghName: sanghName,
      sanghAddress: sanghAddress,
      transaction: transaction,
      allocationDetails: allocationDetails,
      isKannada: isKannada,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Receipt_${transaction.receiptNumber}.pdf',
    );
  }

  /// Triggers system print dialog for the transaction receipt PDF
  static Future<void> printReceipt({
    String sanghName = '',
    String sanghAddress = '',
    required TransactionItem transaction,
    String? allocationDetails,
    bool isKannada = false,
  }) async {
    final bytes = await generateReceiptPdf(
      sanghName: sanghName,
      sanghAddress: sanghAddress,
      transaction: transaction,
      allocationDetails: allocationDetails,
      isKannada: isKannada,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Receipt_${transaction.receiptNumber}',
    );
  }
}

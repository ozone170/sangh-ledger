import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/transaction_repository.dart';
import 'pdf_receipt_service.dart';

class ReceiptSharingService {
  ReceiptSharingService._();

  /// Formats clean, professional bilingual (Kannada + English) receipt text
  static String formatBilingualReceiptMessage({
    required TransactionItem transaction,
    String? sanghName,
    String? additionalNotes,
  }) {
    final sangh = sanghName?.isNotEmpty == true ? sanghName! : 'ಸಂಘ ಲೆಡ್ಜರ್ | Sangh Ledger';
    final dateStr = transaction.transactionDate.toIso8601String().split('T').first;
    final amountFormatted = CurrencyFormatter.formatPaise(transaction.amountPaise);

    String typeKannada;
    String typeEnglish;

    switch (transaction.transactionType) {
      case 'savings_deposit':
        typeKannada = 'ಉಳಿತಾಯ ಜಮೆ';
        typeEnglish = 'Savings Deposit';
        break;
      case 'savings_withdrawal':
        typeKannada = 'ಉಳಿತಾಯ ಹಿಂಪಡೆಯುವಿಕೆ';
        typeEnglish = 'Savings Withdrawal';
        break;
      case 'loan_disbursement':
        typeKannada = 'ಸಾಲ ವಿತರಣೆ';
        typeEnglish = 'Loan Disbursement';
        break;
      case 'loan_repayment':
        typeKannada = 'ಸಾಲ ಮರುಪಾವತಿ';
        typeEnglish = 'Loan Repayment';
        break;
      default:
        typeKannada = 'ಹಣಕಾಸು ವ್ಯವಹಾರ';
        typeEnglish = transaction.transactionType.replaceAll('_', ' ').toUpperCase();
    }

    final modeStr = transaction.paymentMode.toLowerCase() == 'cash' ? 'ನಗದು (CASH)' : 'ಬ್ಯಾಂಕ್ (BANK)';

    return '''
🏛️ *$sangh*
────────────────────────
📄 *ರಸೀದಿ ಸಂಖ್ಯೆ / Receipt No:* ${transaction.receiptNumber}
📅 *ದಿನಾಂಕ / Date:* $dateStr
👤 *ಸದಸ್ಯರು / Member:* ${transaction.memberName} (${transaction.memberCode})
📌 *ವ್ಯವಹಾರ / Type:* $typeKannada ($typeEnglish)
💰 *ಮೊತ್ತ / Amount:* $amountFormatted
💳 *ಪಾವತಿ ವಿಧಾನ / Mode:* $modeStr
${transaction.remarks?.isNotEmpty == true ? '📝 *ವಿವರ / Remarks:* ${transaction.remarks}\n' : ''}${additionalNotes?.isNotEmpty == true ? 'ℹ️ $additionalNotes\n' : ''}────────────────────────
✅ ಅಧಿಕೃತ ಡಿಜಿಟಲ್ ರಸೀದಿ / Authorized Digital Record
'''.trim();
  }

  /// Sanitizes phone number and prepends India country code (+91) if 10-digits
  static String sanitizePhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) {
      return '91$digits';
    }
    return digits;
  }

  /// Shares receipt directly via WhatsApp
  static Future<bool> shareViaWhatsApp({
    required String phone,
    required String message,
  }) async {
    final sanitizedPhone = sanitizePhoneNumber(phone);
    final encodedMessage = Uri.encodeComponent(message);

    // Try direct WhatsApp URL
    final waUrl = Uri.parse('https://wa.me/$sanitizedPhone?text=$encodedMessage');
    final appUrl = Uri.parse('whatsapp://send?phone=$sanitizedPhone&text=$encodedMessage');

    try {
      if (await canLaunchUrl(appUrl)) {
        return await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(waUrl)) {
        return await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // Fallback: general web launch
    return await launchUrl(waUrl, mode: LaunchMode.externalNonBrowserApplication);
  }

  /// Shares receipt directly via native SMS app
  static Future<bool> shareViaSms({
    required String phone,
    required String message,
  }) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final smsUri = Uri(
      scheme: 'sms',
      path: digits,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri);
      }
    } catch (_) {}

    // Fallback to simple string uri
    final fallbackUri = Uri.parse('sms:$digits?body=${Uri.encodeComponent(message)}');
    return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
  }

  /// Exports PDF to temp file and opens system share sheet
  static Future<void> sharePdfReceipt({
    required Uint8List pdfBytes,
    required String filename,
    required String subject,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(pdfBytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject,
      ),
    );
  }

  /// Shows unified Share Bottom Sheet supporting WhatsApp, SMS, Share PDF & Print
  static void showShareOptionsModal(
    BuildContext context, {
    required TransactionItem transaction,
    String? memberPhone,
    String? sanghName,
    String? sanghAddress,
  }) {
    final message = formatBilingualReceiptMessage(
      transaction: transaction,
      sanghName: sanghName,
    );
    final phone = memberPhone ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Share Receipt • ರಸೀದಿ ಹಂಚಿಕೊಳ್ಳಿ',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    transaction.receiptNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.financialTeal),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // WhatsApp Option
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.chat),
                ),
                title: const Text('Share via WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(phone.isNotEmpty ? 'Send to $phone' : 'Select contact on WhatsApp'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final success = await shareViaWhatsApp(phone: phone, message: message);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not launch WhatsApp. Ensure it is installed.')),
                    );
                  }
                },
              ),

              // SMS Option
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.sms),
                ),
                title: const Text('Send SMS', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(phone.isNotEmpty ? 'SMS to $phone' : 'Send via SMS message'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final success = await shareViaSms(phone: phone, message: message);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open SMS application.')),
                    );
                  }
                },
              ),

              // Share PDF Document Option
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.picture_as_pdf),
                ),
                title: const Text('Share PDF Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Share official Kannada/English PDF receipt file'),
                trailing: const Icon(Icons.share, size: 16),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final pdfBytes = await PdfReceiptService.generateReceiptPdf(
                      sanghName: sanghName ?? 'Sangh Ledger',
                      sanghAddress: sanghAddress ?? 'Karnataka, India',
                      transaction: transaction,
                    );
                    await sharePdfReceipt(
                      pdfBytes: pdfBytes,
                      filename: 'Receipt_${transaction.receiptNumber}.pdf',
                      subject: 'Receipt ${transaction.receiptNumber} - ${transaction.memberName}',
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error sharing PDF: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

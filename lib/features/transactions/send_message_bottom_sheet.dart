import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/services/pdf_receipt_service.dart';
import '../../domain/services/receipt_sharing_service.dart';
import '../../l10n/app_localizations.dart';

/// Clean, full-featured bottom sheet for customizing and dispatching transaction receipts
class SendMessageBottomSheet extends StatefulWidget {
  final TransactionItem transaction;
  final String? memberPhone;
  final String? sanghName;
  final String? sanghAddress;
  final String? customInitialMessage;

  const SendMessageBottomSheet({
    super.key,
    required this.transaction,
    this.memberPhone,
    this.sanghName,
    this.sanghAddress,
    this.customInitialMessage,
  });

  static Future<void> show(
    BuildContext context, {
    required TransactionItem transaction,
    String? memberPhone,
    String? sanghName,
    String? sanghAddress,
    String? customInitialMessage,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SendMessageBottomSheet(
        transaction: transaction,
        memberPhone: memberPhone,
        sanghName: sanghName,
        sanghAddress: sanghAddress,
        customInitialMessage: customInitialMessage,
      ),
    );
  }

  @override
  State<SendMessageBottomSheet> createState() => _SendMessageBottomSheetState();
}

class _SendMessageBottomSheetState extends State<SendMessageBottomSheet> {
  late final TextEditingController _messageController;
  late final TextEditingController _phoneController;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    final defaultMessage = widget.customInitialMessage ??
        ReceiptSharingService.formatBilingualReceiptMessage(
          transaction: widget.transaction,
          sanghName: widget.sanghName,
        );
    _messageController = TextEditingController(text: defaultMessage);
    _phoneController = TextEditingController(text: widget.memberPhone ?? '');
  }

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleWhatsApp() async {
    final phone = _phoneController.text.trim();
    final message = _messageController.text.trim();
    final success = await ReceiptSharingService.shareViaWhatsApp(
      phone: phone,
      message: message,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp. Ensure WhatsApp is installed.'),
          backgroundColor: AppColors.errorCrimson,
        ),
      );
    }
  }

  Future<void> _handleSms() async {
    final phone = _phoneController.text.trim();
    final message = _messageController.text.trim();
    final success = await ReceiptSharingService.shareViaSms(
      phone: phone,
      message: message,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open SMS app.'),
          backgroundColor: AppColors.errorCrimson,
        ),
      );
    }
  }

  Future<void> _handlePdfShare() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await PdfReceiptService.generateReceiptPdf(
        sanghName: widget.sanghName ?? 'Sangh Ledger',
        sanghAddress: widget.sanghAddress ?? 'Karnataka, India',
        transaction: widget.transaction,
      );
      await ReceiptSharingService.sharePdfReceipt(
        pdfBytes: pdfBytes,
        filename: 'Receipt_${widget.transaction.receiptNumber}.pdf',
        subject: 'Receipt ${widget.transaction.receiptNumber} - ${widget.transaction.memberName}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: AppColors.errorCrimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _handleOtherShare() async {
    final message = _messageController.text.trim();
    await ReceiptSharingService.shareViaOtherApps(
      text: message,
      subject: 'Receipt ${widget.transaction.receiptNumber} - ${widget.transaction.memberName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.send_rounded, color: AppColors.primaryNavy),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.sendMessage} • ಸಂದೇಶ ಕಳುಹಿಸಿ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.financialTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.transaction.receiptNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.financialTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Phone Number Input
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '${l10n.phone} (10 digits)',
                prefixIcon: const Icon(Icons.phone_outlined),
                hintText: '9876543210',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Editable Receipt Text Preview
            Text(
              '${l10n.messagePreview} (Editable):',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              maxLines: 6,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                fillColor: Colors.grey.shade50,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // 4 Direct Dispatch Action Buttons
            Text(
              'Send or Share via:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 10),

            // Grid of 4 Action Buttons
            Row(
              children: [
                // 1. WhatsApp Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat, size: 20),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _handleWhatsApp,
                  ),
                ),
                const SizedBox(width: 8),

                // 2. SMS Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.sms, size: 20),
                    label: const Text(
                      'SMS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _handleSms,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                // 3. Share PDF Button
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf, color: AppColors.errorCrimson, size: 20),
                    label: Text(
                      l10n.sharePdfReceipt,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: _isGeneratingPdf ? null : _handlePdfShare,
                  ),
                ),
                const SizedBox(width: 8),

                // 4. Other Apps / Native Share
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: Text(
                      l10n.shareOtherApps,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: _handleOtherShare,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Success Confirmation Dialog shown immediately after committing any transaction
class PostTransactionSuccessDialog extends StatelessWidget {
  final TransactionItem transaction;
  final String? memberPhone;
  final int? updatedBalancePaise;
  final String? balanceLabel;
  final String? sanghName;

  const PostTransactionSuccessDialog({
    super.key,
    required this.transaction,
    this.memberPhone,
    this.updatedBalancePaise,
    this.balanceLabel,
    this.sanghName,
  });

  static Future<void> show(
    BuildContext context, {
    required TransactionItem transaction,
    String? memberPhone,
    int? updatedBalancePaise,
    String? balanceLabel,
    String? sanghName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PostTransactionSuccessDialog(
        transaction: transaction,
        memberPhone: memberPhone,
        updatedBalancePaise: updatedBalancePaise,
        balanceLabel: balanceLabel,
        sanghName: sanghName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final amountFormatted = CurrencyFormatter.formatPaise(transaction.amountPaise);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.successGreen,
            foregroundColor: Colors.white,
            radius: 18,
            child: Icon(Icons.check, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.transactionSuccess,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildRow('Receipt # / ರಸೀದಿ:', transaction.receiptNumber, isBold: true),
                  const Divider(height: 16),
                  _buildRow('Member / ಸದಸ್ಯರು:', '${transaction.memberName} (${transaction.memberCode})'),
                  const SizedBox(height: 8),
                  _buildRow('Amount / ಮೊತ್ತ:', amountFormatted, highlightColor: AppColors.primaryNavy),
                  const SizedBox(height: 8),
                  _buildRow('Mode / ವಿಧಾನ:', transaction.paymentMode.toUpperCase()),
                  if (updatedBalancePaise != null) ...[
                    const Divider(height: 16),
                    _buildRow(
                      balanceLabel ?? 'Balance / ಶಿಲ್ಕು:',
                      CurrencyFormatter.formatPaise(updatedBalancePaise!),
                      highlightColor: AppColors.financialTeal,
                      isBold: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(l10n.done),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.financialTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  l10n.sendMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  SendMessageBottomSheet.show(
                    context,
                    transaction: transaction,
                    memberPhone: memberPhone,
                    sanghName: sanghName,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: highlightColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

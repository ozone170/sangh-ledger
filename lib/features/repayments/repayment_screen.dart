import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/financial_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/amount_input.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/inputs.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/repayment_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../domain/services/accounting_engine.dart';
import '../../l10n/app_localizations.dart';
import '../loans/loans_screen.dart';
import '../transactions/send_message_bottom_sheet.dart';

final repaymentRepositoryProvider = Provider<RepaymentRepository>((ref) {
  return RepaymentRepository();
});

class RepaymentScreen extends ConsumerStatefulWidget {
  final String? loanId;

  const RepaymentScreen({super.key, this.loanId});

  @override
  ConsumerState<RepaymentScreen> createState() => _RepaymentScreenState();
}

class _RepaymentScreenState extends ConsumerState<RepaymentScreen> {
  String? _selectedLoanId;
  DateTime _paymentDate = DateTime.now();
  int? _enteredAmountPaise;
  PaymentMode _mode = PaymentMode.cash;
  RepaymentAllocation? _preview;
  String? _previewError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedLoanId = widget.loanId;
  }

  Future<void> _updatePreview() async {
    if (_selectedLoanId == null || _enteredAmountPaise == null || _enteredAmountPaise! <= 0) {
      setState(() {
        _preview = null;
        _previewError = null;
      });
      return;
    }

    try {
      final repo = ref.read(repaymentRepositoryProvider);
      final allocation = await repo.previewAllocation(
        loanId: _selectedLoanId!,
        paymentDate: _paymentDate,
        paymentAmountPaise: _enteredAmountPaise!,
      );
      setState(() {
        _preview = allocation;
        _previewError = null;
      });
    } catch (e) {
      setState(() {
        _preview = null;
        _previewError = e.toString().replaceFirst('Exception: ', '').replaceFirst('ArgumentError: ', '');
      });
    }
  }

  Future<void> _submitRepayment() async {
    if (_selectedLoanId == null || _enteredAmountPaise == null || _enteredAmountPaise! <= 0) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(repaymentRepositoryProvider);
      final rcp = await repo.recordRepayment(
        loanId: _selectedLoanId!,
        amountPaise: _enteredAmountPaise!,
        paymentMode: _mode,
        paymentDate: _paymentDate,
      );

      invalidateFinancialProviders(ref, loanId: _selectedLoanId);

      final txItem = await TransactionRepository().getTransactionByReceiptNumber(rcp);
      final member = txItem != null ? await MemberRepository().getMemberById(txItem.memberId) : null;
      final remainingPrincipal = _preview?.remainingPrincipalPaise;

      if (!mounted) return;
      Navigator.of(context).pop();

      if (txItem != null) {
        PostTransactionSuccessDialog.show(
          context,
          transaction: txItem,
          memberPhone: member?.phone,
          updatedBalancePaise: remainingPrincipal,
          balanceLabel: 'Remaining Principal / ಬಾಕಿ ಅಸಲು:',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Repayment confirmed! Receipt: $rcp'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorCrimson),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loansAsync = ref.watch(loansListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.repayment)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            loansAsync.when(
              data: (loans) {
                final activeLoans = loans.where((l) => l.status == 'Active' || l.status == 'Partially Repaid').toList();
                return DropdownButtonFormField<String>(
                  initialValue: _selectedLoanId,
                  decoration: const InputDecoration(labelText: 'Select Active Loan *'),
                  items: activeLoans
                      .map((l) => DropdownMenuItem(
                            value: l.id,
                            child: Text('${l.loanCode} (Principal: ${CurrencyFormatter.formatPaise(l.principalPaise)})'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedLoanId = val);
                    _updatePreview();
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Failed to load loans'),
            ),
            const SizedBox(height: 16),
            DateSelector(
              label: 'Payment Date',
              selectedDate: _paymentDate,
              onDateSelected: (date) {
                setState(() => _paymentDate = date);
                _updatePreview();
              },
            ),
            const SizedBox(height: 16),
            AmountInput(
              label: 'Repayment Amount *',
              onChanged: (paise) {
                _enteredAmountPaise = paise;
                _updatePreview();
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<PaymentMode>(
              segments: [
                ButtonSegment(value: PaymentMode.cash, label: Text(l10n.cash)),
                ButtonSegment(value: PaymentMode.bank, label: Text(l10n.bank)),
              ],
              selected: {_mode},
              onSelectionChanged: (set) => setState(() => _mode = set.first),
            ),
            const SizedBox(height: 24),
            if (_previewError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorCrimson.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errorCrimson),
                ),
                child: Text(
                  _previewError!,
                  style: const TextStyle(color: AppColors.errorCrimson, fontWeight: FontWeight.bold),
                ),
              ),
            if (_preview != null) ...[
              Card(
                color: AppColors.surfaceNeutral,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Live Allocation Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.financialTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_preview!.elapsedDays} days elapsed',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.financialTeal, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _allocationRow('Total Payment', CurrencyFormatter.formatPaise(_preview!.totalPaidPaise), isBold: true),
                      const SizedBox(height: 6),
                      _allocationRow('1. Interest Settled (FIRST)', CurrencyFormatter.formatPaise(_preview!.interestPaidPaise), color: AppColors.warningAmber),
                      const SizedBox(height: 6),
                      _allocationRow('2. Principal Settled (SECOND)', CurrencyFormatter.formatPaise(_preview!.principalPaidPaise), color: AppColors.successGreen),
                      const Divider(height: 20),
                      _allocationRow('Remaining Accrued Interest', CurrencyFormatter.formatPaise(_preview!.remainingInterestPaise)),
                      const SizedBox(height: 6),
                      _allocationRow('Remaining Principal Balance', CurrencyFormatter.formatPaise(_preview!.remainingPrincipalPaise), isBold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Confirm & Post Repayment',
                isLoading: _isSubmitting,
                onPressed: _submitRepayment,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _allocationRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

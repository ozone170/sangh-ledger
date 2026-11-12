import 'package:flutter/material.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/financial_summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.transactions),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FinancialSummaryCard(
                  title: 'Cash in Hand',
                  amountPaise: 0,
                  icon: Icons.payments_outlined,
                  color: AppColors.financialTeal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FinancialSummaryCard(
                  title: 'Bank Balance',
                  amountPaise: 0,
                  icon: Icons.account_balance_outlined,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FinancialSummaryCard(
                  title: 'Savings Liabilities',
                  amountPaise: 0,
                  icon: Icons.savings_outlined,
                  color: AppColors.financialTealDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FinancialSummaryCard(
                  title: 'Loan Receivables',
                  amountPaise: 0,
                  icon: Icons.monetization_on_outlined,
                  color: AppColors.errorCrimson,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

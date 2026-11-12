import 'package:flutter/material.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/theme/app_colors.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More & Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildItem(
            context,
            icon: Icons.bar_chart,
            title: 'Financial Reports',
            subtitle: '12 standard accounting & ledger reports',
            route: AppRoutes.reports,
          ),
          _buildItem(
            context,
            icon: Icons.receipt_long,
            title: 'Unified Transactions Ledger',
            subtitle: 'Audit trail and transaction reversal',
            route: AppRoutes.transactions,
          ),
          _buildItem(
            context,
            icon: Icons.settings,
            title: 'Settings & Security',
            subtitle: 'Language, Backup, PIN & Admin profile',
            route: AppRoutes.settings,
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryNavy.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryNavy),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: () => Navigator.of(context).pushNamed(route),
      ),
    );
  }
}


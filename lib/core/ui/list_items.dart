import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class MemberListItem extends StatelessWidget {
  final String memberCode;
  final String name;
  final String phone;
  final int savingsBalancePaise;
  final int loanBalancePaise;
  final bool isActive;
  final VoidCallback? onTap;

  const MemberListItem({
    super.key,
    required this.memberCode,
    required this.name,
    required this.phone,
    required this.savingsBalancePaise,
    required this.loanBalancePaise,
    this.isActive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isActive
              ? AppColors.primaryNavy
              : AppColors.textMuted.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'M',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                memberCode,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(phone, style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S: ${CurrencyFormatter.formatPaise(savingsBalancePaise)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.financialTeal,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (loanBalancePaise > 0)
                    Text(
                      'L: ${CurrencyFormatter.formatPaise(loanBalancePaise)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorCrimson,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ),
    );
  }
}

class TransactionListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final int amountPaise;
  final bool isCredit;
  final String? badgeText;
  final VoidCallback? onTap;

  const TransactionListItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.amountPaise,
    required this.isCredit,
    this.badgeText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amountColor = isCredit ? AppColors.successGreen : AppColors.errorCrimson;
    final prefix = isCredit ? '+' : '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isCredit
              ? AppColors.financialTeal.withValues(alpha: 0.1)
              : AppColors.errorCrimson.withValues(alpha: 0.1),
          foregroundColor: amountColor,
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeText != null)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceNeutral,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
        subtitle: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: Text(
          '$prefix${CurrencyFormatter.formatPaise(amountPaise)}',
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/ui/states.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: const EmptyState(
        title: 'No Loans Active',
        subtitle: 'Issue a loan to an active member with daily reducing interest.',
        icon: Icons.account_balance_outlined,
      ),
    );
  }
}

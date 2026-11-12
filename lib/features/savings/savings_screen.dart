import 'package:flutter/material.dart';
import '../../core/ui/states.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings Accounts')),
      body: const EmptyState(
        title: 'No Savings Accounts',
        subtitle: 'Select a member to view or record savings deposits.',
        icon: Icons.savings_outlined,
      ),
    );
  }
}

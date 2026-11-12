import 'package:flutter/material.dart';
import '../../core/ui/states.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Ledger')),
      body: const EmptyState(
        title: 'No Transactions',
        subtitle: 'All double-entry journal transactions will appear here.',
        icon: Icons.receipt_long_outlined,
      ),
    );
  }
}

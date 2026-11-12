import 'package:flutter/material.dart';

class RepaymentScreen extends StatelessWidget {
  final String? loanId;

  const RepaymentScreen({super.key, this.loanId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Repayment')),
      body: Center(
        child: Text('Repayment for: ${loanId ?? "Select Loan"}'),
      ),
    );
  }
}

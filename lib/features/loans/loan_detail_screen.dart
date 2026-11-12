import 'package:flutter/material.dart';

class LoanDetailScreen extends StatelessWidget {
  final String loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Loan $loanId')),
      body: Center(
        child: Text('Loan Details: $loanId'),
      ),
    );
  }
}


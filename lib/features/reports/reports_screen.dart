import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Financial Reports')),
      body: const Center(
        child: Text('Financial Reports (12 Reports)'),
      ),
    );
  }
}

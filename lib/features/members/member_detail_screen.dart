import 'package:flutter/material.dart';

class MemberDetailScreen extends StatelessWidget {
  final String memberId;

  const MemberDetailScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Member #$memberId')),
      body: Center(
        child: Text('Member Profile: $memberId'),
      ),
    );
  }
}

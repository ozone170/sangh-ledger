import 'package:flutter/material.dart';
import '../../core/ui/states.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Members (0/100)')),
      body: const EmptyState(
        title: 'No Members Registered',
        subtitle: 'Add active members (up to 100 maximum) to begin transactions.',
        icon: Icons.people_outline,
      ),
    );
  }
}

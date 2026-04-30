import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProgressGraphScreen extends ConsumerWidget {
  const ProgressGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
      ),
      body: const Center(
        child: Text('New Progress Design Coming Soon'),
      ),
    );
  }
}

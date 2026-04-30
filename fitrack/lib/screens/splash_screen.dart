import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // router will automatically redirect based on auth state
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.activity,
              size: 80,
              color: Color(0xFF22C55E),
            ),
            SizedBox(height: 24),
            Text(
              'Fitrack',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Track. Progress. Transform.',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF94A3B8),
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(
              color: Color(0xFF22C55E),
            ),
          ],
        ),
      ),
    );
  }
}

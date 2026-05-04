import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../widgets/app_button.dart';

class KycWelcomeScreen extends StatelessWidget {
  const KycWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(LucideIcons.arrowLeft),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(height: 32),

              // Shield icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  color: AppTheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Identity Verification',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Before you can upload progress photos, we need to verify your identity. '
                'This keeps your account secure and ensures all content complies with our policy.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 36),

              _InfoTile(
                icon: LucideIcons.lock,
                title: 'Your photos are private',
                subtitle: 'Progress photos are encrypted before storage and never shared.',
              ),
              const SizedBox(height: 16),
              _InfoTile(
                icon: LucideIcons.userCheck,
                title: 'One-time verification',
                subtitle: 'Complete this once to permanently unlock photo uploads.',
              ),
              const SizedBox(height: 16),
              _InfoTile(
                icon: LucideIcons.camera,
                title: 'Live selfie required',
                subtitle: 'A brief liveness check confirms you are a real person.',
              ),
              const SizedBox(height: 16),
              _InfoTile(
                icon: LucideIcons.calendarCheck,
                title: 'Age verification',
                subtitle: 'You must be 18 years or older to use this feature.',
              ),

              const Spacer(),

              AppButton(
                label: 'Continue',
                onPressed: () => context.push('/kyc/consent'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';
import '../../providers/kyc_provider.dart';
import '../../widgets/app_button.dart';

class KycCompleteScreen extends ConsumerWidget {
  const KycCompleteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false, // Don't allow back — KYC is done
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // Success icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.shieldCheck,
                    color: AppTheme.primary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Verification Complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your identity has been verified. Photo uploads are now enabled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textMuted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),

                // Summary tiles
                _SummaryTile(icon: LucideIcons.fileCheck, label: 'Consent recorded'),
                const SizedBox(height: 12),
                _SummaryTile(icon: LucideIcons.scanFace, label: 'Liveness verified'),
                const SizedBox(height: 12),
                _SummaryTile(icon: LucideIcons.calendarCheck, label: 'Age confirmed'),
                const SizedBox(height: 12),
                _SummaryTile(icon: LucideIcons.lock, label: 'Identity embedding stored'),

                const Spacer(),

                AppButton(
                  label: 'Start Uploading Photos',
                  onPressed: () {
                    // Invalidate the KYC provider so the photos screen refreshes.
                    ref.invalidate(kycStatusProvider);
                    context.go('/photos');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const Icon(LucideIcons.check, color: AppTheme.primary, size: 16),
        ],
      ),
    );
  }
}

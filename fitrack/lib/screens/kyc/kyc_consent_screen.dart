import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/error_handler.dart';
import '../../core/theme.dart';
import '../../repositories/tracker_repository.dart';
import '../../widgets/app_button.dart';

class KycConsentScreen extends ConsumerStatefulWidget {
  const KycConsentScreen({super.key});

  @override
  ConsumerState<KycConsentScreen> createState() => _KycConsentScreenState();
}

class _KycConsentScreenState extends ConsumerState<KycConsentScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _photoProcessing = false;
  bool _sensitiveData = false;
  bool _adult = false;
  bool _selfPhoto = false;
  bool _isLoading = false;

  bool get _allChecked =>
      _terms && _privacy && _photoProcessing && _sensitiveData && _adult && _selfPhoto;

  Future<void> _submit() async {
    if (!_allChecked) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(trackerRepositoryProvider).submitKycConsent(
            termsAccepted: true,
            privacyAccepted: true,
            photoProcessingAccepted: true,
            sensitiveDataAccepted: true,
            adultConfirmed: true,
            selfPhotoConfirmed: true,
          );
      if (mounted) context.push('/kyc/selfie');
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, ErrorHandler.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consent & Declarations'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            _StepIndicator(current: 1, total: 4),
            const SizedBox(height: 28),

            const Text(
              'Required Declarations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please read and accept all of the following before proceeding.',
              style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5),
            ),
            const SizedBox(height: 24),

            _ConsentTile(
              value: _terms,
              onChanged: (v) => setState(() => _terms = v),
              label: 'I agree to the ',
              linkText: 'Terms of Service',
            ),
            _ConsentTile(
              value: _privacy,
              onChanged: (v) => setState(() => _privacy = v),
              label: 'I agree to the ',
              linkText: 'Privacy Policy',
            ),
            _ConsentTile(
              value: _photoProcessing,
              onChanged: (v) => setState(() => _photoProcessing = v),
              label: 'I consent to processing my photos for identity verification',
            ),
            _ConsentTile(
              value: _sensitiveData,
              onChanged: (v) => setState(() => _sensitiveData = v),
              label: 'I understand body progress images may contain sensitive personal information. '
                  'I consent to encrypted storage and processing required to provide the service.',
            ),
            _ConsentTile(
              value: _adult,
              onChanged: (v) => setState(() => _adult = v),
              label: 'I confirm I am 18 years or older',
            ),
            _ConsentTile(
              value: _selfPhoto,
              onChanged: (v) => setState(() => _selfPhoto = v),
              label: 'I certify that all uploaded images are of myself only',
            ),

            const SizedBox(height: 24),

            // Consent notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF222222)),
              ),
              child: const Text(
                'By continuing, you authorise the app to process photos captured during '
                'onboarding for identity verification, age checks, and fraud prevention.\n\n'
                'Your uploaded progress photos are encrypted before storage.\n\n'
                'You must be at least 18 years old and may only upload images of yourself. '
                'False declarations, misuse, or uploads involving minors may result in '
                'account suspension.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 32),

            AppButton(
              label: 'Accept & Continue',
              isLoading: _isLoading,
              onPressed: _allChecked ? _submit : null,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < current;
        final isCurrent = i == current - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primary
                  : isCurrent
                      ? AppTheme.primary
                      : const Color(0xFF333333),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? linkText;

  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.label,
    this.linkText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              side: const BorderSide(color: Color(0xFF444444)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: linkText != null
                  ? Text.rich(
                      TextSpan(
                        text: label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: linkText,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/error_handler.dart';
import '../../core/theme.dart';
import '../../repositories/tracker_repository.dart';
import '../../services/face_verification_service.dart';
import '../../widgets/app_button.dart';

class KycAgeScreen extends ConsumerStatefulWidget {
  /// Raw bytes of the captured selfie (passed from the selfie screen).
  final Uint8List? selfieBytes;

  const KycAgeScreen({super.key, this.selfieBytes});

  @override
  ConsumerState<KycAgeScreen> createState() => _KycAgeScreenState();
}

class _KycAgeScreenState extends ConsumerState<KycAgeScreen> {
  DateTime? _dob;
  bool _isLoading = false;

  String get _dobLabel => _dob != null
      ? DateFormat('MMMM d, yyyy').format(_dob!)
      : 'Select date of birth';

  bool get _isValid {
    if (_dob == null) return false;
    final age = (DateTime.now().difference(_dob!).inDays / 365).floor();
    return age >= 18;
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      helpText: 'Select date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.primary,
            surface: AppTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _isLoading = true);
    try {
      final dobStr = DateFormat('yyyy-MM-dd').format(_dob!);

      // Build a landmark-based face embedding from the captured selfie.
      // Falls back to an empty list if no face can be detected (rare in practice
      // since the selfie screen already confirmed a face was present).
      final embedding = widget.selfieBytes != null
          ? await FaceVerificationService.buildLandmarkEmbedding(widget.selfieBytes!) ?? []
          : <double>[];

      await ref.read(trackerRepositoryProvider).completeKyc(
            dob: dobStr,
            faceEmbedding: embedding,
          );

      if (mounted) {
        context.pushReplacement('/kyc/complete');
      }
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
        title: const Text('Age Verification'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepIndicator(current: 3, total: 4),
            const SizedBox(height: 28),

            const Text(
              'Date of Birth',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You must be at least 18 years old to use this feature.',
              style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.5),
            ),
            const SizedBox(height: 32),

            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _dob != null
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : const Color(0xFF333333),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.calendar, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dobLabel,
                        style: TextStyle(
                          fontSize: 16,
                          color: _dob != null
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, color: AppTheme.textMuted, size: 18),
                  ],
                ),
              ),
            ),

            if (_dob != null && !_isValid) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(LucideIcons.alertCircle, size: 16, color: Color(0xFFEF4444)),
                  SizedBox(width: 6),
                  Text(
                    'You must be at least 18 years old.',
                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                  ),
                ],
              ),
            ],

            const Spacer(),

            AppButton(
              label: 'Continue',
              isLoading: _isLoading,
              onPressed: _isValid ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i < current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: filled ? AppTheme.primary : const Color(0xFF333333),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

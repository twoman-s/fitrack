import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme.dart';

class OnboardingMotivationScreen extends StatelessWidget {
  final String goalType; // 'LOSE' | 'GAIN'

  const OnboardingMotivationScreen({super.key, required this.goalType});

  static const _loseQuote =
      '"Every step forward is a step away from who you used to be. '
      'Your transformation starts today — embrace the journey, not just the destination."';

  static const _gainQuote =
      '"Strength isn\'t built overnight. Every rep, every meal, every rest day '
      'is a brick in the foundation of your best self. Build it deliberately."';

  static const _loseLabel = 'Your Trim-Down Journey';
  static const _gainLabel = 'Your Build-Up Journey';

  void _start(BuildContext context) {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isLose = goalType == 'LOSE';
    final quote = isLose ? _loseQuote : _gainQuote;
    final journeyLabel = isLose ? _loseLabel : _gainLabel;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: [
              // Step indicator
              Row(
                children: [
                  _StepDot(active: false),
                  const SizedBox(width: 6),
                  _StepDot(active: true),
                  const Spacer(),
                ],
              ),

              const Spacer(),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isLose ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                  color: AppTheme.primary,
                  size: 36,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                journeyLabel,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'You\'re Ready.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Column(
                  children: [
                    const Icon(LucideIcons.quote, color: AppTheme.primary, size: 20),
                    const SizedBox(height: 12),
                    Text(
                      quote,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 15,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // CTA button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _start(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Start Your Journey',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(LucideIcons.arrowRight, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : const Color(0xFF374151),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

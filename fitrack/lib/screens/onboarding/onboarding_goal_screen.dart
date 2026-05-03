import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme.dart';
import '../../repositories/goal_repository.dart';
import '../../core/error_handler.dart';
import '../../widgets/app_button.dart';

class OnboardingGoalScreen extends ConsumerStatefulWidget {
  const OnboardingGoalScreen({super.key});

  @override
  ConsumerState<OnboardingGoalScreen> createState() => _OnboardingGoalScreenState();
}

class _OnboardingGoalScreenState extends ConsumerState<OnboardingGoalScreen> {
  String _goalType = 'LOSE'; // 'LOSE' | 'GAIN'
  final _currentWeightController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _targetDate = DateTime.now().add(const Duration(days: 90));
  bool _isSaving = false;

  @override
  void dispose() {
    _currentWeightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _targetDate;
    final first = isStart ? DateTime(2020) : _startDate.add(const Duration(days: 1));
    final last = DateTime(2030);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_targetDate.isBefore(_startDate)) {
            _targetDate = _startDate.add(const Duration(days: 90));
          }
        } else {
          _targetDate = picked;
        }
      });
    }
  }

  Future<void> _saveGoal() async {
    final weightText = _weightController.text.trim();
    if (weightText.isEmpty) {
      ErrorHandler.showSnackBar(context, 'Please enter your target weight');
      return;
    }
    final weight = double.tryParse(weightText);
    if (weight == null || weight <= 0) {
      ErrorHandler.showSnackBar(context, 'Please enter a valid weight');
      return;
    }
    final currentWeightText = _currentWeightController.text.trim();
    final currentWeight = currentWeightText.isNotEmpty
        ? double.tryParse(currentWeightText)
        : null;
    if (currentWeightText.isNotEmpty && (currentWeight == null || currentWeight <= 0)) {
      ErrorHandler.showSnackBar(context, 'Please enter a valid current weight');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(goalRepositoryProvider).createGoal(
        goalType: _goalType,
        currentWeight: currentWeight,
        targetWeight: weight,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        targetDate: DateFormat('yyyy-MM-dd').format(_targetDate),
      );
      if (mounted) {
        context.go('/onboarding/motivation', extra: _goalType);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Failed to save goal. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _skip() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Goal not set — some progress metrics won\'t be available until you add one.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF374151),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Step indicator
                  Row(
                    children: [
                      _StepDot(active: true),
                      const SizedBox(width: 6),
                      _StepDot(active: false),
                    ],
                  ),
                  AppButton.ghost(
                    label: 'Skip',
                    expand: false,
                    color: const Color(0xFF6B7280),
                    onPressed: _skip,
                  ),
                ],
              ),
            ),

            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set Your Goal',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tell us what you want to achieve so we can help you get there.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                    ),

                    const SizedBox(height: 32),

                    // ── Goal type toggle ─────────────────────────────────
                    const _SectionLabel('What\'s your goal?'),
                    const SizedBox(height: 10),
                    _GoalToggle(
                      selected: _goalType,
                      onChanged: (v) => setState(() => _goalType = v),
                    ),

                    const SizedBox(height: 28),

                    // ── Current weight ───────────────────────────────────
                    const _SectionLabel('Current Weight (kg)'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _currentWeightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'e.g. 85.0',
                        prefixIcon: const Icon(LucideIcons.scale, size: 18),
                        filled: true,
                        fillColor: const Color(0xFF111111),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Target weight ────────────────────────────────────
                    const _SectionLabel('Target Weight (kg)'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'e.g. 72.5',
                        prefixIcon: const Icon(LucideIcons.scale, size: 18),
                        filled: true,
                        fillColor: const Color(0xFF111111),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Date pickers ─────────────────────────────────────
                    const _SectionLabel('Timeline'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Start Date',
                            date: _startDate,
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Target Date',
                            date: _targetDate,
                            onTap: () => _pickDate(isStart: false),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // ── CTA ──────────────────────────────────────────────
                    AppButton(
                      label: 'Continue',
                      isLoading: _isSaving,
                      onPressed: _saveGoal,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goal type toggle ────────────────────────────────────────────────────────

class _GoalToggle extends StatelessWidget {
  const _GoalToggle({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleOption(
            icon: LucideIcons.trendingDown,
            label: 'Lose Weight',
            subtitle: 'Trim down & feel lighter',
            value: 'LOSE',
            selected: selected == 'LOSE',
            onTap: () => onChanged('LOSE'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToggleOption(
            icon: LucideIcons.trendingUp,
            label: 'Gain Weight',
            subtitle: 'Build mass & get stronger',
            value: 'GAIN',
            selected: selected == 'GAIN',
            onTap: () => onChanged('GAIN'),
          ),
        ),
      ],
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.12) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFF2A2A2A),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.primary : const Color(0xFF6B7280),
              size: 22,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date field ──────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.calendar, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
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

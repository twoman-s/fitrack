import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/error_handler.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../repositories/goal_repository.dart';
import '../../widgets/app_bar.dart';
import '../../widgets/app_button.dart';

/// Standalone screen for creating a new goal or editing/completing an existing one.
/// Pass [existingGoal] to open in edit mode.
class GoalEditScreen extends ConsumerStatefulWidget {
  final WeightGoal? existingGoal;

  const GoalEditScreen({super.key, this.existingGoal});

  @override
  ConsumerState<GoalEditScreen> createState() => _GoalEditScreenState();
}

class _GoalEditScreenState extends ConsumerState<GoalEditScreen> {
  late String _goalType;
  final _currentWeightController = TextEditingController();
  final _weightController = TextEditingController();
  late DateTime _startDate;
  late DateTime _targetDate;
  bool _isSaving = false;
  bool _isCompleting = false;

  bool get _isEditing => widget.existingGoal != null;

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;
    _goalType = g?.goalType ?? 'LOSE';
    _currentWeightController.text =
        g?.currentWeight != null ? g!.currentWeight.toString() : '';
    _weightController.text = g != null ? g.targetWeight.toString() : '';
    _startDate = g != null
        ? DateTime.parse(g.startDate)
        : DateTime.now();
    _targetDate = g != null
        ? DateTime.parse(g.targetDate)
        : DateTime.now().add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _currentWeightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _targetDate;
    final first = isStart
        ? DateTime(2020)
        : _startDate.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2030),
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

  Future<void> _save() async {
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
      if (_isEditing) {
        await ref.read(goalRepositoryProvider).updateGoal(
          widget.existingGoal!.id,
          goalType: _goalType,
          currentWeight: currentWeight,
          targetWeight: weight,
          startDate: DateFormat('yyyy-MM-dd').format(_startDate),
          targetDate: DateFormat('yyyy-MM-dd').format(_targetDate),
        );
      } else {
        await ref.read(goalRepositoryProvider).createGoal(
          goalType: _goalType,
          currentWeight: currentWeight,
          targetWeight: weight,
          startDate: DateFormat('yyyy-MM-dd').format(_startDate),
          targetDate: DateFormat('yyyy-MM-dd').format(_targetDate),
        );
      }
      if (mounted) context.pop(true); // true = refresh caller
    } on Exception catch (e) {
      if (mounted) {
        // 409 = active goal already exists
        final msg = ErrorHandler.getErrorMessage(e);
        ErrorHandler.showSnackBar(context, msg);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _completeGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Complete Goal',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Mark this goal as completed? You will be able to create a new goal afterwards.',
          style: TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCompleting = true);
    try {
      await ref.read(goalRepositoryProvider).updateGoal(
        widget.existingGoal!.id,
        isActive: false,
      );
      if (mounted) context.pop(true);
    } on Exception catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, ErrorHandler.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: FitrackAppBar(
        title: _isEditing ? 'Edit Goal' : 'New Goal',
        actions: _isEditing
            ? [
                TextButton.icon(
                  onPressed: _isCompleting ? null : _completeGoal,
                  icon: _isCompleting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary),
                        )
                      : const Icon(LucideIcons.checkCircle,
                          size: 16, color: AppTheme.primary),
                  label: const Text('Complete',
                      style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Goal type ────────────────────────────────────────────────
            const _SectionLabel("What's your goal?"),
            const SizedBox(height: 10),
            _GoalToggle(
              selected: _goalType,
              onChanged: (v) => setState(() => _goalType = v),
            ),

            const SizedBox(height: 28),

            // ── Current weight ───────────────────────────────────────────
            const _SectionLabel('Current Weight (kg)'),
            const SizedBox(height: 10),
            TextField(
              controller: _currentWeightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'e.g. 85.0',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(LucideIcons.scale, size: 18,
                    color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceHighlight,
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

            // ── Target weight ────────────────────────────────────────────
            const _SectionLabel('Target Weight (kg)'),
            const SizedBox(height: 10),
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'e.g. 72.5',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon:
                    const Icon(LucideIcons.scale, size: 18, color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceHighlight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Timeline ─────────────────────────────────────────────────
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

            // ── Save button ──────────────────────────────────────────────
            AppButton(
              label: _isEditing ? 'Save Changes' : 'Create Goal',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reused sub-widgets ────────────────────────────────────────────────────────

class _GoalToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _GoalToggle({required this.selected, required this.onChanged});

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
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : AppTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFF2A2A2A),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: selected ? AppTheme.primary : AppTheme.textMuted,
                size: 22),
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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateField(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHighlight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.calendar,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../repositories/tracker_repository.dart';
import '../providers/dashboard_provider.dart';
import '../core/error_handler.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';
import '../models/weight.dart';

class AddWeightScreen extends ConsumerStatefulWidget {
  final WeightEntry? entry;
  
  const AddWeightScreen({super.key, this.entry});

  @override
  ConsumerState<AddWeightScreen> createState() => _AddWeightScreenState();
}

class _AddWeightScreenState extends ConsumerState<AddWeightScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _morningTime;
  TimeOfDay? _eveningTime;
  final _morningController = TextEditingController();
  final _eveningController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      final entry = widget.entry!;
      _selectedDate = DateTime.parse(entry.date);
      _morningController.text = entry.morningWeight?.toString() ?? '';
      _eveningController.text = entry.eveningWeight?.toString() ?? '';
      _notesController.text = entry.notes;

      if (entry.morningWeightTime != null) {
        _morningTime = _parseUtcTimeToLocal(entry.date, entry.morningWeightTime!);
      }
      if (entry.eveningWeightTime != null) {
        _eveningTime = _parseUtcTimeToLocal(entry.date, entry.eveningWeightTime!);
      }
    }
  }

  TimeOfDay _parseUtcTimeToLocal(String dateStr, String utcTimeStr) {
    try {
      final parts = utcTimeStr.split(':');
      final date = DateTime.parse(dateStr);
      final utcDateTime = DateTime.utc(
        date.year, date.month, date.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );
      final localDateTime = utcDateTime.toLocal();
      return TimeOfDay.fromDateTime(localDateTime);
    } catch (e) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  String? _formatTimeToUtc(DateTime date, TimeOfDay? time) {
    if (time == null) return null;
    final localDateTime = DateTime(
      date.year, date.month, date.day,
      time.hour, time.minute,
    );
    final utcDateTime = localDateTime.toUtc();
    return DateFormat('HH:mm:ss').format(utcDateTime);
  }

  Future<void> _pickTime(bool isMorning) async {
    final time = await showTimePicker(
      context: context,
      initialTime: (isMorning ? _morningTime : _eveningTime) ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF22C55E),
              surface: Color(0xFF111111),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        if (isMorning) {
          _morningTime = time;
        } else {
          _eveningTime = time;
        }
      });
    }
  }

  Widget _buildTimeSelector({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
    required VoidCallback onClear,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: time != null
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
        ),
        child: Text(
          time?.format(context) ?? 'Select',
          style: TextStyle(
            fontSize: 16,
            color: time == null ? Colors.white.withValues(alpha: 0.4) : Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteWeight() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    setState(() => _isLoading = true);
    try {
      await ref.read(trackerRepositoryProvider).deleteWeight(dateStr);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Entry deleted.', isError: false);
        context.pop();
      }
    } catch (e) {
      if (mounted) ErrorHandler.showSnackBar(context, ErrorHandler.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveWeight() async {
    final morningStr = _morningController.text.trim();
    final eveningStr = _eveningController.text.trim();
    final notes = _notesController.text.trim();
    final isEditing = widget.entry != null;

    if (!isEditing && morningStr.isEmpty && eveningStr.isEmpty) {
      ErrorHandler.showSnackBar(context, 'Please enter at least one weight');
      return;
    }

    final morningWeight = double.tryParse(morningStr);
    final eveningWeight = double.tryParse(eveningStr);

    if ((morningStr.isNotEmpty && morningWeight == null) ||
        (eveningStr.isNotEmpty && eveningWeight == null)) {
      ErrorHandler.showSnackBar(context, 'Please enter valid numbers');
      return;
    }

    // Determine if we need to explicitly clear values
    final clearMorning = isEditing && morningStr.isEmpty && widget.entry!.morningWeight != null;
    final clearEvening = isEditing && eveningStr.isEmpty && widget.entry!.eveningWeight != null;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(trackerRepositoryProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      await repo.addWeight(
        date: dateStr,
        morningWeight: morningWeight,
        morningWeightTime: _formatTimeToUtc(_selectedDate, _morningTime),
        eveningWeight: eveningWeight,
        eveningWeightTime: _formatTimeToUtc(_selectedDate, _eveningTime),
        notes: notes,
        clearMorning: clearMorning,
        clearEvening: clearEvening,
      );

      // Refresh dashboard data
      ref.invalidate(dashboardProvider);

      if (mounted) {
        ErrorHandler.showSnackBar(context, 'Weight saved successfully', isError: false);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showSnackBar(context, ErrorHandler.getErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF22C55E),
              surface: Color(0xFF111111),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;

    return Scaffold(
      appBar: FitrackAppBar(
        title: isEditing ? 'Edit Weight' : 'Add Weight',
        actions: isEditing
            ? [
                IconButton(
                  icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                  onPressed: _isLoading ? null : _deleteWeight,
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(LucideIcons.calendar, color: Color(0xFF22C55E)),
                    Text(
                      DateFormat('MMMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Icon(LucideIcons.chevronRight, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _morningController,
                      onChanged: (val) {
                        if (val.isNotEmpty && _morningTime == null) {
                          setState(() => _morningTime = TimeOfDay.now());
                        }
                      },
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Morning Weight (kg)',
                        prefixIcon: const Icon(LucideIcons.sun),
                        suffixIcon: _morningController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _morningController.clear();
                                    _morningTime = null;
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildTimeSelector(
                    label: 'Time',
                    time: _morningTime,
                    icon: LucideIcons.clock,
                    onTap: () => _pickTime(true),
                    onClear: () => setState(() => _morningTime = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _eveningController,
                      onChanged: (val) {
                        if (val.isNotEmpty && _eveningTime == null) {
                          setState(() => _eveningTime = TimeOfDay.now());
                        }
                      },
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Evening Weight (kg)',
                        prefixIcon: const Icon(LucideIcons.moon),
                        suffixIcon: _eveningController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _eveningController.clear();
                                    _eveningTime = null;
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildTimeSelector(
                    label: 'Time',
                    time: _eveningTime,
                    icon: LucideIcons.clock,
                    onTap: () => _pickTime(false),
                    onClear: () => setState(() => _eveningTime = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'How are you feeling?',
              ),
            ),
            const SizedBox(height: 48),
            AppButton(
              label: 'Save',
              isLoading: _isLoading,
              onPressed: _saveWeight,
            ),
          ],
        ),
      ),
    );
  }
}

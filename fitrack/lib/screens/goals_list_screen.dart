import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme.dart';
import '../models/goal.dart';
import '../repositories/goal_repository.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';

final _goalHistoryProvider =
    FutureProvider.autoDispose<List<WeightGoal>>((ref) {
  return ref.watch(goalRepositoryProvider).getGoalHistory();
});

class GoalsListScreen extends ConsumerWidget {
  const GoalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_goalHistoryProvider);

    return Scaffold(
      appBar: const FitrackAppBar(title: 'My Goals'),
      body: historyAsync.when(
        loading: () => const Center(
          child:
              CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.textMuted, size: 36),
              const SizedBox(height: 8),
              const Text('Failed to load goals',
                  style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              AppButton.ghost(
                label: 'Retry',
                onPressed: () => ref.invalidate(_goalHistoryProvider),
              ),
            ],
          ),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return _EmptyState(
              onAdd: () async {
                final added = await context.push<bool>('/goal/new');
                if (added == true) ref.invalidate(_goalHistoryProvider);
              },
            );
          }

          final active = goals.where((g) => g.isActive).toList();
          final completed = goals.where((g) => !g.isActive).toList();

          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: () => ref.refresh(_goalHistoryProvider.future),
            child: CustomScrollView(
              slivers: [
                // ── Active goal ─────────────────────────────────────────
                if (active.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader('Active Goal'),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _GoalTile(
                        goal: active[i],
                        onTap: () async {
                          final changed = await context.push<bool>(
                              '/goal/${active[i].id}/edit',
                              extra: active[i]);
                          if (changed == true) {
                            ref.invalidate(_goalHistoryProvider);
                          }
                        },
                      ),
                      childCount: active.length,
                    ),
                  ),
                ],

                // ── Add new (only when none active) ─────────────────────
                if (active.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: AppButton.outlined(
                        label: 'Add New Goal',
                        icon: LucideIcons.plus,
                        onPressed: () async {
                          final added =
                              await context.push<bool>('/goal/new');
                          if (added == true) {
                            ref.invalidate(_goalHistoryProvider);
                          }
                        },
                      ),
                    ),
                  ),

                // ── Completed goals ─────────────────────────────────────
                if (completed.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: _SectionHeader('Completed'),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _GoalTile(goal: completed[i]),
                      childCount: completed.length,
                    ),
                  ),
                ],

                SliverToBoxAdapter(
                  child: SizedBox(
                      height:
                          MediaQuery.of(context).padding.bottom + 24),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Goal tile ─────────────────────────────────────────────────────────────────

class _GoalTile extends StatelessWidget {
  final WeightGoal goal;
  final VoidCallback? onTap;

  const _GoalTile({required this.goal, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLose = goal.goalType == 'LOSE';
    final color = goal.isActive ? AppTheme.primary : AppTheme.textMuted;
    final startFmt = _fmtDate(goal.startDate);
    final targetFmt = _fmtDate(goal.targetDate);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: goal.isActive
              ? Border.all(color: AppTheme.primary.withValues(alpha: 0.35), width: 1)
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLose ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isLose ? 'Lose Weight' : 'Gain Weight',
                        style: TextStyle(
                          color: goal.isActive
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(isActive: goal.isActive),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Target: ${goal.targetWeight} kg  ·  $startFmt → $targetFmt',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),

            if (onTap != null)
              const Icon(LucideIcons.chevronRight,
                  size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat('MMM d, yy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}

// ── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withValues(alpha: 0.15)
            : AppTheme.divider,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Active' : 'Done',
        style: TextStyle(
          color: isActive ? AppTheme.primary : AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(LucideIcons.target,
                  color: AppTheme.textMuted, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'No goals yet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set a weight goal to track your progress and stay motivated.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Add Your First Goal',
              icon: LucideIcons.plus,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/progress_provider.dart';
import '../providers/stats_provider.dart';
import '../repositories/goal_repository.dart';
import '../widgets/app_bar.dart';
import '../widgets/goal_progress_card.dart';
import '../widgets/period_selector.dart';
import '../widgets/stats_section.dart';
import '../widgets/weight_chart.dart';
import '../widgets/app_button.dart';
import '../widgets/skeleton.dart';

class ProgressGraphScreen extends ConsumerWidget {
  const ProgressGraphScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final progressAsync = ref.watch(progressDataProvider);
    final statsAsync = ref.watch(statsProvider);

    Future<void> goToEditGoal(int id) async {
      // Fetch the full goal object so GoalEditScreen can pre-fill the form.
      final goal = await ref.read(goalRepositoryProvider).getActiveGoal();
      if (!context.mounted) return;
      final changed = await context.push<bool>(
        '/goal/$id/edit',
        extra: goal,
      );
      if (changed == true) ref.invalidate(progressDataProvider);
    }

    Future<void> goToNewGoal() async {
      final changed = await context.push<bool>('/goal/new');
      if (changed == true) ref.invalidate(progressDataProvider);
    }

    void goToAllGoals() => context.push('/goals');

    return Scaffold(
      appBar: const FitrackAppBar(title: 'Progress'),
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        onRefresh: () async {
          await Future.wait([
            ref.refresh(progressDataProvider.future),
            ref.refresh(statsProvider.future),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 84,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Goal progress card ──────────────────────────────────
                  progressAsync.when(
                    data: (data) => GoalProgressCard(
                      goalProgress: data.goalProgress,
                      onAddGoal: data.goalProgress == null
                          ? goToNewGoal
                          : null,
                      onEditGoal: data.goalId != null
                          ? () => goToEditGoal(data.goalId!)
                          : null,
                      onViewAll: goToAllGoals,
                    ),
                    loading: () => _GoalCardSkeleton(),
                    error: (_, __) => GoalProgressCard(
                      goalProgress: null,
                      onAddGoal: goToNewGoal,
                      onViewAll: goToAllGoals,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Period selector ─────────────────────────────────────
                  PeriodSelector(
                    selected: period,
                    onChanged: (p) =>
                        ref.read(selectedPeriodProvider.notifier).state = p,
                  ),

                  const SizedBox(height: 20),

                  // ── Weight chart ────────────────────────────────────────
                  Container(
                    height: 300,
                    padding: const EdgeInsets.fromLTRB(4, 12, 16, 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: progressAsync.when(
                      data: (data) => WeightChart(points: data.chart),
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.textMuted, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load chart',
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            AppButton.ghost(
                              label: 'Retry',
                              onPressed: () => ref.invalidate(progressDataProvider),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Stats section ─────────────────────────────────────────
                  const SizedBox(height: 24),
                  statsAsync.when(
                    data: (stats) => StatsSection(stats: stats),
                    loading: () => const _StatsSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loader for the goal card ────────────────────────────────────────
class _GoalCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120, height: 13),
                      SizedBox(height: 10),
                      SkeletonBox(width: 90, height: 44),
                      SizedBox(height: 10),
                      SkeletonBox(width: 100, height: 14),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                SkeletonBox(width: 90, height: 90, radius: 45),
              ],
            ),
            const SizedBox(height: 16),
            const SkeletonBox(height: 8, radius: 4),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: 110, height: 36, radius: 8),
                SkeletonBox(width: 90, height: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loader for the stats section ────────────────────────────────────
class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          4,
          (_) => Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}


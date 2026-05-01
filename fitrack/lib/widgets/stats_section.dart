import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme.dart';
import '../models/stats.dart';

/// The full stats section: 4 stat cards + milestones timeline.
class StatsSection extends StatelessWidget {
  final StatsData stats;

  const StatsSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isLose = stats.isLose;
    final avgLabel = isLose ? 'Avg. Loss / Week' : 'Avg. Gain / Week';
    final avgIcon = isLose ? LucideIcons.trendingDown : LucideIcons.trendingUp;
    final avgColor = AppTheme.primary;

    final avg = stats.avgChangePerWeek;
    final vsSign = (stats.vsLastMonthPct ?? 0) >= 0 ? '↑' : '↓';
    final vsAbs = (stats.vsLastMonthPct ?? 0).abs();
    final vsPositive = (stats.vsLastMonthPct ?? 0) >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 4 stat cards (2×2 grid) ────────────────────────────────────────
        Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatCard(
                  icon: avgIcon,
                  iconColor: avgColor,
                  label: avgLabel,
                  value: avg != null ? '${avg.abs().toStringAsFixed(2)} kg' : '-- kg',
                  sub: stats.vsLastMonthPct != null
                      ? '$vsSign $vsAbs% vs last month'
                      : null,
                  subColor: vsPositive ? AppTheme.primary : Colors.redAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: isLose ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                  iconColor: const Color(0xFF8B5CF6),
                  label: stats.bestWeightLabel,
                  value: stats.bestWeight != null
                      ? '${stats.bestWeight!.toStringAsFixed(1)} kg'
                      : '-- kg',
                  sub: stats.bestWeightDate,
                  subColor: const Color(0xFF8B5CF6),
                ),
              ),
            ],
        ),
        const SizedBox(height: 10),
        Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.flame,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Best Streak',
                  value: '${stats.bestStreak} days',
                  sub: (stats.bestStreakStart != null && stats.bestStreakEnd != null)
                      ? '${stats.bestStreakStart} – ${stats.bestStreakEnd}'
                      : null,
                  subColor: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: LucideIcons.calendarDays,
                  iconColor: AppTheme.accentBlue,
                  label: 'Days Logged',
                  value: '${stats.daysLoggedMonth} / ${stats.daysInMonth}',
                  sub: 'This Month',
                  subColor: AppTheme.accentBlue,
                ),
              ),
            ],
        ),

        // ── Milestones ─────────────────────────────────────────────────────
        if (stats.milestones.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Milestones',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // "View All" placeholder — extend later if needed
            ],
          ),
          const SizedBox(height: 14),
          _MilestonesTimeline(milestones: stats.milestones),
        ],
      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub ?? '',
            style: TextStyle(
              color: subColor ?? AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Milestones horizontal timeline ───────────────────────────────────────────

class _MilestonesTimeline extends StatelessWidget {
  final List<Milestone> milestones;

  const _MilestonesTimeline({required this.milestones});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < milestones.length; i++) ...[
          Expanded(child: _MilestoneNode(milestone: milestones[i])),
          if (i < milestones.length - 1)
            _ConnectorLine(achieved: milestones[i].achieved),
        ],
      ],
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  final bool achieved;

  const _ConnectorLine({required this.achieved});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 2,
      margin: const EdgeInsets.only(top: 19),
      decoration: BoxDecoration(
        color: achieved ? AppTheme.primary : AppTheme.divider,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _MilestoneNode extends StatelessWidget {
  final Milestone milestone;

  const _MilestoneNode({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final m = milestone;

    Widget icon;
    Color ringColor;
    Color bgColor;

    if (m.achieved) {
      // Green check
      ringColor = AppTheme.primary;
      bgColor = AppTheme.primary.withValues(alpha: 0.12);
      icon = const Icon(Icons.check, color: AppTheme.primary, size: 18);
    } else if (m.isNext) {
      // Star (active/next milestone)
      ringColor = AppTheme.primary;
      bgColor = AppTheme.primary.withValues(alpha: 0.08);
      icon = const Icon(Icons.star, color: AppTheme.primary, size: 18);
    } else {
      // Lock (not yet reached)
      ringColor = AppTheme.divider;
      bgColor = AppTheme.surface;
      icon = const Icon(Icons.lock_outline, color: AppTheme.textMuted, size: 16);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
          // Circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: m.isNext ? 2 : 1.5),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 8),

          // Label
          Text(
            m.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: m.achieved
                  ? AppTheme.textPrimary
                  : m.isNext
                      ? AppTheme.textPrimary
                      : AppTheme.textMuted,
              fontSize: 11,
              fontWeight: m.isNext ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),

          // Sub-label
          if (m.achieved && m.date != null)
            Text(
              m.date!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            )
          else if (m.isNext && m.progress != null && m.total != null)
            Text(
              '${m.progress} / ${m.total} kg',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (!m.achieved && m.remaining != null)
            Text(
              '${m.remaining} kg to go',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 10,
              ),
            ),
        ],
    );
  }
}

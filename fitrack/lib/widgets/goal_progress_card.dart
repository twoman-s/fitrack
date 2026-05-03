import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme.dart';
import '../models/progress.dart';

/// Top-of-screen card showing goal progress stats + circular arc.
class GoalProgressCard extends StatelessWidget {
  final GoalProgress? goalProgress;
  final VoidCallback? onAddGoal;
  final VoidCallback? onEditGoal;
  final VoidCallback? onViewAll;

  const GoalProgressCard({
    super.key,
    this.goalProgress,
    this.onAddGoal,
    this.onEditGoal,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (goalProgress == null) {
      return _NoGoalCard(onAddGoal: onAddGoal, onViewAll: onViewAll);
    }
    final gp = goalProgress!;
    final isLose = gp.goalType == 'LOSE';
    final pct = gp.percentage.clamp(0.0, 100.0);
    final verb = isLose ? 'Lost' : 'Gained';

    // changed > 0 = making progress; changed < 0 = going wrong direction.
    final isGoodDirection = gp.changed >= 0;
    const badColor = Color(0xFFEF4444); // red
    final accentColor = isGoodDirection ? AppTheme.primary : badColor;
    // Good direction: LOSE → weight going down (trendingDown), GAIN → going up (trendingUp).
    // Bad direction:  LOSE → weight going up (trendingUp bad),  GAIN → going down (trendingDown bad).
    final badgeIcon = isLose
        ? (isGoodDirection ? LucideIcons.trendingDown : LucideIcons.trendingUp)
        : (isGoodDirection ? LucideIcons.trendingUp : LucideIcons.trendingDown);
    // Prefix sign: bad LOSE = gained (+), bad GAIN = lost (-).
    final changedPrefix = isGoodDirection ? '' : (isLose ? '+' : '-');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: stats + arc ────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: text stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight $verb So Far',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$changedPrefix${gp.changed.abs().toStringAsFixed(1)}',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, left: 4),
                          child: Text(
                            'kg',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${gp.startWeight} kg',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            LucideIcons.arrowRight,
                            size: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Text(
                          '${gp.currentWeight} kg',
                          style: TextStyle(
                            color: isGoodDirection
                                ? AppTheme.textPrimary
                                : badColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right: circular arc
              _CircularProgressRing(percentage: pct, color: accentColor),
            ],
          ),

          const SizedBox(height: 16),

          // ── Bottom row: badge + remaining ───────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge — expands to fill same width as stats column
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.30),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: accentColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isGoodDirection
                              ? "You're ${pct.toStringAsFixed(0)}% of the way to your goal!"
                              : "You're moving away from your goal!",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Remaining — aligned under the ring (same 90 px width)
              SizedBox(
                width: 90,
                child: Text(
                  '${gp.remaining} kg to go',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          // ── Action buttons ──────────────────────────────────────────────
          if (onEditGoal != null || onViewAll != null) ...
            [
              const SizedBox(height: 12),
              const Divider(color: AppTheme.divider, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onViewAll != null)
                    Expanded(
                      child: _CardAction(
                        icon: LucideIcons.list,
                        label: 'View all',
                        onTap: onViewAll!,
                      ),
                    ),
                  if (onEditGoal != null && onViewAll != null)
                    Container(
                      width: 1,
                      height: 32,
                      color: AppTheme.divider,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  if (onEditGoal != null)
                    Expanded(
                      child: _CardAction(
                        icon: LucideIcons.pencil,
                        label: 'Edit goal',
                        onTap: onEditGoal!,
                      ),
                    ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Circular progress ring ────────────────────────────────────────────────────

class _CircularProgressRing extends StatelessWidget {
  final double percentage;
  final Color color;

  const _CircularProgressRing({required this.percentage, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: CustomPaint(
        painter: _ArcPainter(percentage: percentage, color: color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const Text(
                'of goal',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double percentage;
  final Color color;

  _ArcPainter({required this.percentage, required this.color});

  // Arc spans 270°; gap (90°) centered at the bottom (6 o'clock = π/2).
  // Start: 135° = 3π/4 rad (bottom-left, 4:30 position in Flutter canvas).
  static const double _startAngle = math.pi * 0.75;
  static const double _sweepTotal = math.pi * 1.5; // 270°
  static const double _strokeWidth = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepTotal,
      false,
      Paint()
        ..color = const Color(0xFF2D2D2D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    final sweep = _sweepTotal * (percentage.clamp(0, 100) / 100);
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        _startAngle,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.percentage != percentage || old.color != color;
}

// ── No goal placeholder ───────────────────────────────────────────────────────

class _NoGoalCard extends StatelessWidget {
  final VoidCallback? onAddGoal;
  final VoidCallback? onViewAll;

  const _NoGoalCard({this.onAddGoal, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.target, color: AppTheme.textMuted, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No goal set',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Set a goal to start tracking your progress.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAddGoal != null)
                GestureDetector(
                  onTap: onAddGoal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
                    ),
                    child: const Text(
                      'Add Goal',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (onViewAll != null) ...
            [
              const SizedBox(height: 12),
              const Divider(color: AppTheme.divider, height: 1),
              const SizedBox(height: 12),
              _CardAction(
                icon: LucideIcons.list,
                label: 'View all goals',
                onTap: onViewAll!,
              ),
            ],
        ],
      ),
    );
  }
}

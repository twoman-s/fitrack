class Milestone {
  final String label;
  final bool achieved;
  final String? date;
  final double? progress;
  final double? total;
  final double? remaining;
  final bool isNext;

  const Milestone({
    required this.label,
    required this.achieved,
    this.date,
    this.progress,
    this.total,
    this.remaining,
    required this.isNext,
  });

  factory Milestone.fromJson(Map<String, dynamic> j) => Milestone(
        label: j['label'] as String,
        achieved: j['achieved'] as bool,
        date: j['date'] as String?,
        progress: _d(j['progress']),
        total: _d(j['total']),
        remaining: _d(j['remaining']),
        isNext: j['is_next'] as bool,
      );

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class StatsData {
  final double? avgChangePerWeek;
  final int? vsLastMonthPct;
  final double? bestWeight;
  final String? bestWeightDate;
  final String bestWeightLabel;
  final int bestStreak;
  final String? bestStreakStart;
  final String? bestStreakEnd;
  final int daysLoggedMonth;
  final int daysInMonth;
  final String? goalType;
  final List<Milestone> milestones;

  const StatsData({
    this.avgChangePerWeek,
    this.vsLastMonthPct,
    this.bestWeight,
    this.bestWeightDate,
    required this.bestWeightLabel,
    required this.bestStreak,
    this.bestStreakStart,
    this.bestStreakEnd,
    required this.daysLoggedMonth,
    required this.daysInMonth,
    this.goalType,
    required this.milestones,
  });

  factory StatsData.fromJson(Map<String, dynamic> j) => StatsData(
        avgChangePerWeek: _d(j['avg_change_per_week']),
        vsLastMonthPct: j['vs_last_month_pct'] as int?,
        bestWeight: _d(j['best_weight']),
        bestWeightDate: j['best_weight_date'] as String?,
        bestWeightLabel: (j['best_weight_label'] as String?) ?? 'Best Weight',
        bestStreak: (j['best_streak'] as int?) ?? 0,
        bestStreakStart: j['best_streak_start'] as String?,
        bestStreakEnd: j['best_streak_end'] as String?,
        daysLoggedMonth: (j['days_logged_month'] as int?) ?? 0,
        daysInMonth: (j['days_in_month'] as int?) ?? 30,
        goalType: j['goal_type'] as String?,
        milestones: (j['milestones'] as List? ?? [])
            .map((e) => Milestone.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool get isLose => goalType != 'GAIN';
}

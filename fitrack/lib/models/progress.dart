class ProgressChartPoint {
  final String date;
  final double? morningWeight;
  final double? eveningWeight;
  final double primaryWeight;
  final double? trend;

  ProgressChartPoint({
    required this.date,
    this.morningWeight,
    this.eveningWeight,
    required this.primaryWeight,
    this.trend,
  });

  factory ProgressChartPoint.fromJson(Map<String, dynamic> json) {
    return ProgressChartPoint(
      date: json['date'] as String,
      morningWeight: _toDouble(json['morning_weight']),
      eveningWeight: _toDouble(json['evening_weight']),
      primaryWeight: _toDouble(json['primary_weight'])!,
      trend: _toDouble(json['trend']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class GoalProgress {
  final String goalType; // 'LOSE' | 'GAIN'
  final double startWeight;
  final double currentWeight;
  final double targetWeight;
  final double changed; // positive = making progress
  final double percentage; // 0–100
  final double remaining;

  GoalProgress({
    required this.goalType,
    required this.startWeight,
    required this.currentWeight,
    required this.targetWeight,
    required this.changed,
    required this.percentage,
    required this.remaining,
  });

  factory GoalProgress.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) =>
        (v is int) ? v.toDouble() : (v is String) ? double.parse(v) : v as double;
    return GoalProgress(
      goalType: json['goal_type'] as String,
      startWeight: d(json['start_weight']),
      currentWeight: d(json['current_weight']),
      targetWeight: d(json['target_weight']),
      changed: d(json['changed']),
      percentage: d(json['percentage']),
      remaining: d(json['remaining']),
    );
  }
}

class ProgressData {
  final String period;
  final List<ProgressChartPoint> chart;
  final GoalProgress? goalProgress;
  final int? goalId;

  ProgressData({
    required this.period,
    required this.chart,
    this.goalProgress,
    this.goalId,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      period: json['period'] as String,
      chart: (json['chart'] as List)
          .map((e) => ProgressChartPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      goalProgress: json['goal_progress'] != null
          ? GoalProgress.fromJson(
              json['goal_progress'] as Map<String, dynamic>)
          : null,
      goalId: json['goal_id'] as int?,
    );
  }
}

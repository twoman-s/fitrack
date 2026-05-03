class WeightGoal {
  final int id;
  final String goalType; // 'LOSE' or 'GAIN'
  final double? currentWeight;
  final double targetWeight;
  final String startDate;
  final String targetDate;
  final bool isActive;
  final String? completedAt;
  final String? createdAt;

  WeightGoal({
    required this.id,
    required this.goalType,
    this.currentWeight,
    required this.targetWeight,
    required this.startDate,
    required this.targetDate,
    required this.isActive,
    this.completedAt,
    this.createdAt,
  });

  factory WeightGoal.fromJson(Map<String, dynamic> json) {
    return WeightGoal(
      id: json['id'],
      goalType: json['goal_type'],
      currentWeight: json['current_weight'] != null
          ? double.parse(json['current_weight'].toString())
          : null,
      targetWeight: double.parse(json['target_weight'].toString()),
      startDate: json['start_date'],
      targetDate: json['target_date'],
      isActive: json['is_active'] ?? true,
      completedAt: json['completed_at'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'goal_type': goalType,
        if (currentWeight != null) 'current_weight': currentWeight,
        'target_weight': targetWeight,
        'start_date': startDate,
        'target_date': targetDate,
      };

  WeightGoal copyWith({bool? isActive}) => WeightGoal(
        id: id,
        goalType: goalType,
        currentWeight: currentWeight,
        targetWeight: targetWeight,
        startDate: startDate,
        targetDate: targetDate,
        isActive: isActive ?? this.isActive,
        completedAt: completedAt,
        createdAt: createdAt,
      );
}

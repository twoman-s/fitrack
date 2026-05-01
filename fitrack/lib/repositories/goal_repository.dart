import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../models/goal.dart';
import '../services/api_service.dart';

final goalRepositoryProvider = Provider((ref) {
  final api = ref.watch(apiServiceProvider);
  return GoalRepository(api.client);
});

class GoalRepository {
  final Dio _client;

  GoalRepository(this._client);

  /// Returns the active goal, or null if none.
  Future<WeightGoal?> getActiveGoal() async {
    final response = await _client.get(ApiConfig.goal);
    if (response.data == null) return null;
    return WeightGoal.fromJson(response.data);
  }

  /// Creates a new goal. Throws [DioException] with 409 if one is already active.
  Future<WeightGoal> createGoal({
    required String goalType,
    required double targetWeight,
    required String startDate,
    required String targetDate,
  }) async {
    final response = await _client.post(
      ApiConfig.goal,
      data: {
        'goal_type': goalType,
        'target_weight': targetWeight,
        'start_date': startDate,
        'target_date': targetDate,
      },
    );
    return WeightGoal.fromJson(response.data);
  }

  /// Updates a goal by id. Pass `isActive: false` to mark it complete.
  Future<WeightGoal> updateGoal(
    int id, {
    String? goalType,
    double? targetWeight,
    String? startDate,
    String? targetDate,
    bool? isActive,
  }) async {
    final Map<String, dynamic> data = {};
    if (goalType != null) data['goal_type'] = goalType;
    if (targetWeight != null) data['target_weight'] = targetWeight;
    if (startDate != null) data['start_date'] = startDate;
    if (targetDate != null) data['target_date'] = targetDate;
    if (isActive != null) data['is_active'] = isActive;

    final response = await _client.patch(ApiConfig.goalDetail(id), data: data);
    return WeightGoal.fromJson(response.data);
  }

  /// Returns all goals for the user, newest first.
  Future<List<WeightGoal>> getGoalHistory() async {
    final response = await _client.get(ApiConfig.goalHistory);
    return (response.data as List)
        .map((e) => WeightGoal.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

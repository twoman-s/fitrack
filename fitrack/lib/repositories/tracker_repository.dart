import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../models/dashboard.dart';
import '../models/weight.dart';
import '../services/api_service.dart';

final trackerRepositoryProvider = Provider((ref) {
  final api = ref.watch(apiServiceProvider);
  return TrackerRepository(api.client);
});

class TrackerRepository {
  final Dio _client;

  TrackerRepository(this._client);

  Future<DashboardData> getDashboard() async {
    final response = await _client.get(ApiConfig.dashboard);
    return DashboardData.fromJson(response.data);
  }

  Future<WeightEntry> addWeight({
    required String date,
    double? morningWeight,
    String? morningWeightTime,
    double? eveningWeight,
    String? eveningWeightTime,
    String? notes,
    bool clearMorning = false,
    bool clearEvening = false,
  }) async {
    final Map<String, dynamic> data = {'date': date};

    if (clearMorning) {
      data['morning_weight'] = null;
      data['morning_weight_time'] = null;
    } else {
      if (morningWeight != null) data['morning_weight'] = morningWeight;
      if (morningWeightTime != null) data['morning_weight_time'] = morningWeightTime;
    }

    if (clearEvening) {
      data['evening_weight'] = null;
      data['evening_weight_time'] = null;
    } else {
      if (eveningWeight != null) data['evening_weight'] = eveningWeight;
      if (eveningWeightTime != null) data['evening_weight_time'] = eveningWeightTime;
    }

    if (notes != null) data['notes'] = notes;

    final response = await _client.post(ApiConfig.weights, data: data);
    return WeightEntry.fromJson(response.data);
  }

  Future<List<WeightAggregate>> getWeightHistory(String range) async {
    final response = await _client.get(
      ApiConfig.weights,
      queryParameters: {'range': range},
    );
    return (response.data as List)
        .map((e) => WeightAggregate.fromJson(e))
        .toList();
  }

  Future<PaginatedWeightResponse> getPaginatedWeights({
    int limit = 30,
    int offset = 0,
    String? startDate,
    String? endDate,
    int? month,
    int? year,
  }) async {
    final Map<String, dynamic> params = {
      'range': 'daily',
      'limit': limit,
      'offset': offset,
    };
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (month != null) params['month'] = month;
    if (year != null) params['year'] = year;

    final response = await _client.get(
      ApiConfig.weights,
      queryParameters: params,
    );
    return PaginatedWeightResponse.fromJson(response.data);
  }

  Future<void> deleteWeight(String date) async {
    await _client.delete(
      ApiConfig.weights,
      queryParameters: {'date': date},
    );
  }

  Future<PhotoSession> getPhotosByDate(String date) async {
    final response = await _client.get(
      ApiConfig.photos,
      queryParameters: {'date': date},
    );
    return PhotoSession.fromJson(response.data);
  }

  Future<ProgressPhoto> uploadPhoto({
    required String date,
    required String photoType,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'date': date,
      'photo_type': photoType,
      'image': await MultipartFile.fromFile(filePath),
    });

    final response = await _client.post(ApiConfig.photosUpload, data: formData);
    return ProgressPhoto.fromJson(response.data);
  }

  Future<Map<String, String?>> comparePhotos({
    required String fromDate,
    required String toDate,
    String type = 'FRONT',
  }) async {
    final response = await _client.get(
      ApiConfig.photosCompare,
      queryParameters: {'from': fromDate, 'to': toDate, 'type': type},
    );
    return {
      'from_image': response.data['from_image'],
      'to_image': response.data['to_image'],
    };
  }

  Future<List<HeatmapEntry>> getHeatmap(String monthStr) async {
    final response = await _client.get(
      ApiConfig.heatmap,
      queryParameters: {'month': monthStr},
    );
    return (response.data as List)
        .map((e) => HeatmapEntry.fromJson(e))
        .toList();
  }
}

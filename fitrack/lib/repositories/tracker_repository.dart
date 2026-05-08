import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../models/crop_transform.dart';
import '../models/dashboard.dart';
import '../models/kyc.dart';
import '../models/weight.dart';
import '../models/progress.dart';
import '../models/stats.dart';
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

  Future<ProgressPhoto> uploadPhotoBytes({
    required String date,
    required String photoType,
    required List<int> bytes,
    String filename = 'photo.jpg',
    List<int>? normalizedBytes,
    CropTransform? cropTransform,
  }) async {
    final map = <String, dynamic>{
      'date': date,
      'photo_type': photoType,
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    };

    if (normalizedBytes != null) {
      map['normalized_image'] = MultipartFile.fromBytes(
        normalizedBytes,
        filename: 'normalized_$filename',
      );
    }

    if (cropTransform != null) {
      map['crop_scale'] = cropTransform.scale;
      map['crop_offset_x'] = cropTransform.offsetX;
      map['crop_offset_y'] = cropTransform.offsetY;
      map['crop_aspect_ratio'] = cropTransform.aspectRatio;
    }

    final formData = FormData.fromMap(map);
    final response = await _client.post(ApiConfig.photosUpload, data: formData);
    return ProgressPhoto.fromJson(response.data);
  }

  Future<void> deletePhoto(int id) async {
    await _client.delete(ApiConfig.photoDetail(id));
  }

  /// Returns the URL of the most recent photo for [photoType], or null if none.
  Future<String?> getLatestPhoto({required String photoType}) async {
    try {
      final response = await _client.get(
        ApiConfig.photosLatest,
        queryParameters: {'type': photoType},
      );
      return response.data['image_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Returns the latest photo data including crop metadata for [photoType].
  Future<Map<String, dynamic>?> getLatestPhotoWithCrop({
    required String photoType,
    String? excludeDate,
  }) async {
    try {
      final queryParams = {'type': photoType};
      if (excludeDate != null) {
        queryParams['exclude_date'] = excludeDate;
      }
      final response = await _client.get(
        ApiConfig.photosLatest,
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['image_url'] == null) return null;
      return data;
    } catch (_) {
      return null;
    }
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

  Future<ProgressData> getProgress(String period) async {
    final response = await _client.get(
      ApiConfig.progress,
      queryParameters: {'period': period},
    );
    return ProgressData.fromJson(response.data);
  }

  Future<StatsData> getStats() async {
    final response = await _client.get(ApiConfig.stats);
    return StatsData.fromJson(response.data);
  }

  // ── KYC ──────────────────────────────────────────────────────────────────

  Future<KycStatus> getKycStatus() async {
    final response = await _client.get(ApiConfig.kycStatus);
    return KycStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> submitKycConsent({
    required bool termsAccepted,
    required bool privacyAccepted,
    required bool photoProcessingAccepted,
    required bool sensitiveDataAccepted,
    required bool adultConfirmed,
    required bool selfPhotoConfirmed,
  }) async {
    await _client.post(ApiConfig.kycConsent, data: {
      'terms_accepted': termsAccepted,
      'privacy_accepted': privacyAccepted,
      'photo_processing_accepted': photoProcessingAccepted,
      'sensitive_data_accepted': sensitiveDataAccepted,
      'adult_confirmed': adultConfirmed,
      'self_photo_confirmed': selfPhotoConfirmed,
    });
  }

  Future<KycStatus> completeKyc({
    required String dob,
    List<double>? faceEmbedding,
  }) async {
    final response = await _client.post(ApiConfig.kycComplete, data: {
      'dob': dob,
      if (faceEmbedding != null) 'face_embedding': faceEmbedding,
    });
    return KycStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Updates only the face embedding for an already-approved KYC user.
  /// Call this when [KycStatus.faceEmbedding] is null after KYC was done
  /// before the embedding feature existed.
  Future<void> updateKycEmbedding(List<double> embedding) async {
    await _client.patch(ApiConfig.kycUpdateEmbedding, data: {
      'face_embedding': embedding,
    });
  }
}

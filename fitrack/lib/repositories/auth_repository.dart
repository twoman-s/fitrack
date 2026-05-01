import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

final authRepositoryProvider = Provider((ref) {
  final api = ref.watch(apiServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return AuthRepository(api.client, storage);
});

class AuthRepository {
  final Dio _client;
  final StorageService _storageService;

  AuthRepository(this._client, this._storageService);

  /// Returns true if the user has no active goal and should see onboarding.
  Future<bool> login(String username, String password) async {
    final response = await _client.post(
      ApiConfig.login,
      data: {
        'username': username,
        'password': password,
      },
    );
    
    if (response.statusCode == 200) {
      await _storageService.saveTokens(
        access: response.data['access'],
        refresh: response.data['refresh'],
      );
      await _storageService.saveUsername(username);
      return response.data['show_onboarding'] == true;
    } else {
      throw Exception('Failed to login');
    }
  }

  /// Signs up and auto-logs in. Returns true if onboarding should be shown.
  Future<bool> signup(String username, String password) async {
    final response = await _client.post(
      ApiConfig.signup,
      data: {
        'username': username,
        'password': password,
      },
    );
    
    if (response.statusCode != 201) {
      throw Exception(response.data['detail'] ?? 'Failed to signup');
    }

    // Auto-login after successful signup (new users always need onboarding)
    return await login(username, password);
  }

  Future<void> logout() async {
    await _storageService.clearTokens();
    await _storageService.clearUsername();
  }

  Future<UserProfile> getProfile() async {
    final response = await _client.get(ApiConfig.profile);
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile({
    required String name,
    required String email,
  }) async {
    final response = await _client.patch(
      ApiConfig.profile,
      data: {'name': name, 'email': email},
    );
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Throws a [String] error message on failure.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.post(
      ApiConfig.changePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    if (response.statusCode != 200) {
      throw response.data['detail'] ?? 'Failed to change password.';
    }
  }
}

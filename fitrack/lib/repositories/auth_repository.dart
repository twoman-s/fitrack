import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
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

  Future<void> login(String username, String password) async {
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
    } else {
      throw Exception('Failed to login');
    }
  }

  Future<void> signup(String username, String password) async {
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
  }

  Future<void> logout() async {
    await _storageService.clearTokens();
  }
}

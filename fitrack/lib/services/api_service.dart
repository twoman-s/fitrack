import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'storage_service.dart';
import '../core/router.dart';

final apiServiceProvider = Provider((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiService(storage, ref);
});

class ApiService {
  late final Dio _dio;
  final StorageService _storageService;
  final ProviderRef _ref;

  ApiService(this._storageService, this._ref) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ));
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Skip token only for public auth endpoints (login, signup, token refresh)
          final unauthenticated = [
            ApiConfig.login,
            ApiConfig.signup,
            ApiConfig.refresh,
          ];
          final isPublic = unauthenticated.any((p) => options.path == p);
          if (!isPublic) {
            final token = await _storageService.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final path = error.requestOptions.path;
          final isPublic = path == ApiConfig.login || path == ApiConfig.signup || path == ApiConfig.refresh;
          if (error.response?.statusCode == 401 && !isPublic) {
            // Token might be expired, try to refresh
            final success = await _refreshToken();
            if (success) {
              // Retry the failed request
              final opts = error.requestOptions;
              final token = await _storageService.getAccessToken();
              opts.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            } else {
              // Refresh failed, logout
              await _storageService.clearTokens();
              _ref.read(routerProvider).go('/login');
              return handler.next(error);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    try {
      final refresh = await _storageService.getRefreshToken();
      if (refresh == null) return false;

      // Use a separate Dio instance to avoid interceptor loops
      final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final response = await refreshDio.post(
        ApiConfig.refresh,
        data: {'refresh': refresh},
      );

      if (response.statusCode == 200) {
        final newAccess = response.data['access'];
        // Note: SimpleJWT by default only returns a new access token on refresh,
        // unless ROTATE_REFRESH_TOKENS is true (which it is in our django backend).
        // If it also returns a new refresh token, we save it.
        final newRefresh = response.data['refresh'] ?? refresh;
        
        await _storageService.saveTokens(access: newAccess, refresh: newRefresh);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Dio get client => _dio;
}

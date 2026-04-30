import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../services/storage_service.dart';

enum AppAuthState { initializing, authenticated, unauthenticated }

final authStateProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(storageServiceProvider),
  );
});

class AuthNotifier extends StateNotifier<AppAuthState> {
  final AuthRepository _repository;
  final StorageService _storageService;

  AuthNotifier(this._repository, this._storageService) : super(AppAuthState.initializing) {
    _checkToken();
  }

  Future<void> _checkToken() async {
    final hasToken = await _storageService.hasToken();
    state = hasToken ? AppAuthState.authenticated : AppAuthState.unauthenticated;
  }

  Future<void> login(String username, String password) async {
    await _repository.login(username, password);
    state = AppAuthState.authenticated;
  }

  Future<void> signup(String username, String password) async {
    await _repository.signup(username, password);
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AppAuthState.unauthenticated;
  }
}

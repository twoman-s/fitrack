import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../services/storage_service.dart';

enum AppAuthState { initializing, authenticated, unauthenticated }

/// True when the user should be routed to onboarding immediately after login/signup.
final showOnboardingProvider = StateProvider<bool>((ref) => false);

final authStateProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier(
    ref,
    ref.watch(authRepositoryProvider),
    ref.watch(storageServiceProvider),
  );
});

class AuthNotifier extends StateNotifier<AppAuthState> {
  final Ref _ref;
  final AuthRepository _repository;
  final StorageService _storageService;

  AuthNotifier(this._ref, this._repository, this._storageService) : super(AppAuthState.initializing) {
    _checkToken();
  }

  Future<void> _checkToken() async {
    final hasToken = await _storageService.hasToken();
    state = hasToken ? AppAuthState.authenticated : AppAuthState.unauthenticated;
  }

  Future<void> login(String username, String password) async {
    final showOnboarding = await _repository.login(username, password);
    _ref.read(showOnboardingProvider.notifier).state = showOnboarding;
    state = AppAuthState.authenticated;
  }

  Future<void> signup(String username, String password) async {
    final showOnboarding = await _repository.signup(username, password);
    _ref.read(showOnboardingProvider.notifier).state = showOnboarding;
    state = AppAuthState.authenticated;
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AppAuthState.unauthenticated;
  }
}

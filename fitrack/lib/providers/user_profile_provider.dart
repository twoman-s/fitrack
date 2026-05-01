import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

final userProfileProvider =
    AsyncNotifierProvider.autoDispose<UserProfileNotifier, UserProfile>(
        UserProfileNotifier.new);

class UserProfileNotifier extends AutoDisposeAsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    return ref.read(authRepositoryProvider).getProfile();
  }

  Future<void> save({required String name, required String email}) async {
    final updated = await ref
        .read(authRepositoryProvider)
        .updateProfile(name: name, email: email);
    state = AsyncData(updated);
  }
}

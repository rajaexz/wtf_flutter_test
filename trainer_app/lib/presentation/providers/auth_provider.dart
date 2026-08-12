import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_entity.dart';
import 'repository_providers.dart';

final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, UserEntity?>(
  CurrentUserNotifier.new,
);

class CurrentUserNotifier extends AsyncNotifier<UserEntity?> {
  static const _seededTrainer = UserEntity(
    id: 'trainer_aarav',
    role: UserRole.trainer,
    name: 'Aarav',
    email: 'aarav@wtf.coach',
  );

  @override
  Future<UserEntity?> build() async {
    final saved = await ref.read(authRepositoryProvider).getCurrentUser();
    return saved;
  }

  Future<void> loginAsAarav() async {
    await ref.read(authRepositoryProvider).saveUser(_seededTrainer);
    state = const AsyncData(_seededTrainer);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).clearUser();
    state = const AsyncData(null);
  }
}

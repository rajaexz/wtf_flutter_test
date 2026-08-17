import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';
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
    if (saved != null) {
      await NotificationService.instance.registerUser(saved.id);
      await ref.read(chatRepositoryProvider).connect(saved.id);
    }
    return saved;
  }

  Future<void> loginAsAarav() async {
    await ref.read(authRepositoryProvider).saveUser(_seededTrainer);
    await NotificationService.instance.registerUser(_seededTrainer.id);
    await ref.read(chatRepositoryProvider).connect(_seededTrainer.id);
    state = const AsyncData(_seededTrainer);
  }

  Future<void> logout() async {
    await ref.read(chatRepositoryProvider).disconnect();
    await ref.read(authRepositoryProvider).clearUser();
    state = const AsyncData(null);
  }
}

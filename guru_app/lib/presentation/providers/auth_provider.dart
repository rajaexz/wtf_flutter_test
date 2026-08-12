import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/user_entity.dart';
import 'repository_providers.dart';

final currentUserProvider = AsyncNotifierProvider<CurrentUserNotifier, UserEntity?>(
  CurrentUserNotifier.new,
);

class CurrentUserNotifier extends AsyncNotifier<UserEntity?> {
  @override
  Future<UserEntity?> build() async {
    return ref.read(authRepositoryProvider).getCurrentUser();
  }

  Future<void> createProfile(String name, UserEntity trainer) async {
    final user = UserEntity(
      id: 'member_${const Uuid().v4()}',
      role: UserRole.member,
      name: name,
      email: '${name.toLowerCase().replaceAll(' ', '_')}@guru.app',
      assignedTrainerId: trainer.id,
    );
    await ref.read(authRepositoryProvider).saveUser(user);
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).clearUser();
    state = const AsyncData(null);
  }
}

final availableTrainersProvider = Provider<List<UserEntity>>(
  (ref) => ref.read(authRepositoryProvider).getAvailableTrainers(),
);

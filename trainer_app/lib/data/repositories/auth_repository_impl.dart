import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  final LocalStorage _storage;

  AuthRepositoryImpl(this._storage);

  static const _currentUserKey = 'current_user';

  static final List<UserEntity> _seededTrainers = [
    const UserEntity(
      id: 'trainer_aarav',
      role: UserRole.trainer,
      name: 'Aarav',
      email: 'aarav@wtf.coach',
      avatarUrl: null,
    ),
    const UserEntity(
      id: 'trainer_priya',
      role: UserRole.trainer,
      name: 'Priya',
      email: 'priya@wtf.coach',
      avatarUrl: null,
    ),
  ];

  @override
  Future<UserEntity?> getCurrentUser() async {
    final data = _storage.get(_storage.user, _currentUserKey);
    if (data == null) return null;
    return _userFromMap(data);
  }

  @override
  Future<void> saveUser(UserEntity user) async {
    await _storage.put(_storage.user, _currentUserKey, _userToMap(user));
  }

  @override
  Future<void> clearUser() async {
    await _storage.user.delete(_currentUserKey);
  }

  @override
  List<UserEntity> getAvailableTrainers() => _seededTrainers;

  Map<String, dynamic> _userToMap(UserEntity u) => {
        'id': u.id,
        'role': u.role.name,
        'name': u.name,
        'email': u.email,
        'avatarUrl': u.avatarUrl,
        'assignedTrainerId': u.assignedTrainerId,
      };

  UserEntity _userFromMap(Map<String, dynamic> m) => UserEntity(
        id: m['id'] as String,
        role: UserRole.values.byName(m['role'] as String),
        name: m['name'] as String,
        email: m['email'] as String,
        avatarUrl: m['avatarUrl'] as String?,
        assignedTrainerId: m['assignedTrainerId'] as String?,
      );
}

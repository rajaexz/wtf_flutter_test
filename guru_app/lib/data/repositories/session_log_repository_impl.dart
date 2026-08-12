import 'dart:async';

import '../../domain/entities/session_log_entity.dart';
import '../../domain/repositories/session_log_repository.dart';
import '../datasources/local_storage.dart';

class SessionLogRepositoryImpl implements SessionLogRepository {
  final LocalStorage _storage;

  SessionLogRepositoryImpl(this._storage);

  final Map<String, StreamController<List<SessionLogEntity>>> _controllers = {};

  StreamController<List<SessionLogEntity>> _controllerFor(String memberId) {
    return _controllers.putIfAbsent(
      memberId,
      () => StreamController<List<SessionLogEntity>>.broadcast(),
    );
  }

  void _emit(String memberId) {
    _controllerFor(memberId).add(_getSync(memberId));
  }

  List<SessionLogEntity> _getSync(String memberId) {
    return _storage
        .getAll(_storage.sessionLogs)
        .map(SessionLogEntity.fromJson)
        .where((l) => l.memberId == memberId)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Stream<List<SessionLogEntity>> watchLogs(String memberId) {
    final controller = _controllerFor(memberId);
    Future.microtask(() => _emit(memberId));
    return controller.stream;
  }

  @override
  Future<List<SessionLogEntity>> getLogs(String memberId) async => _getSync(memberId);

  @override
  Future<void> saveLog(SessionLogEntity log) async {
    await _storage.put(_storage.sessionLogs, log.id, log.toJson());
    _emit(log.memberId);
  }

  @override
  Future<void> updateLog(SessionLogEntity log) async {
    await _storage.put(_storage.sessionLogs, log.id, log.toJson());
    _emit(log.memberId);
  }
}

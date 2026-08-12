import 'dart:async';

import '../../domain/entities/call_request_entity.dart';
import '../../domain/entities/room_meta_entity.dart';
import '../../domain/repositories/call_request_repository.dart';
import '../datasources/local_storage.dart';

class CallRequestRepositoryImpl implements CallRequestRepository {
  final LocalStorage _storage;

  CallRequestRepositoryImpl(this._storage);

  final Map<String, StreamController<List<CallRequestEntity>>> _controllers = {};

  StreamController<List<CallRequestEntity>> _controllerFor(String userId) {
    return _controllers.putIfAbsent(
      userId,
      () => StreamController<List<CallRequestEntity>>.broadcast(),
    );
  }

  void _emit(String userId) {
    final requests = _getSync(userId);
    _controllerFor(userId).add(requests);
  }

  List<CallRequestEntity> _getSync(String userId) {
    return _storage
        .getAll(_storage.callRequests)
        .map(CallRequestEntity.fromJson)
        .where((r) => r.memberId == userId || r.trainerId == userId)
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  @override
  Stream<List<CallRequestEntity>> watchRequests(String userId) {
    final controller = _controllerFor(userId);
    Future.microtask(() => _emit(userId));
    return controller.stream;
  }

  @override
  Future<List<CallRequestEntity>> getRequests(String userId) async => _getSync(userId);

  @override
  Future<void> createRequest(CallRequestEntity request) async {
    await _storage.put(_storage.callRequests, request.id, request.toJson());
    _emit(request.memberId);
    _emit(request.trainerId);
  }

  @override
  Future<void> updateStatus(
    String requestId,
    CallRequestStatus status, {
    String? declineReason,
  }) async {
    final data = _storage.get(_storage.callRequests, requestId);
    if (data == null) return;
    final request = CallRequestEntity.fromJson(data).copyWith(
      status: status,
      declineReason: declineReason,
    );
    await _storage.put(_storage.callRequests, requestId, request.toJson());
    _emit(request.memberId);
    _emit(request.trainerId);
  }

  @override
  Future<bool> hasConflict(String trainerId, DateTime scheduledFor) async {
    final slot = scheduledFor.millisecondsSinceEpoch ~/ (30 * 60 * 1000);
    final all = _storage.getAll(_storage.callRequests).map(CallRequestEntity.fromJson);
    return all.any((r) {
      if (r.trainerId != trainerId) return false;
      if (r.status != CallRequestStatus.approved) return false;
      final rSlot = r.scheduledFor.millisecondsSinceEpoch ~/ (30 * 60 * 1000);
      return rSlot == slot;
    });
  }

  @override
  Future<RoomMetaEntity?> getRoomMeta(String callRequestId) async {
    final data = _storage.get(_storage.roomMeta, callRequestId);
    if (data == null) return null;
    return RoomMetaEntity.fromJson(data);
  }

  @override
  Future<void> saveRoomMeta(RoomMetaEntity meta) async {
    await _storage.put(_storage.roomMeta, meta.callRequestId, meta.toJson());
  }
}

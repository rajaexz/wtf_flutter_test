import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/app_logger.dart';
import '../../domain/entities/call_request_entity.dart';
import '../../domain/entities/room_meta_entity.dart';
import '../../domain/repositories/call_request_repository.dart';
import '../datasources/local_storage.dart';

class CallRequestRepositoryImpl implements CallRequestRepository {
  CallRequestRepositoryImpl(this._storage);

  final LocalStorage _storage;

  static const _tokenServerUrl = String.fromEnvironment(
    'TOKEN_SERVER_URL',
    defaultValue: 'http://192.168.1.2:3000',
  );

  final Map<String, StreamController<List<CallRequestEntity>>> _controllers = {};
  final Map<String, Timer> _pollers = {};

  StreamController<List<CallRequestEntity>> _controllerFor(String userId) {
    return _controllers.putIfAbsent(
      userId,
      () => StreamController<List<CallRequestEntity>>.broadcast(
        onListen: () => _startPolling(userId),
        onCancel: () {
          Future.delayed(const Duration(seconds: 2), () {
            final c = _controllers[userId];
            if (c != null && !c.hasListener) {
              _stopPolling(userId);
            }
          });
        },
      ),
    );
  }

  void _startPolling(String userId) {
    _pollers[userId]?.cancel();
    _syncFromServer(userId);
    _pollers[userId] = Timer.periodic(const Duration(seconds: 2), (_) {
      _syncFromServer(userId);
    });
  }

  void _stopPolling(String userId) {
    _pollers.remove(userId)?.cancel();
  }

  void _emit(String userId) {
    final requests = _getSync(userId);
    final c = _controllers[userId];
    if (c != null && !c.isClosed) c.add(requests);
  }

  List<CallRequestEntity> _getSync(String userId) {
    return _storage
        .getAll(_storage.callRequests)
        .map(CallRequestEntity.fromJson)
        .where((r) => r.memberId == userId || r.trainerId == userId)
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  Future<void> _syncFromServer(String userId) async {
    try {
      final uri = Uri.parse('$_tokenServerUrl/call-requests?userId=$userId');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['requests'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      var changed = false;
      for (final raw in list) {
        final remote = CallRequestEntity.fromJson(raw);
        final local = _storage.get(_storage.callRequests, remote.id);
        if (local == null ||
            local['status'] != remote.status.name ||
            local['note'] != remote.note ||
            local['declineReason'] != remote.declineReason) {
          await _storage.put(_storage.callRequests, remote.id, remote.toJson());
          changed = true;
        }
      }
      if (changed) {
        logger.schedule('[SCHEDULE] synced ${list.length} requests for $userId');
        _emit(userId);
      }
    } catch (e) {
      logger.schedule('[SCHEDULE] sync failed: $e');
    }
  }

  @override
  Stream<List<CallRequestEntity>> watchRequests(String userId) {
    final controller = _controllerFor(userId);
    Future.microtask(() {
      _emit(userId);
      _syncFromServer(userId);
    });
    return controller.stream;
  }

  @override
  Future<List<CallRequestEntity>> getRequests(String userId) async {
    await _syncFromServer(userId);
    return _getSync(userId);
  }

  @override
  Future<void> createRequest(CallRequestEntity request) async {
    await _storage.put(_storage.callRequests, request.id, request.toJson());
    _emit(request.memberId);
    _emit(request.trainerId);

    try {
      final res = await http
          .post(
            Uri.parse('$_tokenServerUrl/call-requests'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('create ${res.statusCode}');
      }
      logger.schedule('[SCHEDULE] request posted ${request.id}');
    } catch (e) {
      logger.schedule('[SCHEDULE] create post failed: $e');
    }
  }

  @override
  Future<void> updateStatus(
    String requestId,
    CallRequestStatus status, {
    String? declineReason,
  }) async {
    var data = _storage.get(_storage.callRequests, requestId);

    // Always patch server so peer can sync even if local missing
    try {
      await http
          .post(
            Uri.parse('$_tokenServerUrl/call-requests/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': requestId,
              'status': status.name,
              if (declineReason != null) 'declineReason': declineReason,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      logger.schedule('[SCHEDULE] status post failed: $e');
    }

    if (data != null) {
      final request = CallRequestEntity.fromJson(data).copyWith(
        status: status,
        declineReason: declineReason,
      );
      await _storage.put(_storage.callRequests, requestId, request.toJson());
      _emit(request.memberId);
      _emit(request.trainerId);
    }
  }

  @override
  Future<bool> hasConflict(String trainerId, DateTime scheduledFor) async {
    await _syncFromServer(trainerId);
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

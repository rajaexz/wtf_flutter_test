import '../entities/call_request_entity.dart';
import '../entities/room_meta_entity.dart';

abstract class CallRequestRepository {
  Stream<List<CallRequestEntity>> watchRequests(String userId);
  Future<List<CallRequestEntity>> getRequests(String userId);
  Future<void> createRequest(CallRequestEntity request);
  Future<void> updateStatus(String requestId, CallRequestStatus status, {String? declineReason});
  Future<bool> hasConflict(String trainerId, DateTime scheduledFor);
  Future<RoomMetaEntity?> getRoomMeta(String callRequestId);
  Future<void> saveRoomMeta(RoomMetaEntity meta);
}

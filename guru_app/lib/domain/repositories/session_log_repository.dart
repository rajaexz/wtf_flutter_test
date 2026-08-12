import '../entities/session_log_entity.dart';

abstract class SessionLogRepository {
  Stream<List<SessionLogEntity>> watchLogs(String memberId);
  Future<List<SessionLogEntity>> getLogs(String memberId);
  Future<void> saveLog(SessionLogEntity log);
  Future<void> updateLog(SessionLogEntity log);
}

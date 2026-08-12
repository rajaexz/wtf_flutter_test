import '../entities/session_log_entity.dart';
import '../repositories/session_log_repository.dart';

class SaveSessionLogUseCase {
  final SessionLogRepository _repository;

  SaveSessionLogUseCase(this._repository);

  Future<void> call(SessionLogEntity log) => _repository.saveLog(log);
}

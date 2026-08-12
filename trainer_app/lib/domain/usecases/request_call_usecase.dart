import '../../core/error/failures.dart';
import '../entities/call_request_entity.dart';
import '../repositories/call_request_repository.dart';

class RequestCallUseCase {
  final CallRequestRepository _repository;

  RequestCallUseCase(this._repository);

  Future<Failure?> call(CallRequestEntity request) async {
    if (request.scheduledFor.isBefore(DateTime.now())) {
      return const ValidationFailure('Cannot select a past time.');
    }
    final conflict = await _repository.hasConflict(request.trainerId, request.scheduledFor);
    if (conflict) {
      return const ConflictFailure('This slot is already booked.');
    }
    await _repository.createRequest(request);
    return null;
  }
}

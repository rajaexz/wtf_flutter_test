abstract class Failure {
  final String message;
  const Failure(this.message);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

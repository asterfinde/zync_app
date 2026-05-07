/// Base class for all typed failure descriptors.
///
/// Each subtype maps to a specific error domain. Use [code] for programmatic
/// handling and [message] for human-readable context.
sealed class Failure {
  final String code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const Failure({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });
}

/// Network or connectivity error (HTTP, timeout, no connection).
final class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'network');
}

/// Authentication or authorization error.
final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'auth');
}

/// Input validation error (precondition not met at system boundary).
final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'validation');
}

/// Business rule violation within the domain.
final class DomainFailure extends Failure {
  const DomainFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'domain');
}

/// Native platform or plugin error.
final class PlatformFailure extends Failure {
  const PlatformFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'platform');
}

/// Catch-all for unclassified errors. Prefer a specific subtype when possible.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'unexpected');
}

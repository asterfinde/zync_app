import 'package:nunakin_app/shared/failure.dart';

/// Represents the outcome of an operation that can succeed or fail.
///
/// Use [Success] for successful results and [FailureResult] for failures.
/// Pattern match exhaustively or use [fold] for transformation.
///
/// Example:
/// ```dart
/// Result<User> result = await getUser(id);
/// result.fold(
///   (user) => show(user),
///   (failure) => showError(failure.message),
/// );
/// ```
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(value: final v) => v,
        FailureResult<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        FailureResult<T>(failure: final f) => f,
      };

  R fold<R>(R Function(T) onSuccess, R Function(Failure) onFailure) =>
      switch (this) {
        Success<T>(value: final v) => onSuccess(v),
        FailureResult<T>(failure: final f) => onFailure(f),
      };
}

/// A successful [Result] carrying a value of type [T].
final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

/// A failed [Result] carrying a [Failure] descriptor.
final class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);
}

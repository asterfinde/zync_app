# Sem 1 - Día 2 — Result<T> y Failure

**Rama**: refactor/sem1-result-failure

**Estado previo**: Día 1 ✅ mergeado (PRs #144 + #145) — scaffold completo en main

---

| Archivos a crear | Archivo | Descripción |
|------------------|---------|-------------|
| lib/shared/result.dart | `lib/shared/result.dart` | Sealed Result con fold, valueOrNull, failureOrNull |
| lib/shared/failure.dart | `lib/shared/failure.dart` | Sealed Failure + 6 subtipos |
| lib/shared/unit.dart | `lib/shared/unit.dart` | Tipo Unit singleton |
| test/shared/result_test.dart | `test/shared/result_test.dart` | Tests unitarios ≥95% coverage |

---

## Tarea 1 — lib/shared/result.dart
```dart
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

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);
}
```
---

## Tarea 2 — lib/shared/failure.dart

```dart
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

final class NetworkFailure extends Failure {
  const NetworkFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'network');
}

final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'auth');
}

final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'validation');
}

final class DomainFailure extends Failure {
  const DomainFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'domain');
}

final class PlatformFailure extends Failure {
  const PlatformFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'platform');
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({required super.message, super.cause, super.stackTrace})
      : super(code: 'unexpected');
}
```
---

## Tarea 3 — lib/shared/unit.dart

```dart
class Unit {
  const Unit._();
  static const Unit instance = Unit._();
}
```
---

## Tarea 4 — test/shared/result_test.dart

**Casos a cubrir (≥95% coverage):**

- **Success.fold** invoca onSuccess con el valor correcto.
- **FailureResult.fold** invoca onFailure con el Failure correcto.
- **Pattern matching exhaustivo** (Dart no compila si falta rama).
- **valueOrNull** retorna T en Success, null en FailureResult.
- **failureOrNull** retorna null en Success, Failure en FailureResult.
- **isSuccess / isFailure** son mutuamente excluyentes.

---

## Restricciones
- No reemplazar ningún try/catch existente — solo se publican los tipos.
- No usar print() — los tests no requieren logging.
- Sin imports de Firebase ni Flutter en shared/ — dominio puro.

---

## Entregable
PR: refactor(shared): add Result<T> and Failure types

## Criterio de done
 - flutter analyze verde.
 - flutter test verde (suite existente + nuevos).
 - Coverage ≥95% en result.dart y failure.dart.
 - No se modificó ningún archivo fuera de lib/shared/ y test/shared/.
 
---  

**Siguiente: Día 3 usa Opus (DI módulos + Contract DbC — más interdependencias)**
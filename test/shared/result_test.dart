import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/shared/failure.dart';
import 'package:nunakin_app/shared/result.dart';

void main() {
  group('Result<T>', () {
    group('Success', () {
      test('isSuccess is true', () {
        final result = Success<int>(42);
        expect(result.isSuccess, isTrue);
      });

      test('isFailure is false', () {
        final result = Success<int>(42);
        expect(result.isFailure, isFalse);
      });

      test('valueOrNull returns the value', () {
        final result = Success<String>('hello');
        expect(result.valueOrNull, 'hello');
      });

      test('failureOrNull returns null', () {
        final result = Success<String>('hello');
        expect(result.failureOrNull, isNull);
      });

      test('fold invokes onSuccess with the value', () {
        final result = Success<int>(7);
        final output = result.fold((v) => v * 2, (_) => -1);
        expect(output, 14);
      });

      test('fold does not invoke onFailure', () {
        final result = Success<int>(1);
        var failureCalled = false;
        result.fold(
          (v) => v,
          (_) { failureCalled = true; return 0; },
        );
        expect(failureCalled, isFalse);
      });

      test('works with nullable value type', () {
        final result = Success<String?>(null);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });
    });

    group('FailureResult', () {
      final failure = NetworkFailure(message: 'no connection');

      test('isFailure is true', () {
        final result = FailureResult<int>(failure);
        expect(result.isFailure, isTrue);
      });

      test('isSuccess is false', () {
        final result = FailureResult<int>(failure);
        expect(result.isSuccess, isFalse);
      });

      test('valueOrNull returns null', () {
        final result = FailureResult<int>(failure);
        expect(result.valueOrNull, isNull);
      });

      test('failureOrNull returns the failure', () {
        final result = FailureResult<int>(failure);
        expect(result.failureOrNull, same(failure));
      });

      test('fold invokes onFailure with the failure', () {
        final result = FailureResult<int>(failure);
        final output = result.fold((_) => 'ok', (f) => f.code);
        expect(output, 'network');
      });

      test('fold does not invoke onSuccess', () {
        final result = FailureResult<int>(failure);
        var successCalled = false;
        result.fold(
          (_) { successCalled = true; return 0; },
          (f) => 0,
        );
        expect(successCalled, isFalse);
      });
    });

    group('pattern matching exhaustiveness', () {
      test('switch on Result covers both cases without default', () {
        Result<int> result = Success<int>(1);
        final label = switch (result) {
          Success() => 'success',
          FailureResult() => 'failure',
        };
        expect(label, 'success');
      });

      test('switch on FailureResult covers both cases without default', () {
        Result<int> result = FailureResult<int>(
          DomainFailure(message: 'invariant violated'),
        );
        final label = switch (result) {
          Success() => 'success',
          FailureResult() => 'failure',
        };
        expect(label, 'failure');
      });
    });
  });

  group('Failure subtypes', () {
    test('NetworkFailure has code "network"', () {
      const f = NetworkFailure(message: 'timeout');
      expect(f.code, 'network');
      expect(f.message, 'timeout');
    });

    test('AuthFailure has code "auth"', () {
      const f = AuthFailure(message: 'invalid token');
      expect(f.code, 'auth');
    });

    test('ValidationFailure has code "validation"', () {
      const f = ValidationFailure(message: 'email required');
      expect(f.code, 'validation');
    });

    test('DomainFailure has code "domain"', () {
      const f = DomainFailure(message: 'rule violated');
      expect(f.code, 'domain');
    });

    test('PlatformFailure has code "platform"', () {
      const f = PlatformFailure(message: 'channel error');
      expect(f.code, 'platform');
    });

    test('UnexpectedFailure has code "unexpected"', () {
      const f = UnexpectedFailure(message: 'unknown');
      expect(f.code, 'unexpected');
    });

    test('cause and stackTrace are optional and default to null', () {
      const f = NetworkFailure(message: 'x');
      expect(f.cause, isNull);
      expect(f.stackTrace, isNull);
    });

    test('cause is forwarded when provided', () {
      final cause = Exception('root cause');
      final f = NetworkFailure(message: 'x', cause: cause);
      expect(f.cause, same(cause));
    });

    test('stackTrace is forwarded when provided', () {
      final st = StackTrace.current;
      final f = NetworkFailure(message: 'x', stackTrace: st);
      expect(f.stackTrace, same(st));
    });
  });
}

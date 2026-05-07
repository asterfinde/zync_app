import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/shared/contract.dart';

void main() {
  group('Contract.requires', () {
    test('condition true → no lanza', () {
      expect(() => Contract.requires(true, 'ok'), returnsNormally);
    });

    test('condition false → lanza ContractViolation con kind precondition', () {
      expect(
        () => Contract.requires(false, 'must be positive'),
        throwsA(
          isA<ContractViolation>()
              .having((e) => e.kind, 'kind', 'precondition')
              .having((e) => e.description, 'description', 'must be positive'),
        ),
      );
    });
  });

  group('Contract.ensures', () {
    test('condition true → no lanza', () {
      expect(() => Contract.ensures(true, 'ok'), returnsNormally);
    });

    test('condition false → lanza ContractViolation con kind postcondition', () {
      expect(
        () => Contract.ensures(false, 'state must be silent'),
        throwsA(
          isA<ContractViolation>()
              .having((e) => e.kind, 'kind', 'postcondition'),
        ),
      );
    });
  });

  group('Contract.invariant', () {
    test('condition true → no lanza', () {
      expect(() => Contract.invariant(true, 'ok'), returnsNormally);
    });

    test('condition false → lanza ContractViolation con kind invariant', () {
      expect(
        () => Contract.invariant(false, 'circle must have owner'),
        throwsA(
          isA<ContractViolation>()
              .having((e) => e.kind, 'kind', 'invariant'),
        ),
      );
    });
  });

  group('ContractViolation.toString', () {
    test('incluye kind y description', () {
      final v = ContractViolation('precondition', 'x must be positive');
      expect(v.toString(), contains('precondition'));
      expect(v.toString(), contains('x must be positive'));
    });
  });
}

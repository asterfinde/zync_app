import 'package:flutter/foundation.dart';

/// Thrown when a [Contract] condition is violated in debug mode.
/// No-op in release builds (assert is compiled out).
class ContractViolation extends Error {
  final String kind; // 'precondition' | 'postcondition' | 'invariant'
  final String description;

  ContractViolation(this.kind, this.description);

  @override
  String toString() => 'ContractViolation [$kind]: $description';
}

/// Design-by-Contract guards for use cases and state machine transitions.
///
/// All methods are no-ops in release builds — the assert block is
/// stripped by the compiler. Use at entry/exit of critical use cases only.
abstract final class Contract {
  static void requires(bool condition, String description) {
    assert(() {
      if (!condition) {
        if (kDebugMode) debugPrint('❌ [Contract.requires] $description');
        throw ContractViolation('precondition', description);
      }
      return true;
    }());
  }

  static void ensures(bool condition, String description) {
    assert(() {
      if (!condition) {
        if (kDebugMode) debugPrint('❌ [Contract.ensures] $description');
        throw ContractViolation('postcondition', description);
      }
      return true;
    }());
  }

  static void invariant(bool condition, String description) {
    assert(() {
      if (!condition) {
        if (kDebugMode) debugPrint('❌ [Contract.invariant] $description');
        throw ContractViolation('invariant', description);
      }
      return true;
    }());
  }
}

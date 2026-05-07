/// Represents the absence of a meaningful return value.
///
/// Use as [Result<Unit>] for use cases that succeed without returning data.
class Unit {
  const Unit._();
  static const Unit instance = Unit._();
}

/// Phase 7.9 — Clock injection.
///
/// Every time-dependent code path that we want to control in tests calls
/// [Clock.instance.now] instead of `DateTime.now()`. Production uses the
/// real wall clock; tests swap [Clock.instance] for a deterministic stub.
///
/// The replacement scope per `MASTER_PLAN.md` §7.9:
///   - `lib/utils/validators.dart`
///   - `lib/providers/app_state.dart` (recurring + PIN-lockout logic)
///   - `lib/utils/notification_helper.dart`
///   - `lib/utils/home_widget_helper.dart`
///   - `lib/utils/pin_security_helper.dart`
///
/// UI/export code paths (formatters, export filename timestamps) keep
/// using `DateTime.now()` directly — their behaviour is observed through
/// goldens / smoke tests, not unit tests, so the indirection doesn't pay
/// for itself there.
class Clock {
  const Clock();

  /// Production implementation — defers to the real wall clock.
  DateTime now() => DateTime.now();

  /// Active clock. Tests swap in a [FakeClock] / fixed [Clock] for
  /// deterministic time. Always reset in tearDown to avoid leaking
  /// state across test files.
  static Clock instance = const Clock();
}

/// Deterministic clock for tests. Either a fixed instant or a sequence.
class FakeClock implements Clock {
  /// Returns this fixed [DateTime] on every call to [now].
  FakeClock.fixed(this._fixed) : _sequence = null;

  /// Yields each [DateTime] in [sequence] in order, then sticks on the
  /// last value once exhausted. Useful for "before lockout / after
  /// lockout" style tests.
  FakeClock.sequence(List<DateTime> sequence)
      : assert(sequence.isNotEmpty, 'sequence must not be empty'),
        _fixed = null,
        _sequence = List.unmodifiable(sequence);

  final DateTime? _fixed;
  final List<DateTime>? _sequence;
  int _index = 0;

  @override
  DateTime now() {
    final fixed = _fixed;
    if (fixed != null) return fixed;
    final seq = _sequence!;
    final value = seq[_index < seq.length ? _index : seq.length - 1];
    if (_index < seq.length - 1) _index++;
    return value;
  }
}

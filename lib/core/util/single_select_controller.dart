import 'package:flutter/foundation.dart';

/// Reusable single-selection controller for chip rows used by the
/// figma-ui-redesign feature.
///
/// At any moment **exactly one** value from [values] is selected (or `null`
/// only when constructed with `initial: null` and [select] has not yet been
/// called), and that value is the most recently passed argument to [select]
/// (or the configured `initial` when no taps have occurred).
///
/// Concrete consumers in the figma-ui-redesign feature:
///
/// * `workshop_map_screen.dart` Browse tab category chip row
///   `All / Repair / Car Wash / Parts`         — Requirements 7.2, 11.4.
/// * `document_vault_screen.dart` category chip row
///   `All / Insurance / Tax / Receipt / Warranty` — Requirement 10.1.
///
/// The controller is the canonical state behind Property 11 (chip
/// single-selection invariant) — see `design.md` and tasks 3.14 / 3.15.
///
/// Single mutable field invariant: `_selected` is the only mutable state.
/// [values] is wrapped in [List.unmodifiable] at construction so the
/// constraint set cannot be mutated out from underneath the controller.
///
/// Extends [ChangeNotifier] so widgets can `ListenableBuilder` /
/// `AnimatedBuilder` against it to rebuild only the affected chip row when
/// the selection changes.
///
/// See: figma-ui-redesign Requirements 7.2, 10.1, 11.4.
class SingleSelectController<T> extends ChangeNotifier {
  /// Creates a controller constrained to [values] with optional [initial]
  /// selection.
  ///
  /// If [initial] is non-null it must be present in [values]; this is
  /// enforced by an `assert` in debug builds.
  SingleSelectController({required List<T> values, T? initial})
      : assert(
          initial == null || values.contains(initial),
          'initial selection must be present in values',
        ),
        values = List<T>.unmodifiable(values),
        _selected = initial;

  /// Immutable list of values this controller is constrained to.
  final List<T> values;

  T? _selected;

  /// Currently selected value, or `null` if the controller was constructed
  /// with `initial: null` and [select] has not yet been called.
  T? get selected => _selected;

  /// Selects [value], which must be present in [values].
  ///
  /// If [value] is already the current selection this is a no-op and
  /// listeners are **not** notified. Otherwise [_selected] is updated and
  /// [notifyListeners] is called exactly once.
  void select(T value) {
    assert(
      values.contains(value),
      'value must be present in values',
    );
    if (value == _selected) {
      return;
    }
    _selected = value;
    notifyListeners();
  }
}

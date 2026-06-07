import 'package:flutter/foundation.dart';

/// Reusable in-flight guard used by gestures that must produce **exactly one**
/// downstream effect per user-initiated activation, even when the underlying
/// async work has not yet completed.
///
/// Two concrete consumers in the figma-ui-redesign feature:
///
/// * `home_screen.dart` wallet `Top Up` action — Requirement 4.8.
/// * `login_screen.dart` `Sign In` button       — Requirement 5.7.
///
/// Behaviour of [run]:
///
/// 1. If [isRunning] is already `true` (a previous invocation is still in
///    flight), the call is **dropped** — `action` is never invoked and the
///    method returns `null` synchronously (well, on the next microtask).
/// 2. Otherwise, [isRunning] flips to `true` and listeners are notified so
///    UI can render a loading state and disable its trigger.
/// 3. `action()` is awaited; the resolved value is returned.
/// 4. In a `finally` block, [isRunning] flips back to `false` and listeners
///    are notified again so UI can return to its idle state.
///
/// The `try/finally` guarantees the gate releases even when `action` throws;
/// the thrown error is rethrown to the caller so existing error-handling
/// pathways (banners, snack bars, navigation) are preserved.
///
/// The gate extends [ChangeNotifier] so widgets can `AnimatedBuilder` /
/// `ListenableBuilder` against it to drive `AppGradientButton.isLoading`,
/// `enabled` flags, and equivalent visual treatments without manually
/// threading a separate `bool` through `setState`.
///
/// Single mutable field invariant: `_inFlight` is the only mutable state.
/// The async hop inside [run] is a deliberate concession: the in-flight
/// contract is inherently asynchronous and cannot be expressed without it.
///
/// See: figma-ui-redesign Requirements 4.8, 5.7.
class InFlightGate extends ChangeNotifier {
  bool _inFlight = false;

  /// `true` while an invocation passed to [run] has been started and not yet
  /// completed (either successfully or with an error). `false` otherwise.
  bool get isRunning => _inFlight;

  /// Executes [action] under the in-flight guard.
  ///
  /// Returns the value produced by [action], or `null` if the call was
  /// dropped because a previous invocation was still in flight.
  ///
  /// If [action] throws, the gate is released before the error is rethrown.
  Future<T?> run<T>(Future<T> Function() action) async {
    if (_inFlight) {
      return null;
    }
    _inFlight = true;
    notifyListeners();
    try {
      final T result = await action();
      return result;
    } finally {
      _inFlight = false;
      notifyListeners();
    }
  }
}

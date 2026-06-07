import 'package:flutter/material.dart';

/// Internal press-scale wrapper used across the DriveCare+ button family
/// (`AppPrimaryButton`, `AppSecondaryButton`, `AppIconButton`,
/// `AppGradientButton`).
///
/// Renders [child] inside a gesture detector that animates the child's
/// scale to `0.98x` while pressed and back to `1.0x` on release, with each
/// scale transition completing in `100 ms` (within the 80–200 ms inclusive
/// window required by Requirement 3.2 of the figma-ui-redesign spec).
///
/// When [enabled] is `false`, the gesture handlers are detached entirely so
/// tap, press, and long-press gestures cannot reach the underlying [child]
/// (Requirement 3.12). Callers are responsible for applying the disabled
/// visual treatment to [child] itself (e.g. muted surface, muted foreground)
/// since this wrapper is purely concerned with gestures and scale animation.
///
/// This widget is library-private (leading underscore in the filename) and
/// is not exported from `ui.dart`.
class PressScale extends StatefulWidget {
  /// Visible content. Should already be sized and styled by the caller.
  final Widget child;

  /// Tap callback. Ignored when [enabled] is `false`.
  final VoidCallback? onTap;

  /// When `false`, all gestures are detached and the wrapper renders the
  /// child at its resting scale.
  final bool enabled;

  /// Optional semantics override. Buttons that wrap their own [Semantics]
  /// node should pass `null` (the default) so the wrapper does not emit a
  /// duplicate semantics tree.
  final String? semanticsLabel;

  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.semanticsLabel,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  // The press-scale animation lives outside the `AppMotion` token scale
  // (which is 150/300/500 ms). The 100 ms target is a Component_Library
  // constant explicitly called out in Requirement 3.2 (within 80–200 ms
  // inclusive) and is not a duration represented in the Token_Set, so it
  // does not conflict with Requirement 3.11's literal-free rule.
  static const Duration _pressDuration = Duration(milliseconds: 100);
  static const double _restingScale = 1.0;
  static const double _pressedScale = 0.98;

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
  }

  void _handleTap() {
    if (!widget.enabled) return;
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final Widget animated = AnimatedScale(
      scale: _pressed ? _pressedScale : _restingScale,
      duration: _pressDuration,
      curve: Curves.easeOut,
      child: widget.child,
    );

    final Widget gestures = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? _handleTapDown : null,
      onTapUp: widget.enabled ? _handleTapUp : null,
      onTapCancel: widget.enabled ? _handleTapCancel : null,
      onTap: widget.enabled ? _handleTap : null,
      child: animated,
    );

    if (widget.semanticsLabel == null) {
      return gestures;
    }
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticsLabel,
      child: gestures,
    );
  }
}

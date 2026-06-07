import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Token-styled skeleton placeholder for the DriveCare+ Component_Library.
///
/// While [enabled] is `true`, the widget covers [child] with a softly
/// pulsing block whose color alternates between `AppColors.muted` and the
/// same color at half opacity, giving callers a stand-in shape for content
/// that is loading. The pulse cycle uses `AppMotion.normal` (300 ms) so it
/// matches the wider motion language of the redesign (Requirement 11.8).
///
/// The placeholder takes its size from [child], so callers can size the
/// skeleton by handing in a sized stand-in — for example a `SizedBox` of
/// the expected card height, or the real widget that will be revealed once
/// the data arrives. The child itself is rendered fully transparent under
/// the shimmer so it contributes layout but is not visible.
///
/// While [enabled] is `false`, the widget renders [child] as-is and runs no
/// animation; this is the steady-state branch once data has loaded.
///
/// Every visual constant — duration, shimmer color, radius — flows from the
/// design-token extensions on `Theme.of(context)`; no hex colors or
/// token-equivalent literals are inlined (Requirement 3.11).
///
/// Example:
/// ```dart
/// AppSkeletonLoader(
///   enabled: isLoading,
///   child: SizedBox(
///     height: 96,
///     child: AppCard(child: SizedBox.shrink()),
///   ),
/// );
/// ```
class AppSkeletonLoader extends StatefulWidget {
  /// Layout child. While [enabled] is `true`, [child] is rendered
  /// transparent and used only for sizing; while `false`, it is rendered
  /// as-is.
  final Widget child;

  /// Whether the shimmer placeholder is active. Defaults to `true`.
  final bool enabled;

  const AppSkeletonLoader({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<AppSkeletonLoader> createState() => _AppSkeletonLoaderState();
}

class _AppSkeletonLoaderState extends State<AppSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Pulse cycle uses `AppMotion.normal` (300 ms); the shimmer alternates
    // direction via `repeat(reverse: true)` so each forward+reverse pair is
    // 600 ms total — slow enough to read as a calm pulse, fast enough to
    // signal in-flight work. Token is read at `initState` time because the
    // controller's duration cannot reach `Theme.of(context)` extensions
    // here, but `AppMotion.normal` is a compile-time constant so this
    // still satisfies the no-literal-in-tokens rule (Requirement 3.11).
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AppSkeletonLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Toggle the animation when the loading state flips, without
    // recreating the controller.
    if (widget.enabled && !oldWidget.enabled) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && oldWidget.enabled) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppRadiiExt radii = theme.extension<AppRadiiExt>()!;

    final Color baseColor = colors.muted;
    final Color highlightColor = colors.muted.withValues(alpha: 0.5);

    final BorderRadius borderRadius = BorderRadius.circular(radii.small);

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? sizingChild) {
        final Color tint =
            Color.lerp(baseColor, highlightColor, _controller.value) ??
                baseColor;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: borderRadius,
          ),
          // The original child is rendered fully transparent so it
          // contributes layout sizing but is not visible behind the
          // shimmer.
          child: Opacity(opacity: 0.0, child: sizingChild),
        );
      },
      child: widget.child,
    );
  }
}

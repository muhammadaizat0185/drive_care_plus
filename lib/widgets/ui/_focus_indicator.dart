import 'package:flutter/material.dart';

import '../../core/theme/tokens/tokens.dart';

/// Reusable focus indicator wrapper for the DriveCare+ Component_Library.
///
/// Wraps [child] in a [Focus] widget and tracks the focus state. When the
/// control is focused, paints a 2-logical-pixel border outline in the brand's
/// token colors: `AppColors.emerald500` (in light mode) / `AppColors.teal400`
/// (in dark mode) per Requirement 13.9.
///
/// The focus border has a radius matching [borderRadius] and is overlaid on
/// top of [child] so it doesn't affect its layout size or alignment.
class AppFocusIndicator extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final BorderRadius borderRadius;
  final FocusNode? focusNode;

  const AppFocusIndicator({
    super.key,
    required this.child,
    required this.enabled,
    required this.borderRadius,
    this.focusNode,
  });

  @override
  State<AppFocusIndicator> createState() => _AppFocusIndicatorState();
}

class _AppFocusIndicatorState extends State<AppFocusIndicator> {
  bool _focused = false;
  FocusNode? _internalFocusNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final Color outlineColor = theme.brightness == Brightness.light
        ? colors.emerald500
        : colors.teal400;

    return Focus(
      focusNode: _effectiveFocusNode,
      canRequestFocus: widget.enabled,
      onFocusChange: (focused) {
        setState(() {
          _focused = focused;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          widget.child,
          if (_focused && widget.enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    border: Border.all(color: outlineColor, width: 2.0),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

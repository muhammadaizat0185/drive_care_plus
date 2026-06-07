import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens/tokens.dart';

/// Token-driven text input for the DriveCare+ Component_Library.
///
/// Renders a Material `TextField` whose visual contract is defined by the
/// `inputDecorationTheme` registered in `AppTheme.buildTheme`:
///
///   * 2-logical-pixel border using `AppColors.border` in the resting state
///     (Requirement 3.3).
///   * 2-logical-pixel border using `AppColors.emerald500` while focused
///     (Requirement 3.4).
///   * 2-logical-pixel border using `AppColors.error` whenever
///     [errorText] is non-null, with the error string rendered below the
///     field (Requirement 3.5).
///   * `enabled = false` rejects all pointer and keyboard input
///     (Requirement 3.6).
///   * Corner radius `AppRadii.medium` (carried by the theme).
///
/// Per-instance overrides are limited to decoration content the theme
/// cannot resolve on its own (label, hint, prefix icon, suffix, error
/// text). All visual constants — colors, radii, padding, typography —
/// flow from the design-token extensions on `Theme.of(context)`; no hex
/// colors, spacing, radii, typography, or duration literals from the
/// Token_Sets are inlined (Requirement 3.11).
///
/// Example:
/// ```dart
/// AppTextField(
///   controller: _emailController,
///   label: 'Email address',
///   hintText: 'you@example.com',
///   prefixIcon: Icons.mail_outline,
///   keyboardType: TextInputType.emailAddress,
///   errorText: _emailError,
/// );
/// ```
class AppTextField extends StatelessWidget {
  /// Editing controller bound to the field's text value. Required so
  /// callers can read the entered text and observe changes.
  final TextEditingController controller;

  /// Optional label rendered above / inside the field via
  /// `InputDecoration.labelText`.
  final String? label;

  /// Optional placeholder rendered when the field is empty.
  final String? hintText;

  /// Optional leading icon rendered inside the field's prefix slot.
  final IconData? prefixIcon;

  /// Optional trailing widget (e.g. visibility toggle for password
  /// fields) rendered inside the field's suffix slot.
  final Widget? suffix;

  /// When `true`, the entered text is replaced by the platform obscuring
  /// character. Defaults to `false`.
  final bool obscureText;

  /// When `false`, the field rejects all pointer and keyboard input
  /// (Requirement 3.6). Defaults to `true`.
  final bool enabled;

  /// When non-null, the field renders its error border treatment and
  /// displays the string below the field (Requirement 3.5).
  final String? errorText;

  /// Optional keyboard type passed straight through to the underlying
  /// `TextField`.
  final TextInputType? keyboardType;

  /// Optional input formatters passed straight through to the underlying
  /// `TextField`.
  final List<TextInputFormatter>? inputFormatters;

  /// Optional change callback invoked on every keystroke.
  final ValueChanged<String>? onChanged;

  /// Optional focus node so callers can drive focus from outside.
  final FocusNode? focusNode;

  /// Optional max-length constraint passed to the underlying `TextField`.
  /// When set, the field also enforces the limit via
  /// `MaxLengthEnforcement.enforced`.
  final int? maxLength;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.focusNode,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    // Prefix-icon color tracks the foreground token in the active state
    // and softens to the muted-foreground treatment when disabled, so
    // the icon recedes alongside the rest of the field surface.
    final Color iconColor = enabled
        ? colors.foreground.withValues(alpha: colors.surfaceProminent + 0.4)
        : colors.foreground.withValues(alpha: colors.surfaceProminent);

    final Widget? prefix = prefixIcon == null
        ? null
        : Icon(prefixIcon, color: iconColor, size: typography.title.fontSize);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      maxLength: maxLength,
      maxLengthEnforcement: maxLength == null
          ? null
          : MaxLengthEnforcement.enforced,
      style: typography.bodyLarge.copyWith(color: colors.foreground),
      cursorColor: colors.emerald500,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefix,
        suffixIcon: suffix,
        // Hide the maxLength counter — the design has no counter slot
        // and the constraint is enforced silently by the formatter.
        counterText: '',
      ),
    );
  }
}

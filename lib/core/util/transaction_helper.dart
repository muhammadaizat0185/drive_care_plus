import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';
import '../../widgets/ui/ui.dart';
import '../theme/tokens/tokens.dart';

class TransactionHelper {
  const TransactionHelper._();

  /// Displays a double-confirmation modal prompting the user to approve/reject
  /// a money transfer. If approved, performs biometric checks and returns true
  /// if transaction is authorized, or false otherwise.
  static Future<bool> confirmAndAuthorizeTransaction({
    required BuildContext context,
    required double amount,
    required String description,
    required String recipient,
  }) async {
    // 1. Show transfer confirmation modal
    final bool? confirmed = await AppBottomSheet.show<bool>(
      context,
      initialHeightFraction: 0.45,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
        final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
        final AppColorsExt colors = theme.extension<AppColorsExt>()!;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Confirm Money Transfer',
              style: typography.headline.copyWith(color: colors.foreground),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.lg),
            AppCard(
              child: Column(
                children: [
                  Text(
                    'To: $recipient',
                    style: typography.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: colors.foreground),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    'RM ${amount.toStringAsFixed(2)}',
                    style: typography.headline.copyWith(
                      color: colors.emerald500,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    description,
                    style: typography.body.copyWith(
                      color: colors.foreground.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.xl),
            AppGradientButton(
              label: 'Approve Transfer',
              icon: Icons.check_circle_outline,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            SizedBox(height: spacing.md),
            AppSecondaryButton(
              label: 'Reject / Cancel',
              fullWidth: true,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }

    // 2. Perform Biometric Verification check
    final BiometricService biometricService = BiometricService.instance;
    final String reason = 'Authorize payment of RM ${amount.toStringAsFixed(2)} to $recipient.';

    if (biometricService.isTransactionAuthEnabled) {
      // Biometrics are enabled: Trigger native biometric authentication
      final bool authenticated = await biometricService.authenticateLocal(reason: reason);
      return authenticated;
    }

    // Check device support
    final bool isSupported = await biometricService.canAuthenticate();
    if (isSupported) {
      // Biometrics are supported but not enabled: Suggest enabling biometric transactions
      final bool? enableBiometric = await AppBottomSheet.show<bool>(
        context,
        initialHeightFraction: 0.42,
        builder: (BuildContext sheetContext) {
          final ThemeData theme = Theme.of(sheetContext);
          final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
          final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;
          final AppColorsExt colors = theme.extension<AppColorsExt>()!;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                Icons.fingerprint_rounded,
                size: 64,
                color: colors.emerald500,
              ),
              SizedBox(height: spacing.md),
              Text(
                'Enable Biometric Payments?',
                style: typography.headline.copyWith(color: colors.foreground),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.md),
              Text(
                'Protect future transactions with biometric authentication. You can toggle this setting anytime under Security settings.',
                style: typography.body.copyWith(
                  color: colors.foreground.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.lg),
              AppGradientButton(
                label: 'Enable & Authenticate',
                icon: Icons.fingerprint_rounded,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              SizedBox(height: spacing.md),
              AppSecondaryButton(
                label: 'Skip for Now',
                fullWidth: true,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          );
        },
      );

      if (enableBiometric == true) {
        // User clicked Enable: save configuration and run biometric auth
        await biometricService.setTransactionAuthEnabled(true);
        final bool authenticated = await biometricService.authenticateLocal(reason: reason);
        return authenticated;
      } else if (enableBiometric == false) {
        // User clicked Skip: proceed with standard authorization
        return true;
      } else {
        // Sheet dismissed/cancelled: cancel transaction
        return false;
      }
    }

    // Biometrics are not supported/enrolled on device: proceed with standard checkout
    return true;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/totp_service.dart';
import '../widgets/ui/ui.dart';
import '../core/theme/tokens/tokens.dart';
import '../core/theme/color_utils.dart';

class TOTPSetupScreen extends StatefulWidget {
  const TOTPSetupScreen({super.key});

  static const String routeName = '/settings/2fa-setup';

  @visibleForTesting
  static bool skipAuthCheck = false;

  @override
  State<TOTPSetupScreen> createState() => _TOTPSetupScreenState();
}

class _TOTPSetupScreenState extends State<TOTPSetupScreen> {
  late final String _secret;
  late final String _qrUri;
  final TextEditingController _codeController = TextEditingController();
  
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    String email = 'driver@drivecareplus.com';
    if (!TOTPSetupScreen.skipAuthCheck) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.email != null) {
          email = user.email!;
        }
      } catch (_) {}
    }
    _secret = TOTPService.instance.generateSecret();
    _qrUri = TOTPService.instance.getQrUri(email: email, secret: _secret);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndEnable() async {
    final String code = _codeController.text.trim();
    setState(() {
      _errorMessage = code.length != 6 ? 'Enter a 6-digit code' : null;
    });

    if (_errorMessage != null) return;

    setState(() => _isSaving = true);
    try {
      String uid = 'dummy_uid';
      if (!TOTPSetupScreen.skipAuthCheck) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User is not authenticated.');
        }
        uid = user.uid;
      }

      final bool isValid = TOTPService.instance.verifyCode(
        secret: _secret,
        code: code,
      );

      if (isValid) {
        await TOTPService.instance.enableTotp(uid, _secret);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Two-factor authentication enabled successfully! ✅'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid validation code. Please check your authenticator app.';
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString().replaceFirst('Exception: ', '')}';
        _isSaving = false;
      });
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _secret));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Secret key copied to clipboard! 📋'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Setup 2-Step Verification',
            style: typography.headline.copyWith(color: colors.foreground),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.lg,
          ),
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Step 1: Link your Authenticator App',
                    style: typography.title.copyWith(color: colors.foreground),
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    'Scan the QR code below in an authenticator app (such as Google Authenticator, Microsoft Authenticator, or Authy).',
                    style: typography.body.copyWith(
                      color: colors.foreground.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: spacing.xl),
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(spacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: _qrUri,
                        version: QrVersions.auto,
                        size: 200.0,
                        gapless: false,
                        errorStateBuilder: (cxt, err) {
                          return const Center(child: Text('Could not generate QR Code'));
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.xl),
                  Text(
                    'Can\'t scan the QR code?',
                    style: typography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: AppTextField(
                          controller: TextEditingController(text: _secret),
                          label: 'Secret Key',
                          enabled: false,
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: colors.muted.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: AppIconButton(
                          icon: Icons.copy_rounded,
                          semanticsLabel: 'Copy secret key',
                          onPressed: _copyToClipboard,
                          color: colors.emerald500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: spacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Step 2: Enter Verification Code',
                    style: typography.title.copyWith(color: colors.foreground),
                  ),
                  SizedBox(height: spacing.sm),
                  Text(
                    'Enter the 6-digit verification code from your authenticator app to complete the setup.',
                    style: typography.body.copyWith(
                      color: colors.foreground.withValues(alpha: 0.7),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  AppTextField(
                    controller: _codeController,
                    label: 'Verification Code',
                    hintText: '000000',
                    prefixIcon: Icons.lock_clock_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    errorText: _errorMessage,
                    enabled: !_isSaving,
                  ),
                  SizedBox(height: spacing.lg),
                  AppGradientButton(
                    label: 'Verify & Enable',
                    isLoading: _isSaving,
                    onPressed: _isSaving ? null : _verifyAndEnable,
                  ),
                  SizedBox(height: spacing.md),
                  AppSecondaryButton(
                    label: 'Cancel',
                    fullWidth: true,
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

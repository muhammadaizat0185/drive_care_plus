import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/totp_service.dart';
import '../widgets/ui/ui.dart';
import '../core/theme/tokens/tokens.dart';
import '../core/theme/color_utils.dart';

class TOTPVerificationScreen extends StatefulWidget {
  final String uid;

  const TOTPVerificationScreen({super.key, required this.uid});

  static const String routeName = '/login/2fa-verify';

  @override
  State<TOTPVerificationScreen> createState() => _TOTPVerificationScreenState();
}

class _TOTPVerificationScreenState extends State<TOTPVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final String code = _codeController.text.trim();
    setState(() {
      _errorMessage = code.length != 6 ? 'Enter a 6-digit code' : null;
    });

    if (_errorMessage != null) return;

    setState(() => _isSaving = true);
    try {
      final String? secret = await TOTPService.instance.getTotpSecret(widget.uid);
      if (secret == null || secret.isEmpty) {
        throw Exception('Two-factor authentication secret not found. Contact support.');
      }

      final bool isValid = TOTPService.instance.verifyCode(
        secret: secret,
        code: code,
      );

      if (isValid) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid verification code. Please try again.';
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  Future<void> _cancelVerification() async {
    setState(() => _isSaving = true);
    try {
      // Securely sign the user out of Firebase so their unverified session is closed
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Error signing out during cancel: $e');
    }
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingExt spacing = theme.extension<AppSpacingExt>()!;
    final AppColorsExt colors = theme.extension<AppColorsExt>()!;
    final AppTypographyExt typography = theme.extension<AppTypographyExt>()!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _cancelVerification();
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('2-Step Verification'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _isSaving ? null : _cancelVerification,
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: spacing.lg),
              child: AppCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(spacing.md),
                        decoration: BoxDecoration(
                          color: colors.emerald500.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.security_rounded,
                          size: 48,
                          color: colors.emerald500,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing.lg),
                    Text(
                      'Enter Verification Code',
                      style: typography.title.copyWith(color: colors.foreground),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.sm),
                    Text(
                      'This account is protected by 2-step verification. Enter the 6-digit code from your authenticator app.',
                      style: typography.body.copyWith(
                        color: colors.foreground.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing.xl),
                    AppTextField(
                      controller: _codeController,
                      label: '6-Digit Code',
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
                    SizedBox(height: spacing.xl),
                    AppGradientButton(
                      label: 'Verify Code',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _verify,
                    ),
                    SizedBox(height: spacing.md),
                    AppSecondaryButton(
                      label: 'Cancel',
                      fullWidth: true,
                      onPressed: _isSaving ? null : _cancelVerification,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

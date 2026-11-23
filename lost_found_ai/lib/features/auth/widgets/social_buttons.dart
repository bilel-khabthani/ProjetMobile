import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import 'google_logo.dart';

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({
    super.key,
    this.onGooglePressed,
    this.onPressed,
    this.loading = false,
  });

  final VoidCallback? onGooglePressed;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GoogleSignInButton(
      loading: loading,
      onPressed: onGooglePressed ?? onPressed,
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continuer avec Google',
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.colors.primary,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GoogleLogo(size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: context.typography.labelLarge?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
              ],
            ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(label, style: context.typography.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

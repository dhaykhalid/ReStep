import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../state/app_scope.dart';
import '../../widgets/widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final app = AppScope.read(context);
    try {
      await app.sendPasswordReset(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Reset password',
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        if (_sent) ...[
          const SizedBox(height: 24),
          Center(
            child: Container(
              height: 96,
              width: 96,
              decoration: const BoxDecoration(
                color: AppColors.successTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read_outlined,
                  size: 48, color: AppColors.success),
            ),
          ),
          const SizedBox(height: 24),
          Text('Check your email',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'If an account exists for ${_emailController.text.trim()}, we have '
            'sent a link to reset your password.',
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Back to Sign In',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ] else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Forgot your password?',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Enter the email you used for ReStep. We will send you a '
                  'link to reset your password.',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  label: 'Email',
                  hint: 'name@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  prefixIcon: Icons.mail_outline_rounded,
                  validator: Validators.email,
                  onFieldSubmitted: (_) => _sendLink(),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Send Reset Link',
                  loading: _loading,
                  onPressed: _sendLink,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

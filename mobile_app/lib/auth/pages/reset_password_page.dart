import 'package:flutter/material.dart';
import '../../core/widgets/design_system.dart';
import '../data/auth_api.dart';
import '../widgets/auth_input.dart';
import '../widgets/auth_layout.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.api,
    required this.challengeId,
    required this.resetToken,
  });
  final AuthApi api;
  final String challengeId, resetToken;

  // Creates the new-password form state.
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  String? error;

  // Submits the reset-only token and returns to login after revoking old sessions.
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.reset(
        widget.challengeId,
        widget.resetToken,
        password.text,
      );
      password.clear();
      confirmation.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(
            api: widget.api,
            message:
                'Password reset successfully. Log in with your new password.',
          ),
        ),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Clears password controllers after the reset page closes.
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  // Builds the password reset form using the existing theme controls.
  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Set a new password',
    step: '3 of 3',
    subtitle:
        'Choose a strong password to keep your TaskBridge account secure.',
    child: AutofillGroup(
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthError(error),
            AuthInput(
              label: 'New password',
              controller: password,
              enabled: !busy,
              password: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: AuthValidation.password,
            ),
            AuthInput(
              label: 'Confirm new password',
              controller: confirmation,
              enabled: !busy,
              password: true,
              validator: (v) =>
                  v != password.text ? 'Passwords do not match.' : null,
              onSubmitted: submit,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Use at least 8 characters, including a letter and a number.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ),
            AppButton(
              label: 'Reset password',
              loading: busy,
              onPressed: submit,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: busy
                  ? null
                  : () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoginPage(api: widget.api),
                      ),
                      (_) => false,
                    ),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    ),
  );
}

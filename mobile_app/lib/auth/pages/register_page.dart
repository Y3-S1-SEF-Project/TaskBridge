import 'package:flutter/material.dart';
import '../../core/widgets/design_system.dart';
import '../data/auth_api.dart';
import '../widgets/auth_input.dart';
import '../widgets/auth_layout.dart';
import 'otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.api});
  final AuthApi api;

  // Creates registration form state.
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false;
  String? error;

  // Starts registration and sends an email verification OTP before creating an account.
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final challenge = await widget.api.register(
        name.text,
        email.text,
        phone.text,
        password.text,
      );
      password.clear();
      confirmation.clear();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpPage(
            api: widget.api,
            challenge: challenge,
            fullName: name.text.trim(),
            phone: phone.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Clears form controllers when registration closes.
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  // Builds a single account registration form for both customer and provider modes.
  @override
  Widget build(BuildContext context) => AuthLayout(
    label: 'Create Your Account',
    title: 'Join TaskBridge',
    subtitle: 'Find help and offer your skills with one account.',
    child: AutofillGroup(
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthError(error),
            AuthInput(
              label: 'Full name',
              controller: name,
              enabled: !busy,
              maxLength: 100,
              keyboardType: TextInputType.name,
              autofillHints: const [AutofillHints.name],
              validator: AuthValidation.name,
            ),
            AuthInput(
              label: 'Email address',
              hint: 'you@example.com',
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidation.email,
            ),
            AuthInput(
              label: 'Mobile number',
              hint: '077 123 4567',
              controller: phone,
              enabled: !busy,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: AuthValidation.phone,
            ),
            AuthInput(
              label: 'Password',
              controller: password,
              enabled: !busy,
              password: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: AuthValidation.password,
            ),
            AuthInput(
              label: 'Confirm password',
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
              label: 'Create account',
              loading: busy,
              onPressed: submit,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                GestureDetector(
                  onTap: busy ? null : () => Navigator.pop(context),
                  child: Text(
                    'Log in',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

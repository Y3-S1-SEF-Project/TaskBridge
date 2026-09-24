import 'package:flutter/material.dart';
import '../../core/widgets/design_system.dart';
import '../../home/pages/home_page.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../widgets/auth_input.dart';
import '../widgets/auth_layout.dart';
import 'forgot_password_page.dart';
import 'otp_page.dart';
import 'profile_setup_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, this.message});
  final AuthApi api;
  final String? message;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final identifier = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final result = await widget.api.login(identifier.text, password.text);
      password.clear();
      if (!mounted) return;

      if (result.isNewUser) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileSetupPage(api: widget.api, user: result.user),
          ),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(user: result.user, api: widget.api),
          ),
          (_) => false,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        if (e.status == 403 && identifier.text.contains('@')) {
          // Unverified email; navigate to OTP page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpPage(
                api: widget.api,
                challenge: OtpChallenge(
                  email: identifier.text.trim(),
                  message: e.message,
                  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
                ),
              ),
            ),
          );
        } else {
          setState(() => error = e.toString());
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    label: 'Login',
    title: 'Welcome back',
    subtitle: 'Your next trusted service is one login away.',
    back: false,
    child: AutofillGroup(
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(widget.message!),
              ),
            AuthError(error),
            AuthInput(
              label: 'Email or mobile number',
              hint: 'you@example.com or 077 123 4567',
              controller: identifier,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.telephoneNumber,
              ],
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? 'Enter your email or mobile number.'
                  : null,
            ),
            AuthInput(
              label: 'Password',
              controller: password,
              enabled: !busy,
              password: true,
              autofillHints: const [AutofillHints.password],
              validator: (v) =>
                  (v?.isEmpty ?? true) ? 'Enter your password.' : null,
              onSubmitted: submit,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForgotPasswordPage(api: widget.api),
                        ),
                      ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(label: 'Login', loading: busy, onPressed: submit),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'New to TaskBridge? ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                GestureDetector(
                  onTap: busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterPage(api: widget.api),
                          ),
                        ),
                  child: Text(
                    'Create account',
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

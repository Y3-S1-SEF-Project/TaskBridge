import 'package:flutter/material.dart';
import '../../core/widgets/design_system.dart';
import '../data/auth_api.dart';
import '../widgets/auth_input.dart';
import '../widgets/auth_layout.dart';
import 'otp_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.api});
  final AuthApi api;

  // Creates password recovery form state.
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final form = GlobalKey<FormState>();
  final phone = TextEditingController();
  bool busy = false;
  String? error;

  // Requests a password-reset OTP for the entered mobile number.
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final challenge = await widget.api.forgot(phone.text);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpPage(api: widget.api, challenge: challenge),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Releases the mobile number controller.
  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  // Builds the recovery form without disclosing whether the account exists.
  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Forgot password?',
    step: '1 of 3',
    subtitle:
        'Enter your registered mobile number. We’ll help you get back into your account.',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthError(error),
          AuthInput(
            label: 'Mobile number',
            hint: '077 123 4567',
            controller: phone,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            validator: AuthValidation.phone,
            onSubmitted: submit,
          ),
          AppButton(
            label: 'Send verification code',
            loading: busy,
            onPressed: submit,
          ),
          const SizedBox(height: 16),
          const Text(
            'If this number has a TaskBridge account, you’ll receive an SMS code.',
          ),
        ],
      ),
    ),
  );
}

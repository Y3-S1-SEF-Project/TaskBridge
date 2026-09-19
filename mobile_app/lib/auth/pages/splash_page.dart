import 'package:flutter/material.dart';
import '../../core/services/user_mode_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/design_system.dart';
import '../data/auth_api.dart';
import 'authenticated_page.dart';
import 'onboarding_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.api});
  final AuthApi api;

  // Creates the session restoration state.
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String? error;
  bool busy = false;

  // Restores the saved session after the first frame is ready.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => restore());
  }

  // Validates the saved session and routes to onboarding or the signed-in handoff.
  Future<void> restore() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final user = await widget.api.restore();
      if (!mounted) return;
      if (user == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OnboardingPage(api: widget.api)),
        );
        return;
      }
      final mode = await UserModeService.getMode();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AuthenticatedPage(
            api: widget.api,
            user: user,
            initialMode: mode,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Displays the TaskBridge splash identity and recoverable connection errors.
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppPalette.of(context).soft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(AppIcons.briefcase, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'TaskBridge',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Connecting People to the Right Skills.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (error == null)
                const CircularProgressIndicator()
              else ...[
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                AppButton(label: 'Try again', onPressed: restore),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../home/pages/home_page.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import 'profile_setup_page.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({
    super.key,
    required this.api,
    required this.challenge,
    this.fullName,
    this.phone,
    this.title,
  });

  final AuthApi api;
  final OtpChallenge challenge;
  final String? fullName;
  final String? phone;
  final String? title;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final code = TextEditingController();
  final focusNode = FocusNode();
  late OtpChallenge challenge;
  Timer? timer;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    challenge = widget.challenge;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNode.requestFocus();
    });
  }

  Future<void> verify() async {
    if (busy || code.text.trim().length != 6) return;
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final result = await widget.api.verifyEmailOtp(
        challenge.email,
        code.text.trim(),
      );
      if (!mounted) return;

      if (result.isNewUser) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProfileSetupPage(api: widget.api, user: result.user),
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
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final updated = await widget.api.resendOtp(challenge.email);
      if (mounted) {
        setState(() {
          challenge = updated;
          code.clear();
        });
        focusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resendAt =
        challenge.resendAt ?? DateTime.now().add(const Duration(seconds: 60));
    final remaining = resendAt
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 60);

    final isEmail = challenge.email.contains('@');
    final titleText =
        widget.title ?? (isEmail ? 'Verify your email' : 'Verify your number');
    final changeText = isEmail
        ? 'Change email address'
        : 'Change mobile number';
    final targetDestination = challenge.email.isNotEmpty
        ? challenge.email
        : (widget.phone ?? '+94 77 ••• 4567');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s24,
                vertical: AppSpacing.s16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (AppSpacing.s16 * 2),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header Row ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ONE MORE STEP',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  titleText,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            splashRadius: 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Subtitle / Destination ──
                      const Text(
                        'Enter the 6-digit code sent to',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        targetDestination,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── 6-Box OTP Input Area ──
                      Stack(
                        children: [
                          // Visual 6 rounded boxes with typed digit or centered dash
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              final hasDigit = index < code.text.length;
                              final isCurrentFocus =
                                  index == code.text.length &&
                                  focusNode.hasFocus;

                              return Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(
                                    right: index < 5 ? 8 : 0,
                                  ),
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.r12,
                                    ),
                                    border: Border.all(
                                      color: isCurrentFocus
                                          ? AppColors.primary
                                          : hasDigit
                                          ? AppColors.primary.withValues(
                                              alpha: 0.5,
                                            )
                                          : AppColors.border,
                                      width: isCurrentFocus ? 2.0 : 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: hasDigit
                                        ? Text(
                                            code.text[index],
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          )
                                        : Container(
                                            width: 16,
                                            height: 2.2,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4A5568),
                                              borderRadius:
                                                  BorderRadius.circular(1),
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            }),
                          ),

                          // Invisible overlay text field capturing keyboard events
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0,
                              child: TextField(
                                controller: code,
                                focusNode: focusNode,
                                keyboardType: TextInputType.number,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                onChanged: (val) {
                                  setState(() {});
                                  if (val.length == 6) {
                                    verify();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Resend Code Countdown / Button ──
                      Center(
                        child: remaining > 0
                            ? Text(
                                'Resend code in 00:${remaining.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : GestureDetector(
                                onTap: busy ? null : resend,
                                child: const Text(
                                  'Resend code',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 18),

                      // ── Change Mobile / Email Button ──
                      InkWell(
                        onTap: busy ? null : () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.r12),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              changeText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Error Notice ──
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: AppSpacing.s8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.r8),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const Spacer(),
                      const SizedBox(height: 16),

                      // ── Bottom "Verify & Continue" Action Button ──
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.r16,
                              ),
                            ),
                            disabledBackgroundColor: AppColors.primary
                                .withValues(alpha: 0.5),
                          ),
                          onPressed: (busy || code.text.trim().length != 6)
                              ? null
                              : verify,
                          child: busy
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Verify & Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

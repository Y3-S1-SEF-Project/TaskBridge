import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_spacing.dart';

class AuthInput extends StatefulWidget {
  const AuthInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.password = false,
    this.enabled = true,
    this.keyboardType,
    this.validator,
    this.autofillHints,
    this.formatters,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.onSubmitted,
  });
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool password, enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? formatters;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final VoidCallback? onSubmitted;

  // Creates the field state for password visibility.
  @override
  State<AuthInput> createState() => _AuthInputState();
}

class _AuthInputState extends State<AuthInput> {
  bool hidden = true;

  // Renders a validated field with autofill and accessible password visibility controls.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s20),
    child: TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.password && hidden,
      autocorrect:
          !widget.password && widget.keyboardType == TextInputType.name,
      enableSuggestions: !widget.password,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.formatters,
      maxLength: widget.maxLength,
      validator: widget.validator,
      minLines: widget.minLines,
      maxLines: widget.password ? 1 : widget.maxLines,
      textInputAction: (widget.maxLines != null && widget.maxLines! > 1)
          ? TextInputAction.newline
          : (widget.onSubmitted == null
              ? TextInputAction.next
              : TextInputAction.done),
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        counterText: '',
        suffixIcon: widget.password
            ? IconButton(
                tooltip: hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              )
            : null,
      ),
    ),
  );
}

abstract final class AuthValidation {
  // Validates Sri Lankan local and international mobile number formats.
  static String? phone(String? value) {
    final phone = (value ?? '').replaceAll(RegExp(r'[\s()+-]'), '');
    return RegExp(r'^(07\d{8}|947\d{8})$').hasMatch(phone)
        ? null
        : 'Enter a valid mobile number, such as 0771234567.';
  }

  // Matches the server password length and character requirements.
  static String? password(String? value) {
    final text = value ?? '';
    return text.length >= 8 &&
            text.length <= 128 &&
            RegExp(r'[a-zA-Z]').hasMatch(text) &&
            RegExp(r'\d').hasMatch(text)
        ? null
        : '  Use at least 8 characters with a letter and a number.';
  }

  // Requires a readable full name within the server limit.
  static String? name(String? value) =>
      (value?.trim().length ?? 0) < 2 || (value?.trim().length ?? 0) > 100
      ? 'Enter your full name (2–100 characters).'
      : null;

  // Validates standard email addresses.
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email address.';
    return RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(text)
        ? null
        : 'Enter a valid email address.';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:test_auth/theme/app_theme.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppColors.text, fontSize: 16),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted),
        prefixIcon: Icon(icon, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class PrimaryAuthButton extends StatelessWidget {
  const PrimaryAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryStrong,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceAlt,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.leading,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Widget leading;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: borderColor ?? Colors.transparent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.onCompleted,
    this.enabled = true,
  });

  final ValueChanged<String> onCompleted;
  final bool enabled;

  @override
  State<OtpCodeField> createState() => OtpCodeFieldState();
}

class OtpCodeFieldState extends State<OtpCodeField> {
  static const _length = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _nodes = List.generate(_length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get code => _controllers.map((c) => c.text).join();

  void clear() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _nodes.first.requestFocus();
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      if (digits.length >= _length) {
        _nodes.last.unfocus();
        widget.onCompleted(digits.substring(0, _length));
      } else if (digits.isNotEmpty) {
        _nodes[digits.length.clamp(0, _length - 1)].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty && index < _length - 1) {
      _nodes[index + 1].requestFocus();
    }
    if (code.length == _length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == _length - 1 ? 0 : 8),
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace &&
                    _controllers[index].text.isEmpty &&
                    index > 0) {
                  _nodes[index - 1].requestFocus();
                  _controllers[index - 1].clear();
                }
              },
              child: TextField(
                controller: _controllers[index],
                focusNode: _nodes[index],
                enabled: widget.enabled,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.4,
                    ),
                  ),
                ),
                onChanged: (value) => _onChanged(index, value),
              ),
            ),
          ),
        );
      }),
    );
  }
}

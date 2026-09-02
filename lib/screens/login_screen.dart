import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_auth/bloc/auth/auth_cubit.dart';
import 'package:test_auth/bloc/auth/auth_state.dart';
import 'package:test_auth/screens/home_screen.dart';
import 'package:test_auth/screens/otp_screen.dart';
import 'package:test_auth/theme/app_theme.dart';
import 'package:test_auth/widgets/auth_controls.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  OtpChannel _channel = OtpChannel.email;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<AuthBloc>();
    if (_channel == OtpChannel.email) {
      final email = _emailController.text.trim();
      if (!_isValidEmail(email)) {
        _showMessage('Enter a valid email address.');
        return;
      }
      cubit.requestEmailOtp(email);
    } else {
      final phone = _normalizePhone(_phoneController.text);
      if (!_isValidPhone(phone)) {
        _showMessage('Enter a phone number with country code, e.g. +998...');
        return;
      }
      cubit.requestPhoneOtp(phone);
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _normalizePhone(String value) {
    var phone = value.replaceAll(RegExp(r'[\s-]'), '');
    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    } else if (!phone.startsWith('+') && phone.startsWith('998')) {
      phone = '+$phone';
    }
    return phone;
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^\+\d{7,15}$').hasMatch(value);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        return (current.error != null && current.error != previous.error) ||
            (current.user != null && current.user != previous.user) ||
            (current.otpSent && !previous.otpSent);
      },
      listener: (context, state) {
        if (state.error != null && state.error!.isNotEmpty) {
          _showMessage(state.error!);
          context.read<AuthBloc>().clearError();
        }
        if (state.user != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
          );
        } else if (state.otpSent) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OtpScreen()));
        }
      },
      builder: (context, state) {
        final loading = state.isLoading;
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF10182C), AppColors.background],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.lock_open_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in with Google, Facebook, email OTP, or a Telegram phone code.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _AuthMethodSwitch(
                      value: _channel,
                      onChanged: loading
                          ? null
                          : (value) => setState(() => _channel = value),
                    ),
                    const SizedBox(height: 18),
                    if (_channel == OtpChannel.email)
                      AuthTextField(
                        controller: _emailController,
                        hint: 'Email address',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      )
                    else
                      AuthTextField(
                        controller: _phoneController,
                        hint: '+998 90 123 45 67',
                        icon: Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      _channel == OtpChannel.email
                          ? 'We will send a 6-digit code to your email.'
                          : 'You will be redirected to Telegram to receive the OTP.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryAuthButton(
                      label: _channel == OtpChannel.email
                          ? 'Send email code'
                          : 'Continue with Telegram',
                      loading: loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 28),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or continue with',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SocialAuthButton(
                      label: 'Continue with Google',
                      onPressed: loading
                          ? null
                          : () => context.read<AuthBloc>().signInWithGoogle(),
                      background: Colors.white,
                      foreground: const Color(0xFF1F1F1F),
                      leading: const _GoogleMark(),
                    ),
                    const SizedBox(height: 12),
                    SocialAuthButton(
                      label: 'Continue with Facebook',
                      onPressed: loading
                          ? null
                          : () => context.read<AuthBloc>().signInWithFacebook(),
                      background: AppColors.facebook,
                      foreground: Colors.white,
                      leading: const Icon(
                        Icons.facebook_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuthMethodSwitch extends StatelessWidget {
  const _AuthMethodSwitch({required this.value, required this.onChanged});

  final OtpChannel value;
  final ValueChanged<OtpChannel>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _chip(
            label: 'Email OTP',
            selected: value == OtpChannel.email,
            onTap: onChanged == null
                ? null
                : () => onChanged!(OtpChannel.email),
          ),
          _chip(
            label: 'Phone + Telegram',
            selected: value == OtpChannel.phone,
            onTap: onChanged == null
                ? null
                : () => onChanged!(OtpChannel.phone),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceAlt : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.text : AppColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

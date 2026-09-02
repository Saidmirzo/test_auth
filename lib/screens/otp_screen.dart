import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_auth/bloc/auth/auth_cubit.dart';
import 'package:test_auth/bloc/auth/auth_state.dart';
import 'package:test_auth/screens/home_screen.dart';
import 'package:test_auth/theme/app_theme.dart';
import 'package:test_auth/widgets/auth_controls.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpKey = GlobalKey<OtpCodeFieldState>();

  void _verify(String code) {
    if (code.length != 6) return;
    final cubit = context.read<AuthBloc>();
    if (cubit.state.otpChannel == OtpChannel.phone) {
      cubit.verifyPhoneOtp(code);
    } else {
      cubit.verifyEmailOtp(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.error != null && state.error!.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
          context.read<AuthBloc>().clearError();
          _otpKey.currentState?.clear();
        }
        if (state.user != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
          );
        }
      },
      builder: (context, state) {
        final isPhone = state.otpChannel == OtpChannel.phone;
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) context.read<AuthBloc>().resetOtp();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  context.read<AuthBloc>().resetOtp();
                  Navigator.of(context).pop();
                },
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPhone ? 'Telegram code' : 'Email code',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPhone
                          ? 'Open Telegram from the same number, tap Start, share that contact, then paste the 6-digit code here.'
                          : 'Enter the 6-digit code sent to ${state.otpDestination ?? 'your email'}.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    OtpCodeField(
                      key: _otpKey,
                      enabled: !state.isLoading,
                      onCompleted: _verify,
                    ),
                    if (kDebugMode && state.debugOtpCode != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Debug code: ${state.debugOtpCode}',
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (isPhone)
                      SocialAuthButton(
                        label: 'Open Telegram bot',
                        onPressed: state.isLoading
                            ? null
                            : () => context
                                  .read<AuthBloc>()
                                  .reopenTelegramRedirect(),
                        background: const Color(0xFF229ED9),
                        foreground: Colors.white,
                        leading: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: state.isLoading
                          ? null
                          : () {
                              final destination = state.otpDestination;
                              if (destination == null) return;
                              if (isPhone) {
                                context.read<AuthBloc>().requestPhoneOtp(
                                  destination,
                                );
                              } else {
                                context.read<AuthBloc>().requestEmailOtp(
                                  destination,
                                );
                              }
                            },
                      child: const Text('Resend code'),
                    ),
                    const Spacer(),
                    PrimaryAuthButton(
                      label: 'Verify and continue',
                      loading: state.isLoading,
                      onPressed: () {
                        final code = _otpKey.currentState?.code ?? '';
                        if (code.length != 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter the 6-digit code.'),
                            ),
                          );
                          return;
                        }
                        _verify(code);
                      },
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

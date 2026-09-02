import 'package:test_auth/models/user_model.dart';

enum OtpChannel { email, phone }

class AuthState {
  final bool isLoading;
  final String? error;
  final UserModel? user;
  final bool otpSent;
  final OtpChannel? otpChannel;
  final String? otpDestination;
  final String? redirectUrl;
  final String? telegramUrl;
  final String? debugOtpCode;

  const AuthState({
    this.isLoading = false,
    this.error,
    this.user,
    this.otpSent = false,
    this.otpChannel,
    this.otpDestination,
    this.redirectUrl,
    this.telegramUrl,
    this.debugOtpCode,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    String? error,
    UserModel? user,
    bool clearUser = false,
    bool clearError = false,
    bool? otpSent,
    OtpChannel? otpChannel,
    String? otpDestination,
    String? redirectUrl,
    String? telegramUrl,
    String? debugOtpCode,
    bool clearOtp = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      user: clearUser ? null : (user ?? this.user),
      otpSent: clearOtp ? false : (otpSent ?? this.otpSent),
      otpChannel: clearOtp ? null : (otpChannel ?? this.otpChannel),
      otpDestination: clearOtp ? null : (otpDestination ?? this.otpDestination),
      redirectUrl: clearOtp ? null : (redirectUrl ?? this.redirectUrl),
      telegramUrl: clearOtp ? null : (telegramUrl ?? this.telegramUrl),
      debugOtpCode: clearOtp ? null : (debugOtpCode ?? this.debugOtpCode),
    );
  }
}

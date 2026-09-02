import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_auth/bloc/auth/auth_state.dart';
import 'package:test_auth/models/user_model.dart';
import 'package:test_auth/services/api_client.dart';
import 'package:test_auth/services/auth_service.dart';
import 'package:test_auth/services/locale_service.dart';

class AuthBloc extends Cubit<AuthState> {
  AuthBloc({LocaleService? localeService, AuthService? authService})
    : super(const AuthState(isLoading: true)) {
    _localeService = localeService ?? LocaleServiceImpl();
    _authService = authService ?? AuthServiceImpl(_localeService);
    ApiClient.instance.onSessionExpired = _onSessionExpired;
  }

  late final LocaleService _localeService;
  late final AuthService _authService;

  void _onSessionExpired() {
    _localeService.signOut();
    if (!isClosed) {
      emit(
        state.copyWith(
          isLoading: false,
          clearUser: true,
          clearOtp: true,
          error: 'Session expired. Please sign in again.',
        ),
      );
    }
  }

  Future<UserModel?> getCurrentUser() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final result = await _authService.restoreSession();
    emit(
      state.copyWith(isLoading: false, user: result, clearUser: result == null),
    );
    if (result != null) {
      await loadSessions();
    }
    return result;
  }

  Future<void> loadSessions() async {
    try {
      final sessions = await _authService.fetchSessions();
      emit(state.copyWith(sessions: sessions));
    } catch (_) {
      emit(state.copyWith(sessions: const []));
    }
  }

  Future<void> revokeSession(int sessionId) async {
    final error = await _authService.revokeSession(sessionId);
    if (error != null) {
      emit(state.copyWith(error: error));
      return;
    }
    await loadSessions();
  }

  Future<void> signOut() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    await _authService.signOut();
    emit(
      state.copyWith(
        isLoading: false,
        clearUser: true,
        clearOtp: true,
        sessions: const [],
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final error = await _authService.signInWithGoogle();
    if (error != null) {
      emit(state.copyWith(isLoading: false, error: error));
      return;
    }
    final user = await _localeService.getCurrentUser();
    emit(state.copyWith(isLoading: false, user: user, clearOtp: true));
    await loadSessions();
  }

  Future<void> signInWithFacebook() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final error = await _authService.signInWithFacebook();
    if (error != null) {
      emit(state.copyWith(isLoading: false, error: error));
      return;
    }
    final user = await _localeService.getCurrentUser();
    emit(state.copyWith(isLoading: false, user: user, clearOtp: true));
  }

  Future<void> requestEmailOtp(String email) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final result = await _authService.requestEmailOtp(email);
    if (!result.isSuccess) {
      emit(state.copyWith(isLoading: false, error: result.error));
      return;
    }
    emit(
      state.copyWith(
        isLoading: false,
        otpSent: true,
        otpChannel: OtpChannel.email,
        otpDestination: email.trim(),
        debugOtpCode: result.debugOtpCode,
      ),
    );
  }

  Future<void> verifyEmailOtp(String code) async {
    final email = state.otpDestination;
    if (email == null) {
      emit(state.copyWith(error: 'Request a new email code first.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    final error = await _authService.verifyEmailOtp(email, code);
    if (error != null) {
      emit(state.copyWith(isLoading: false, error: error));
      return;
    }
    final user = await _localeService.getCurrentUser();
    emit(state.copyWith(isLoading: false, user: user, clearOtp: true));
    await loadSessions();
  }

  Future<void> requestPhoneOtp(String phone) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final result = await _authService.requestPhoneOtp(phone);
    if (!result.isSuccess) {
      emit(state.copyWith(isLoading: false, error: result.error));
      return;
    }
    emit(
      state.copyWith(
        isLoading: false,
        otpSent: true,
        otpChannel: OtpChannel.phone,
        otpDestination: phone.trim(),
        redirectUrl: result.redirectUrl,
        telegramUrl: result.telegramUrl,
        debugOtpCode: result.debugOtpCode,
      ),
    );
    final redirect = result.redirectUrl ?? result.telegramUrl;
    if (redirect != null) {
      await _authService.openOtpRedirect(redirect);
    }
  }

  Future<void> verifyPhoneOtp(String code) async {
    final phone = state.otpDestination;
    if (phone == null) {
      emit(state.copyWith(error: 'Request a new phone code first.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    final error = await _authService.verifyPhoneOtp(phone, code);
    if (error != null) {
      emit(state.copyWith(isLoading: false, error: error));
      return;
    }
    final user = await _localeService.getCurrentUser();
    emit(state.copyWith(isLoading: false, user: user, clearOtp: true));
    await loadSessions();
  }

  Future<void> reopenTelegramRedirect() async {
    final url = state.redirectUrl ?? state.telegramUrl;
    if (url == null) return;
    await _authService.openOtpRedirect(url);
  }

  void resetOtp() {
    emit(state.copyWith(clearOtp: true, clearError: true));
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}

import 'dart:io';

class ApiConfig {
  static const _lanOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_lanOverride.isNotEmpty) return _lanOverride;
    if (Platform.isAndroid) {
      return 'http://192.168.0.164:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Android OAuth client (package + SHA-1).
  static const googleAndroidClientId =
      '223943653055-546urm38lb52do5kumv01v1h4n64pntr.apps.googleusercontent.com';

  /// iOS OAuth client (bundle id).
  static const googleIosClientId =
      '223943653055-3lddvp09rhs7ck1sq3f77tu2kq8n9njd.apps.googleusercontent.com';

  /// Web OAuth client — ID token `aud` for backend verification.
  static const googleWebClientId =
      '223943653055-4a1cdet49pq03r0vc8d7f483j88cl8c3.apps.googleusercontent.com';

  static String get googleClientId =>
      Platform.isIOS ? googleIosClientId : googleAndroidClientId;
}

abstract final class ApiPaths {
  static const emailRequestOtp = '/api/auth/email/request-otp/';
  static const emailVerifyOtp = '/api/auth/email/verify-otp/';
  static const phoneRequestOtp = '/api/auth/phone/request-otp/';
  static const phoneVerifyOtp = '/api/auth/phone/verify-otp/';
  static const google = '/api/auth/google/';
  static const tokenRefresh = '/api/auth/token/refresh/';
  static const me = '/api/auth/me/';
  static const logout = '/api/auth/logout/';
  static const sessions = '/api/auth/sessions/';

  static String revokeSession(int sessionId) =>
      '/api/auth/sessions/$sessionId/revoke/';

  static String telegramRedirect(String sessionId) =>
      '/auth/telegram-redirect/$sessionId/';
}

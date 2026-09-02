import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:test_auth/config/api_config.dart';
import 'package:test_auth/models/user_model.dart';
import 'package:test_auth/services/locale_service.dart';
import 'package:url_launcher/url_launcher.dart';

class OtpRequestResult {
  const OtpRequestResult({
    this.error,
    this.redirectUrl,
    this.telegramUrl,
    this.debugOtpCode,
  });

  final String? error;
  final String? redirectUrl;
  final String? telegramUrl;
  final String? debugOtpCode;

  bool get isSuccess => error == null;
}

abstract class AuthService {
  Future<UserModel?> getCurrentUser();
  Future<void> signOut();
  Future<String?> signInWithGoogle();
  Future<String?> signInWithFacebook();
  Future<OtpRequestResult> requestEmailOtp(String email);
  Future<String?> verifyEmailOtp(String email, String code);
  Future<OtpRequestResult> requestPhoneOtp(String phone);
  Future<String?> verifyPhoneOtp(String phone, String code);
  Future<void> openOtpRedirect(String url);
}

class AuthServiceImpl implements AuthService {
  AuthServiceImpl(this._localeService);

  final LocaleService _localeService;
  bool _googleReady = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: ApiConfig.googleServerClientId,
    );
    _googleReady = true;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  String _apiError(
    http.Response response, [
    String fallback = 'Request failed',
  ]) {
    final body = _decode(response);
    return (body['error'] as String?) ?? fallback;
  }

  @override
  Future<UserModel?> getCurrentUser() {
    return _localeService.getCurrentUser();
  }

  @override
  Future<String?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = result.user;
      await _localeService.saveUserData(
        user: UserModel(
          name: firebaseUser?.displayName ?? googleUser.displayName,
          email: firebaseUser?.email ?? googleUser.email,
          photoUrl: firebaseUser?.photoURL,
          provider: 'google',
        ),
      );
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Google sign-in was cancelled.';
      }
      return e.description ?? 'Google sign-in failed.';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Google sign-in failed.';
    } catch (e) {
      return 'Google sign-in failed.';
    }
  }

  @override
  Future<String?> signInWithFacebook() async {
    try {
      final faceBook = FacebookAuth.instance;
      await faceBook.logOut();
      final login = await faceBook.login();

      if (login.status == LoginStatus.cancelled) {
        return 'Facebook sign-in was cancelled.';
      }
      if (login.status != LoginStatus.success || login.accessToken == null) {
        return login.message ?? 'Facebook sign-in failed.';
      }
      final credential = FacebookAuthProvider.credential(
        login.accessToken!.tokenString,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final firebaseUser = result.user;
      final profile = await FacebookAuth.instance.getUserData();
      await _localeService.saveUserData(
        user: UserModel(
          name: firebaseUser?.displayName ?? profile['name'] as String?,
          email: firebaseUser?.email ?? profile['email'] as String?,
          photoUrl: firebaseUser?.photoURL,
          provider: 'facebook',
        ),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Facebook sign-in failed.';
    } catch (e) {
      return 'Facebook sign-in failed. Check Facebook app id configuration.';
    }
  }

  @override
  Future<OtpRequestResult> requestEmailOtp(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/email/request-otp/'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim()}),
          )
          .timeout(const Duration(seconds: 15));
      final body = _decode(response);
      if (response.statusCode >= 400) {
        return OtpRequestResult(
          error: _apiError(response, 'Could not send email code.'),
        );
      }
      return OtpRequestResult(debugOtpCode: body['debug_code'] as String?);
    } on SocketException {
      return const OtpRequestResult(
        error: 'Cannot reach auth server. Start Django on port 8000.',
      );
    } catch (_) {
      return const OtpRequestResult(error: 'Could not send email code.');
    }
  }

  @override
  Future<String?> verifyEmailOtp(String email, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/email/verify-otp/'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
          )
          .timeout(const Duration(seconds: 15));
      final body = _decode(response);
      if (response.statusCode >= 400) {
        return _apiError(response, 'Invalid email code.');
      }
      await _localeService.saveUserData(
        user: UserModel(
          name: (body['name'] as String?) ?? email.trim(),
          email: (body['email'] as String?) ?? email.trim(),
          provider: 'email',
        ),
      );
      return null;
    } on SocketException {
      return 'Cannot reach auth server. Start Django on port 8000.';
    } catch (_) {
      return 'Could not verify email code.';
    }
  }

  @override
  Future<OtpRequestResult> requestPhoneOtp(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/phone/request-otp/'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone.trim()}),
          )
          .timeout(const Duration(seconds: 15));
      final body = _decode(response);
      if (response.statusCode >= 400) {
        return OtpRequestResult(
          error: _apiError(response, 'Could not start phone verification.'),
        );
      }
      final sessionId = body['session_id'] as String?;
      final redirectPath = body['redirect_path'] as String?;
      final telegramUrl = body['telegram_url'] as String?;
      final redirectUrl = sessionId == null
          ? null
          : '${ApiConfig.baseUrl}${redirectPath ?? '/auth/telegram-redirect/$sessionId/'}';
      return OtpRequestResult(
        redirectUrl: redirectUrl,
        telegramUrl: telegramUrl,
        debugOtpCode: body['debug_code'] as String?,
      );
    } on SocketException {
      return const OtpRequestResult(
        error: 'Cannot reach auth server. Start Django on port 8000.',
      );
    } catch (_) {
      return const OtpRequestResult(
        error: 'Could not start phone verification.',
      );
    }
  }

  @override
  Future<String?> verifyPhoneOtp(String phone, String code) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/phone/verify-otp/'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone.trim(), 'code': code.trim()}),
          )
          .timeout(const Duration(seconds: 15));
      final body = _decode(response);
      if (response.statusCode >= 400) {
        return _apiError(response, 'Invalid phone code.');
      }
      await _localeService.saveUserData(
        user: UserModel(
          name: (body['name'] as String?) ?? phone.trim(),
          phone: (body['phone'] as String?) ?? phone.trim(),
          provider: 'phone',
        ),
      );
      return null;
    } on SocketException {
      return 'Cannot reach auth server. Start Django on port 8000.';
    } catch (_) {
      return 'Could not verify phone code.';
    }
  }

  @override
  Future<void> openOtpRedirect(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _localeService.signOut();
    await FirebaseAuth.instance.signOut();
  }
}

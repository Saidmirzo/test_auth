import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:test_auth/config/api_config.dart';
import 'package:test_auth/models/user_model.dart';
import 'package:test_auth/services/api_client.dart';
import 'package:test_auth/services/device_service.dart';
import 'package:test_auth/services/locale_service.dart';
import 'package:test_auth/services/token_storage.dart';
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
  Future<UserModel?> restoreSession();
  Future<UserModel?> getCurrentUser();
  Future<void> signOut();
  Future<String?> signInWithGoogle();
  Future<String?> signInWithFacebook();
  Future<OtpRequestResult> requestEmailOtp(String email);
  Future<String?> verifyEmailOtp(String email, String code);
  Future<OtpRequestResult> requestPhoneOtp(String phone);
  Future<String?> verifyPhoneOtp(String phone, String code);
  Future<void> openOtpRedirect(String url);
  Future<List<AuthSessionModel>> fetchSessions();
  Future<String?> revokeSession(int sessionId);
}

class AuthServiceImpl implements AuthService {
  AuthServiceImpl(this._localeService, {DeviceService? deviceService})
    : _deviceService = deviceService ?? DeviceService();

  final LocaleService _localeService;
  final DeviceService _deviceService;
  final ApiClient _api = ApiClient.instance;
  bool _googleReady = false;

  TokenStorage get _tokens => _api.tokens;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      clientId: ApiConfig.googleClientId,
      serverClientId: ApiConfig.googleWebClientId,
    );
    _googleReady = true;
  }

  String _apiError(Object error, [String fallback = 'Request failed']) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is String) {
        return data['error'] as String;
      }
      if (error.type == DioExceptionType.connectionError ||
          error.error is SocketException) {
        return 'Cannot reach auth server. Start Django on port 8000.';
      }
    }
    return fallback;
  }

  Future<Map<String, dynamic>> _withDevice(Map<String, dynamic> body) async {
    return {...body, 'device': await _deviceService.payload()};
  }

  Future<String?> _persistAuth(Map data) async {
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    final userJson = data['user'];
    if (access == null || refresh == null || userJson is! Map) {
      return 'Auth response is missing tokens.';
    }
    await _tokens.saveTokens(access: access, refresh: refresh);
    final user = UserModel.fromJson(Map<String, dynamic>.from(userJson));
    await _localeService.saveUserData(user: user);
    return null;
  }

  @override
  Future<UserModel?> getCurrentUser() {
    return _localeService.getCurrentUser();
  }

  @override
  Future<UserModel?> restoreSession() async {
    final hasRefresh = await _tokens.hasRefresh();
    if (!hasRefresh) {
      await _localeService.signOut();
      return null;
    }
    try {
      final response = await _api.get(ApiPaths.me);
      final data = response.data;
      if (data is Map && data['user'] is Map) {
        final user = UserModel.fromJson(
          Map<String, dynamic>.from(data['user'] as Map),
        );
        await _localeService.saveUserData(user: user);
        return user;
      }
    } catch (_) {}
    await _tokens.clear();
    await _localeService.signOut();
    return null;
  }

  @override
  Future<String?> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return 'Google did not return an ID token.';
      }
      final response = await _api.post(
        ApiPaths.google,
        data: await _withDevice({'id_token': idToken}),
        skipAuthRefresh: true,
      );
      final data = response.data;
      if (data is! Map) return 'Google sign-in failed.';
      return _persistAuth(Map<String, dynamic>.from(data));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Google sign-in was cancelled.';
      }
      return e.description ?? 'Google sign-in failed.';
    } on DioException catch (e) {
      return _apiError(e, 'Google sign-in failed.');
    } catch (_) {
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
    } catch (_) {
      return 'Facebook sign-in failed. Check Facebook app id configuration.';
    }
  }

  @override
  Future<OtpRequestResult> requestEmailOtp(String email) async {
    try {
      await _api.post(
        ApiPaths.emailRequestOtp,
        data: {'email': email.trim()},
        skipAuthRefresh: true,
      );
      return const OtpRequestResult();
    } on DioException catch (e) {
      return OtpRequestResult(error: _apiError(e, 'Could not send email code.'));
    } catch (_) {
      return const OtpRequestResult(error: 'Could not send email code.');
    }
  }

  @override
  Future<String?> verifyEmailOtp(String email, String code) async {
    try {
      final response = await _api.post(
        ApiPaths.emailVerifyOtp,
        data: await _withDevice({'email': email.trim(), 'code': code.trim()}),
        skipAuthRefresh: true,
      );
      final data = response.data;
      if (data is! Map) return 'Could not verify email code.';
      return _persistAuth(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      return _apiError(e, 'Invalid email code.');
    } catch (_) {
      return 'Could not verify email code.';
    }
  }

  @override
  Future<OtpRequestResult> requestPhoneOtp(String phone) async {
    try {
      final response = await _api.post(
        ApiPaths.phoneRequestOtp,
        data: {'phone': phone.trim()},
        skipAuthRefresh: true,
      );
      final body = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final sessionId = body['session_id'] as String?;
      final redirectPath = body['redirect_path'] as String?;
      final telegramUrl = body['telegram_url'] as String?;
      final redirectUrl = sessionId == null
          ? null
          : '${ApiConfig.baseUrl}${redirectPath ?? ApiPaths.telegramRedirect(sessionId)}';
      return OtpRequestResult(
        redirectUrl: redirectUrl,
        telegramUrl: telegramUrl,
        debugOtpCode: body['debug_code'] as String?,
      );
    } on DioException catch (e) {
      return OtpRequestResult(
        error: _apiError(e, 'Could not start phone verification.'),
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
      final response = await _api.post(
        ApiPaths.phoneVerifyOtp,
        data: await _withDevice({'phone': phone.trim(), 'code': code.trim()}),
        skipAuthRefresh: true,
      );
      final data = response.data;
      if (data is! Map) return 'Could not verify phone code.';
      return _persistAuth(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      return _apiError(e, 'Invalid phone code.');
    } catch (_) {
      return 'Could not verify phone code.';
    }
  }

  @override
  Future<List<AuthSessionModel>> fetchSessions() async {
    final response = await _api.get(ApiPaths.sessions);
    final data = response.data;
    if (data is! Map || data['sessions'] is! List) return [];
    return (data['sessions'] as List)
        .whereType<Map>()
        .map(
          (item) => AuthSessionModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Future<String?> revokeSession(int sessionId) async {
    try {
      await _api.post(ApiPaths.revokeSession(sessionId));
      return null;
    } on DioException catch (e) {
      return _apiError(e, 'Could not revoke session.');
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
      final refresh = await _tokens.readRefresh();
      await _api.post(ApiPaths.logout, data: {'refresh': refresh});
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _tokens.clear();
    await _localeService.signOut();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}

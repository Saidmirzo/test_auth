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

  static const googleServerClientId =
      '223943653055-4a1cdet49pq03r0vc8d7f483j88cl8c3.apps.googleusercontent.com';
}

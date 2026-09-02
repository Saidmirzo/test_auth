import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_auth/models/user_model.dart';

abstract class LocaleService {
  Future<UserModel?> getCurrentUser();
  Future<void> signOut();
  Future<void> saveUserData({required UserModel user});
}

class LocaleServiceImpl implements LocaleService {
  static const _userKey = 'current_user';

  @override
  Future<void> saveUserData({required UserModel user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

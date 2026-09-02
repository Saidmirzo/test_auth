import 'package:hive_flutter/hive_flutter.dart';
import 'package:test_auth/models/user_model.dart';

abstract class LocaleService {
  Future<UserModel?> getCurrentUser();
  Future<void> signOut();
  Future<void> saveUserData({required UserModel user});
}

class LocaleServiceImpl implements LocaleService {
  static const boxName = 'app_data';
  static const _userKey = 'current_user';

  Box get _box => Hive.box(boxName);

  @override
  Future<void> saveUserData({required UserModel user}) async {
    await _box.put(_userKey, user.toJson());
  }

  @override
  Future<void> signOut() async {
    await _box.delete(_userKey);
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final raw = _box.get(_userKey);
    if (raw is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}

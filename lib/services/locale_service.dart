import 'package:test_auth/models/user_model.dart';

abstract class LocaleService {
  Future<UserModel> getCurrentUser();
  Future<void> signOut();
  Future<void> saveUserData({required UserModel user});
  // Future<void> signInWithEmailAndPassword(String email, String password);
}

class LocaleServiceImpl implements LocaleService {
  @override
  Future<void> saveUserData({required UserModel user}) {
    // TODO: implement saveUserData
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    // TODO: implement signOut
    throw UnimplementedError();
  }

  @override
  Future<UserModel> getCurrentUser() {
    // TODO: implement getCurrentUser
    throw UnimplementedError();
  }
}

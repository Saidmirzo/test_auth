import 'package:test_auth/user_model.dart';

abstract class AuthService {
  Future<UserModel> getCurrentUser();
  Future<void> signOut();
  Future<void> signInWithGoogle(UserModel user);
  Future<void> signInWithFacebook(UserModel user);
  Future<void> signInWithPhoneNumber(UserModel user);
  Future<void> signInWithEmailAndPassword(String email, String password);
}

class AuthServiceImpl implements AuthService {
  @override
  Future<UserModel> getCurrentUser() {
    // TODO: implement getCurrentUser
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) {
    // TODO: implement signInWithEmailAndPassword
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithFacebook(UserModel user) {
    // TODO: implement signInWithFacebook
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithGoogle(UserModel user) {
    // TODO: implement signInWithGoogle
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithPhoneNumber(UserModel user) {
    // TODO: implement signInWithPhoneNumber
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    // TODO: implement signOut
    throw UnimplementedError();
  }
}

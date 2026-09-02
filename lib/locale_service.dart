import 'package:test_auth/user_model.dart';

abstract class LocaleService {

  Future<UserModel> getCurrentUser();
  Future<void> signOut();
  Future<void> signInWithGoogle(UserModel user);
  Future<void> signInWithEmailAndPassword(String email, String password);

}
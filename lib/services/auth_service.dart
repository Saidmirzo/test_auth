import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:test_auth/models/user_model.dart';
import 'package:test_auth/services/locale_service.dart';

abstract class AuthService {
  Future<UserModel> getCurrentUser();
  Future<void> signOut();
  Future<void> signInWithGoogle(UserModel user);
  Future<void> signInWithFacebook(UserModel user);
  Future<void> signInWithPhoneNumber(UserModel user);
  Future<String?> signInWithEmailAndPassword(String email, String password);
  Future<String?> signUpWithEmailAndPassword(String email, String password);
}

class AuthServiceImpl implements AuthService {
  AuthServiceImpl(this._localeService);
  final LocaleService _localeService;
  @override
  Future<UserModel> getCurrentUser() {
    // TODO: implement getCurrentUser
    throw UnimplementedError();
  }

  @override
  Future<String?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      _localeService.saveUserData(
        user: UserModel(
          name: credential.user?.displayName ?? email,
          email: credential.user?.email,
          phone: credential.user?.phoneNumber,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
        return 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
        return 'The account already exists for that email.';
      }
    } catch (e) {
      print(e);
      return 'An error occurred while signing in.';
    }
    return null;
  }

  @override
  Future<void> signInWithFacebook(UserModel user) {
    // TODO: implement signInWithFacebook
    throw UnimplementedError();
  }

  @override
  Future<void> signInWithGoogle(UserModel user) async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
        .authenticate();

    final GoogleSignInAuthentication? googleAuth = googleUser?.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth?.idToken,
    );

    await FirebaseAuth.instance.signInWithCredential(credential);
    _localeService.saveUserData(
      user: UserModel(
        name: googleUser?.displayName ?? '',
        email: googleUser?.email,
      ),
    );
  }

  @override
  Future<void> signInWithPhoneNumber(UserModel user) {
    // TODO: implement signInWithPhoneNumber
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    await _localeService.signOut();
    return FirebaseAuth.instance.signOut();
  }

  @override
  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
        return 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
        return 'Wrong password provided for that user.';
      }
    }
    return null;
  }
}

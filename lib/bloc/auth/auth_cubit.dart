import 'dart:core';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_auth/bloc/auth/auth_state.dart';
import 'package:test_auth/models/user_model.dart';
import 'package:test_auth/services/auth_service.dart';
import 'package:test_auth/services/locale_service.dart';

class AuthBloc extends Cubit<AuthState> {
  AuthBloc() : super(AuthState(isLoading: true));

  final LocaleService _localeService = LocaleServiceImpl();
  final AuthService _authService = AuthServiceImpl(LocaleServiceImpl());

  Future<UserModel?> getCurrentUser() async {
    emit(state.copyWith(isLoading: true));
    final result = await _localeService.getCurrentUser();
    emit(state.copyWith(isLoading: false, user: result));
    return result;
  }

  Future<void> signOut() async {
    emit(state.copyWith(isLoading: true));
    await _authService.signOut();
    emit(state.copyWith(isLoading: false, user: null));
  }

  Future<void> signInWithGoogle(UserModel user) async {
    emit(state.copyWith(isLoading: true));
    await _authService.signInWithGoogle(user);
    emit(state.copyWith(isLoading: false, user: user));
  }

  Future<void> signInWithFacebook(UserModel user) async {
    emit(state.copyWith(isLoading: true));
    await _authService.signInWithFacebook(user);
    emit(state.copyWith(isLoading: false, user: user));
  }

  Future<void> signInWithPhoneNumber(UserModel user) async {
    emit(state.copyWith(isLoading: true));
    await _authService.signInWithPhoneNumber(user);
    emit(state.copyWith(isLoading: false, user: user));
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    emit(state.copyWith(isLoading: true));
    final error = await _authService.signInWithEmailAndPassword(
      email,
      password,
    );
    if (error != null) {
      emit(state.copyWith(isLoading: false, error: error));
    } else {
      final user = await _localeService.getCurrentUser();
      emit(state.copyWith(isLoading: false, user: user));
    }
  }
}

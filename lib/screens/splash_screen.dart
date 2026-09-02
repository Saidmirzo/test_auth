import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_auth/bloc/auth/auth_cubit.dart';
import 'package:test_auth/bloc/auth/auth_state.dart';
import 'package:test_auth/screens/home_screen.dart';
import 'package:test_auth/screens/login_screen.dart';
import 'package:test_auth/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().getCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.isLoading) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  state.user == null ? const LoginScreen() : const HomeScreen(),
            ),
          );
        },
        builder: (context, state) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Checking session…',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_auth/bloc/auth/auth_cubit.dart';
import 'package:test_auth/firebase_options.dart';
import 'package:test_auth/screens/splash_screen.dart';
import 'package:test_auth/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
      child: MaterialApp(
        title: 'Flutter Auth Demo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const SplashScreen(),
      ),
    );
  }
}

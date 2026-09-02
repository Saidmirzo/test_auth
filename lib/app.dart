import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:test_auth/bloc/auth/auth_cubit.dart';
import 'package:test_auth/config/app_env.dart';
import 'package:test_auth/firebase_options.dart';
import 'package:test_auth/screens/splash_screen.dart';
import 'package:test_auth/services/alice_inspector.dart';
import 'package:test_auth/services/locale_service.dart';
import 'package:test_auth/theme/app_theme.dart';
import 'package:test_auth/widgets/alice_tap_scope.dart';

Future<void> bootstrap(AppEnv env) async {
  AppFlavor.bootstrap(env);
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(LocaleServiceImpl.boxName);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AliceInspector.init();
  runApp(AliceInspector.wrap(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(),
      child: MaterialApp(
        title: 'Flutter Auth Demo',
        debugShowCheckedModeBanner: AppFlavor.current.isDev,
        theme: AppTheme.dark(),
        navigatorKey: AliceInspector.navigatorKey,
        builder: (context, child) {
          return AliceTapScope(child: child ?? const SizedBox.shrink());
        },
        home: const SplashScreen(),
      ),
    );
  }
}

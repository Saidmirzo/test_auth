import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_alice/alice.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:test_auth/config/app_env.dart';

class AliceInspector {
  AliceInspector._();

  static Alice? _alice;

  static bool get isEnabled => AppFlavor.current.enableAlice;

  static GlobalKey<NavigatorState>? get navigatorKey =>
      _alice?.getNavigatorKey();

  static void init() {
    if (!isEnabled) return;
    _alice ??= Alice(
      showNotification: true,
      showInspectorOnShake: true,
      darkTheme: true,
    );
  }

  static Interceptor? dioInterceptor() {
    final alice = _alice;
    if (alice == null) return null;
    return alice.getDioInterceptor();
  }

  static Widget wrap(Widget app) {
    if (!isEnabled) return app;
    return OverlaySupport.global(child: app);
  }

  static void show() => _alice?.showInspector();
}

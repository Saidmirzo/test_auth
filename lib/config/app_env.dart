enum AppEnv {
  dev,
  prod;

  bool get isDev => this == AppEnv.dev;
  bool get isProd => this == AppEnv.prod;
  bool get enableAlice => isDev;
}

class AppFlavor {
  static AppEnv current = AppEnv.prod;

  static void bootstrap(AppEnv env) {
    current = env;
  }
}

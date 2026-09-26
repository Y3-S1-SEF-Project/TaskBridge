import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth/data/auth_api.dart';
import 'auth/pages/splash_page.dart';
import 'core/config/api_config.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';

// Starts TaskBridge with initialized services and authentication entry flow.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();
  await ThemeService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // Creates the application-owned API client.
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final api = AuthApi();

  // Releases the API client when the application closes.
  @override
  void dispose() {
    api.dispose();
    super.dispose();
  }

  // Applies the shared TaskBridge theme and status bar style.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        final platformBrightness =
            MediaQuery.maybePlatformBrightnessOf(context) ??
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final isDark = themeMode == ThemeMode.dark ||
            (themeMode == ThemeMode.system &&
                platformBrightness == Brightness.dark);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemOverlayStyle(
            isDark ? Brightness.dark : Brightness.light,
          ),
          child: MaterialApp(
            title: 'TaskBridge',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: SplashPage(api: api),
          ),
        );
      },
    );
  }
}

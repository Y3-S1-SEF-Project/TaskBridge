import 'package:flutter/material.dart';
import 'auth/data/auth_api.dart';
import 'auth/pages/splash_page.dart';
import 'core/theme/app_theme.dart';

// Starts TaskBridge with the authentication entry flow.
void main() => runApp(const MyApp());

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

  // Applies the shared TaskBridge theme to the authentication flow.
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TaskBridge',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    home: SplashPage(api: api),
  );
}

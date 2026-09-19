import 'package:flutter/material.dart';
import '../../core/services/user_mode_service.dart';
import '../../core/theme/app_palette.dart';
import '../../home/pages/home_page.dart';
import '../../provider/pages/provider_main_page.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

class AuthenticatedPage extends StatelessWidget {
  const AuthenticatedPage({
    super.key,
    required this.api,
    required this.user,
    this.initialMode,
  });

  final AuthApi api;
  final AuthUser user;
  final UserMode? initialMode;

  @override
  Widget build(BuildContext context) {
    if (initialMode != null) {
      if (initialMode == UserMode.provider && user.isProvider) {
        return ProviderMainPage(user: user, api: api);
      }
      return HomePage(user: user, api: api);
    }

    final p = AppPalette.of(context);
    return FutureBuilder<UserMode>(
      future: UserModeService.getMode(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: p.background,
            body: Center(child: CircularProgressIndicator(color: p.primary)),
          );
        }
        if (snapshot.data == UserMode.provider && user.isProvider) {
          return ProviderMainPage(user: user, api: api);
        }
        return HomePage(user: user, api: api);
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../home/pages/home_page.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';

class AuthenticatedPage extends StatelessWidget {
  const AuthenticatedPage({super.key, required this.api, required this.user});
  final AuthApi api;
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return HomePage(user: user, api: api);
  }
}


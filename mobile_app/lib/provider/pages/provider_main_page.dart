import 'package:flutter/material.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../widgets/provider_bottom_nav.dart';
import 'provider_chat_page.dart';
import 'provider_dashboard_page.dart';
import 'provider_jobs_page.dart';
import 'provider_profile_page.dart';

class ProviderMainPage extends StatefulWidget {
  final AuthUser user;
  final AuthApi api;

  const ProviderMainPage({
    super.key,
    required this.user,
    required this.api,
  });

  @override
  State<ProviderMainPage> createState() => _ProviderMainPageState();
}

class _ProviderMainPageState extends State<ProviderMainPage> {
  int _currentIndex = 3; // Defaults to Provider Profile as shown in Image 2!
  late AuthUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  void _switchToCustomer() {
    Navigator.pop(context, _currentUser);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProviderDashboardPage(
        user: _currentUser,
        onSwitchToCustomer: _switchToCustomer,
      ),
      const ProviderJobsPage(),
      const ProviderChatPage(),
      ProviderProfilePage(
        user: _currentUser,
        api: widget.api,
        onSwitchToCustomer: _switchToCustomer,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: ProviderBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

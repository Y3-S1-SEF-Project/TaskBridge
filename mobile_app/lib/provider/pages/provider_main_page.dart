import 'package:flutter/material.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/services/user_mode_service.dart';
import '../../chat/services/chat_service.dart';
import '../../home/pages/home_page.dart';
import '../../notifications/services/notification_service.dart';
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
    UserModeService.setMode(UserMode.provider);
    NotificationService.verificationStatusChangeNotifier.addListener(_onVerificationChanged);
  }

  @override
  void dispose() {
    NotificationService.verificationStatusChangeNotifier.removeListener(_onVerificationChanged);
    super.dispose();
  }

  void _onVerificationChanged() async {
    final status = NotificationService.verificationStatusChangeNotifier.value;
    if (status != null && mounted) {
      setState(() {
        _currentUser = _currentUser.copyWith(
          isVerified: status,
          verificationStatus: status ? 'Approved' : 'Rejected',
        );
      });
      final fresh = await widget.api.restore();
      if (fresh != null && mounted) {
        setState(() {
          _currentUser = fresh;
        });
      }
    }
  }

  void _switchToCustomer() async {
    await UserModeService.setMode(UserMode.customer);
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context, _currentUser);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(user: _currentUser, api: widget.api),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProviderDashboardPage(
        user: _currentUser,
        onSwitchToCustomer: _switchToCustomer,
      ),
      ProviderJobsPage(user: _currentUser),
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
        onTap: (index) {
          if (index == 2) {
            ChatService().triggerConversationsRefresh();
          }
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}

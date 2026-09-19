import 'package:flutter/material.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/services/location_service.dart';
import '../../core/services/user_mode_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../models/service_category.dart';
import '../widgets/category_card.dart';
import '../widgets/taskbridge_bottom_nav.dart';
import '../widgets/taskbridge_search_bar.dart';
import 'all_categories_page.dart';
import 'customer_bookings_page.dart';
import 'customer_chat_page.dart';
import 'location_picker_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final AuthUser? user;
  final AuthApi? api;

  const HomePage({super.key, this.user, this.api});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentNavIndex = 0;
  UserLocation _userLocation = UserLocation.defaultLocation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    UserModeService.setMode(UserMode.customer);
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    // 1. Load saved/cached location
    final cached = await LocationService.getSavedLocation();
    if (cached != null && mounted) {
      setState(() => _userLocation = cached);
    }

    // 2. Fetch live GPS position on startup
    if (mounted) setState(() => _isLoadingLocation = true);
    try {
      final live = await LocationService.determineCurrentPosition();
      if (live != null && mounted) {
        setState(() {
          _userLocation = live;
          _isLoadingLocation = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _changeLocation() async {
    final selected = await Navigator.push<UserLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(initialLocation: _userLocation),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _userLocation = selected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location updated to ${selected.shortName}'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String get _userName {
    final name = widget.user?.fullName.trim();
    if (name != null && name.isNotEmpty) {
      return name.split(' ').first;
    }
    return 'Kavindu';
  }

  void _openAllCategories() async {
    final targetIndex = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const AllCategoriesPage()),
    );
    if (targetIndex != null && mounted) {
      setState(() => _currentNavIndex = targetIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topCategories = ServiceCategory.allCategories.take(3).toList();

    final pages = [
      _buildHomeContent(topCategories),
      CustomerBookingsPage(
        onSwitchTab: (index) => setState(() => _currentNavIndex = index),
      ),
      const CustomerChatPage(),
      ProfilePage(
        user: widget.user,
        api: widget.api,
        showBottomNav: false,
        onBackToHome: () => setState(() => _currentNavIndex = 0),
        onTabChange: (index) => setState(() => _currentNavIndex = index),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentNavIndex,
        children: pages,
      ),
      bottomNavigationBar: TaskBridgeBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
        },
      ),
    );
  }

  Widget _buildHomeContent(List<ServiceCategory> topCategories) {
    return SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Tag ──
              const Text(
                'YOUR HOME, IN GOOD HANDS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

              // ── Title Row with Notification Bell ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Good morning,\n$_userName',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      AppIcons.notification,
                      color: AppColors.textPrimary,
                      size: 26,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // ── Location Center Row ──
              InkWell(
                onTap: _changeLocation,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        AppIcons.location,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _isLoadingLocation
                              ? 'Locating you… · '
                              : '${_userLocation.shortName} · ',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isLoadingLocation)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: SizedBox.square(
                            dimension: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _changeLocation,
                        child: const Text(
                          'Change',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),

              // ── Search Bar ──
              TaskBridgeSearchBar(
                hintText: 'Search services or providers',
                onTap: _openAllCategories,
                readOnly: true,
              ),
              const SizedBox(height: AppSpacing.s20),

              // ── AI Recommendation Card ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Don\u2019t know who to hire?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Describe your problem and TaskBridge AI will help you find a suitable provider.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('AI Recommendation opening soon'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Text(
                          'Get AI Recommendation',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // ── Browse Services Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Browse services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openAllCategories,
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // ── Top 3 Services Row ──
              Row(
                children: topCategories.map((cat) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: CategoryCard(
                        category: cat,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${cat.name} selected'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.s24),

              // ── Available Near You Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available near you',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // ── Sample Provider Card ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        AppIcons.plumbing,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sampath Perera',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Master Plumber · 4.9 ★ (84 reviews)',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'From Rs. 2,500/hr',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
          ),
        ),
      );
  }
}

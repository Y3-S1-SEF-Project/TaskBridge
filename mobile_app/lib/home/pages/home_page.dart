import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/services/location_service.dart';
import '../../core/services/user_mode_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
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
import 'provider_search_page.dart';
import '../data/provider_api.dart';
import '../models/provider_item.dart';
import '../widgets/provider_card.dart';
import '../../ai/widgets/ai_prompt_sheet.dart';
import '../../ai/services/bookings_sync_service.dart';
import '../../chat/services/chat_service.dart';

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
  List<ProviderItem> _nearbyProviders = [];
  bool _isLoadingProviders = true;

  @override
  void initState() {
    super.initState();
    UserModeService.setMode(UserMode.customer);
    _initializeLocation();
    _loadNearbyProviders();
  }

  Future<void> _loadNearbyProviders() async {
    if (!mounted) return;
    setState(() => _isLoadingProviders = true);
    try {
      final list = await ProviderApi.getProviders(
        location: _userLocation.shortName,
        lat: _userLocation.latitude,
        lng: _userLocation.longitude,
        sortBy: 'distance',
        excludeUserId: widget.user?.id,
        excludeName: widget.user?.fullName,
        limit: 5,
      );
      if (mounted) {
        final currentUserId = widget.user?.id.toLowerCase();
        final currentUserName = widget.user?.fullName.trim().toLowerCase();

        final filteredList = list.where((p) {
          if (currentUserId != null &&
              p.userId.toLowerCase() == currentUserId) {
            return false;
          }
          if (currentUserName != null &&
              p.fullName.trim().toLowerCase() == currentUserName) {
            return false;
          }
          return true;
        }).toList();

        final realList = filteredList.map((p) {
          if (p.latitude != null &&
              p.longitude != null &&
              p.latitude != 0 &&
              p.longitude != 0) {
            final meters = Geolocator.distanceBetween(
              _userLocation.latitude,
              _userLocation.longitude,
              p.latitude!,
              p.longitude!,
            );
            final km = meters / 1000.0;
            final rounded = km < 0.5
                ? 0.5
                : double.parse(km.toStringAsFixed(1));
            return p.copyWith(distanceKm: rounded);
          }
          return p;
        }).toList();

        realList.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

        setState(() {
          _nearbyProviders = realList;
          _isLoadingProviders = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProviders = false);
      }
    }
  }

  Future<void> _initializeLocation() async {
    // 1. Load saved/cached location
    final cached = await LocationService.getSavedLocation();
    if (cached != null && mounted) {
      setState(() => _userLocation = cached);
      _loadNearbyProviders();
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
        _loadNearbyProviders();
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
      _loadNearbyProviders();
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
    return 'User';
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
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
    final palette = AppPalette.of(context);
    final topCategories = ServiceCategory.allCategories.take(3).toList();

    final pages = [
      _buildHomeContent(topCategories, palette),
      CustomerBookingsPage(
        user: widget.user,
        api: widget.api,
        onSwitchTab: (index) => setState(() => _currentNavIndex = index),
      ),
      const CustomerChatPage(),
      ProfilePage(
        user: widget.user,
        api: widget.api,
        onBackToHome: () => setState(() => _currentNavIndex = 0),
        onTabChange: (index) => setState(() => _currentNavIndex = index),
        showBottomNav: false,
      ),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      body: IndexedStack(index: _currentNavIndex, children: pages),
      bottomNavigationBar: TaskBridgeBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 1) {
            BookingsSyncService.instance.triggerImmediateUpdate();
          } else if (index == 2) {
            ChatService().triggerConversationsRefresh();
          }
          setState(() => _currentNavIndex = index);
        },
      ),
    );
  }

  Widget _buildHomeContent(
    List<ServiceCategory> topCategories,
    AppPalette palette,
  ) {
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
            Text(
              'YOUR HOME, IN GOOD HANDS',
              style: TextStyle(
                color: palette.primary,
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
                    '$_greeting,\n$_userName',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: palette.text,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    AppIcons.notification,
                    color: palette.text,
                    size: 26,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            // ── Location Center Row ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(AppIcons.location, color: palette.primary, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _isLoadingLocation
                          ? 'Locating you… · '
                          : '${_userLocation.shortName} · ',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isLoadingLocation)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            palette.primary,
                          ),
                        ),
                      ),
                    ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _changeLocation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Text(
                        'Change',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s20),

            // ── Search Bar ──
            TaskBridgeSearchBar(
              hintText: 'Search services or providers',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProviderSearchPage(
                      location: _userLocation.shortName,
                      userLocation: _userLocation,
                      user: widget.user,
                    ),
                  ),
                );
              },
              readOnly: true,
            ),

            const SizedBox(height: AppSpacing.s16),

            // ── AI Recommendation Card (Compact) ──
            InkWell(
              onTap: () {
                AiPromptSheet.show(
                  context,
                  currentLocation: _userLocation.shortName,
                  user: widget.user,
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border, width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: palette.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Don\u2019t know who to hire?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Get instant AI specialist recommendation',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ask AI',
                            style: TextStyle(
                              color: palette.onPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: palette.onPrimary,
                            size: 13,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s20),

            // ── Browse Services Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Browse services',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                GestureDetector(
                  onTap: _openAllCategories,
                  child: Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.primary,
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProviderSearchPage(
                              initialCategory: cat.name,
                              location: _userLocation.shortName,
                              userLocation: _userLocation,
                            ),
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
                Text(
                  'Available near you',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProviderSearchPage(
                          location: _userLocation.shortName,
                          userLocation: _userLocation,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            // ── Dynamic Provider Cards from Database ──
            if (_isLoadingProviders)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                  ),
                ),
              )
            else if (_nearbyProviders.isEmpty)
              Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border, width: 1),
                ),
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: palette.muted,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No specialists registered nearby yet in ${_userLocation.shortName}. Tap "View all" to see all areas.',
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.muted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _nearbyProviders.take(3).map((provider) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ProviderCardWidget(provider: provider),
                  );
                }).toList(),
              ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

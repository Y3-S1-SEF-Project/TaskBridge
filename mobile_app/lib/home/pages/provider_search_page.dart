import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../ai/widgets/ai_prompt_sheet.dart';
import '../../auth/data/auth_models.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../data/provider_api.dart';
import '../models/provider_item.dart';
import '../widgets/provider_card.dart';

enum ProviderSortOption {
  distance('Nearest First', Icons.near_me_rounded, 'Sort by closest distance from you'),
  rating('Highest Rated', Icons.star_rounded, 'Sort by highest customer review rating'),
  priceLowToHigh('Price: Low to High', Icons.arrow_upward_rounded, 'Sort by lowest hourly rate first'),
  priceHighToLow('Price: High to Low', Icons.arrow_downward_rounded, 'Sort by highest hourly rate first'),
  reviews('Most Reviewed', Icons.rate_review_rounded, 'Sort by number of customer reviews');

  final String label;
  final IconData icon;
  final String description;
  const ProviderSortOption(this.label, this.icon, this.description);
}

class ProviderSearchPage extends StatefulWidget {
  final String? initialCategory;
  final String? initialQuery;
  final String? location;
  final UserLocation? userLocation;
  final AuthUser? user;

  const ProviderSearchPage({
    super.key,
    this.initialCategory,
    this.initialQuery,
    this.location,
    this.userLocation,
    this.user,
  });

  @override
  State<ProviderSearchPage> createState() => _ProviderSearchPageState();
}

class _ProviderSearchPageState extends State<ProviderSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  late String _selectedCategory;
  List<ProviderItem> _providers = [];
  bool _isLoading = true;
  Timer? _debounceTimer;

  UserLocation? _customerLocation;
  ProviderSortOption _selectedSort = ProviderSortOption.distance;

  static const List<String> _categories = [
    'All',
    'Plumbing',
    'Electrical',
    'HVAC',
    'Cleaning',
    'Painting',
    'Carpentry',
    'Gardening & Outdoor',
    'Roofing',
    'Appliance Repair',
    'IT & Security',
    'Masonry',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'All';
    _customerLocation = widget.userLocation;
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    _initCustomerLocationAndLoad();
  }

  Future<void> _initCustomerLocationAndLoad() async {
    if (_customerLocation == null) {
      final saved = await LocationService.getSavedLocation();
      if (saved != null && mounted) {
        setState(() => _customerLocation = saved);
      }
    }
    _loadProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await ProviderApi.getProviders(
        query: _searchController.text.trim(),
        category: _selectedCategory,
        location: _customerLocation?.shortName ?? widget.location,
        lat: _customerLocation?.latitude,
        lng: _customerLocation?.longitude,
        sortBy: _getApiSortKey(_selectedSort),
        excludeUserId: widget.user?.id,
        excludeName: widget.user?.fullName,
      );

      if (mounted) {
        final currentUserId = widget.user?.id.toLowerCase();
        final currentUserName = widget.user?.fullName.trim().toLowerCase();

        _providers = results.where((p) {
          if (currentUserId != null && p.userId.toLowerCase() == currentUserId) {
            return false;
          }
          if (currentUserName != null &&
              p.fullName.trim().toLowerCase() == currentUserName) {
            return false;
          }
          return true;
        }).toList();

        _calculateRealDistancesAndSort();
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getApiSortKey(ProviderSortOption sort) {
    switch (sort) {
      case ProviderSortOption.distance:
        return 'distance';
      case ProviderSortOption.rating:
        return 'rating';
      case ProviderSortOption.priceLowToHigh:
        return 'price_asc';
      case ProviderSortOption.priceHighToLow:
        return 'price_desc';
      case ProviderSortOption.reviews:
        return 'reviews';
    }
  }

  /// Calculates actual geodesic distance between the customer's coordinates
  /// and each provider's coordinates, then applies the active sort order.
  void _calculateRealDistancesAndSort() {
    if (_customerLocation != null) {
      final cLat = _customerLocation!.latitude;
      final cLng = _customerLocation!.longitude;

      _providers = _providers.map((p) {
        if (p.latitude != null && p.longitude != null && p.latitude != 0 && p.longitude != 0) {
          final meters = Geolocator.distanceBetween(
            cLat,
            cLng,
            p.latitude!,
            p.longitude!,
          );
          final km = meters / 1000.0;
          final rounded = km < 0.5 ? 0.5 : double.parse(km.toStringAsFixed(1));
          return p.copyWith(distanceKm: rounded);
        }
        return p;
      }).toList();
    }

    _applySort();
  }

  void _applySort() {
    switch (_selectedSort) {
      case ProviderSortOption.distance:
        _providers.sort((a, b) {
          final cmp = a.distanceKm.compareTo(b.distanceKm);
          return cmp != 0 ? cmp : b.rating.compareTo(a.rating);
        });
        break;
      case ProviderSortOption.rating:
        _providers.sort((a, b) {
          final cmp = b.rating.compareTo(a.rating);
          return cmp != 0 ? cmp : b.reviewCount.compareTo(a.reviewCount);
        });
        break;
      case ProviderSortOption.priceLowToHigh:
        _providers.sort((a, b) {
          final cmp = a.hourlyRate.compareTo(b.hourlyRate);
          return cmp != 0 ? cmp : a.distanceKm.compareTo(b.distanceKm);
        });
        break;
      case ProviderSortOption.priceHighToLow:
        _providers.sort((a, b) {
          final cmp = b.hourlyRate.compareTo(a.hourlyRate);
          return cmp != 0 ? cmp : a.distanceKm.compareTo(b.distanceKm);
        });
        break;
      case ProviderSortOption.reviews:
        _providers.sort((a, b) {
          final cmp = b.reviewCount.compareTo(a.reviewCount);
          return cmp != 0 ? cmp : b.rating.compareTo(a.rating);
        });
        break;
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadProviders();
    });
  }

  void _onCategorySelected(String category) {
    if (_selectedCategory == category) return;
    setState(() {
      _selectedCategory = category;
    });
    _loadProviders();
  }

  void _showSortModal() {
    final palette = AppPalette.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(
                      Icons.swap_vert_rounded,
                      color: palette.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sort Specialists By',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...ProviderSortOption.values.map((option) {
                  final isSelected = _selectedSort == option;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedSort = option;
                        _applySort();
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.soft : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? palette.primary : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            option.icon,
                            size: 20,
                            color: isSelected ? palette.primary : palette.muted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? palette.primary : palette.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  option.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: palette.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isFilteringCategory =
        _selectedCategory != 'All' && _selectedCategory.isNotEmpty;
    final currentLocName = _customerLocation?.shortName ?? widget.location ?? 'Colombo';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrowLeft, color: palette.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isFilteringCategory
              ? '$_selectedCategory Specialists'
              : 'Find Specialists',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: palette.text,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search Input Field ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: AppSpacing.s8,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: widget.initialQuery != null,
                  style: TextStyle(
                    fontSize: 15,
                    color: palette.text,
                  ),
                  decoration: InputDecoration(
                    hintText: isFilteringCategory
                        ? 'Search within $_selectedCategory…'
                        : 'Search specialists, skills, or services…',
                    hintStyle: TextStyle(
                      color: palette.muted,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: palette.muted,
                      size: 22,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: palette.muted,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _loadProviders();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),
            ),

            // ── Category Filter Chips ──
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s20,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();

                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => _onCategorySelected(cat),
                    selectedColor: palette.primary,
                    backgroundColor: palette.surface,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? palette.onPrimary : palette.text,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? palette.primary : palette.border,
                      ),
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // ── Interactive Header Summary & Sort By Button ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoading
                              ? 'Searching specialists…'
                              : '${_providers.length} ${_providers.length == 1 ? "specialist" : "specialists"} available',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(AppIcons.location, size: 12, color: palette.primary),
                            const SizedBox(width: 4),
                            Text(
                              currentLocName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: palette.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Interactive Sort By Pill ──
                  InkWell(
                    onTap: _showSortModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_vert_rounded,
                            size: 16,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _selectedSort.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: palette.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // ── Provider Results List ──
            Expanded(
              child: _buildContent(palette, currentLocName),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppPalette palette, String locName) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_providers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadProviders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: palette.soft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  size: 36,
                  color: palette.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _selectedCategory != 'All'
                    ? 'No registered $_selectedCategory specialists yet'
                    : 'No specialists found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We couldn\'t find any verified providers matching your filter near $locName.\nTry another category or use TaskBridge AI matching!',
                style: TextStyle(
                  fontSize: 14,
                  color: palette.muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text(
                  'Get AI Recommendation',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  AiPromptSheet.show(
                    context,
                    currentLocation: locName,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProviders,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s12,
        ),
        itemCount: _providers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final p = _providers[index];
          return ProviderCardWidget(provider: p);
        },
      ),
    );
  }
}

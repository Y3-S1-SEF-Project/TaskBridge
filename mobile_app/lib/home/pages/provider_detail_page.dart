import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/bookings_sync_service.dart';
import '../../ai/services/review_api.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../models/provider_item.dart';
import 'book_specialist_page.dart';
import '../../chat/pages/active_chat_page.dart';
import '../../chat/services/chat_service.dart';

class ProviderDetailPage extends StatefulWidget {
  final ProviderItem provider;
  final AuthUser? user;

  const ProviderDetailPage({super.key, required this.provider, this.user});

  @override
  State<ProviderDetailPage> createState() => _ProviderDetailPageState();
}

class _ProviderDetailPageState extends State<ProviderDetailPage> {
  ProviderItem get provider => widget.provider;
  List<FeedbackModel> _feedbacks = [];
  bool _isLoadingFeedbacks = false;
  AuthUser? _currentUser;
  GoogleMapController? _mapController;
  UserLocation? _customerLocation;
  double? _calculatedDistanceKm;
  late LatLng _providerLatLng;

  bool get _isOwnProfile =>
      _currentUser != null &&
      (_currentUser!.id == provider.userId ||
          _currentUser!.id == provider.id ||
          (_currentUser!.fullName.trim().toLowerCase() ==
                  provider.fullName.trim().toLowerCase() &&
              provider.fullName.isNotEmpty));

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser == null) {
      AuthApi.getCachedUser().then((u) {
        if (mounted && u != null) {
          setState(() => _currentUser = u);
        }
      });
    }
    _providerLatLng = LatLng(
      (provider.latitude != null && provider.latitude != 0)
          ? provider.latitude!
          : UserLocation.defaultLocation.latitude,
      (provider.longitude != null && provider.longitude != 0)
          ? provider.longitude!
          : UserLocation.defaultLocation.longitude,
    );
    _loadFeedbacks();
    _loadCustomerLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerLocation() async {
    try {
      final saved = await LocationService.getSavedLocation();
      if (saved != null && mounted) {
        setState(() {
          _customerLocation = saved;
          _recomputeDistance();
        });
      }
      final live = await LocationService.determineCurrentPosition();
      if (live != null && mounted) {
        setState(() {
          _customerLocation = live;
          _recomputeDistance();
        });
      }
    } catch (_) {}
  }

  void _recomputeDistance() {
    if (_customerLocation == null) return;
    final meters = Geolocator.distanceBetween(
      _customerLocation!.latitude,
      _customerLocation!.longitude,
      _providerLatLng.latitude,
      _providerLatLng.longitude,
    );
    final km = meters / 1000.0;
    setState(() {
      _calculatedDistanceKm = km < 0.5
          ? 0.5
          : double.parse(km.toStringAsFixed(1));
    });
  }

  double _extractRadiusKm(String? serviceAreas) {
    if (serviceAreas == null || serviceAreas.isEmpty) return 15.0;
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*km',
      caseSensitive: false,
    ).firstMatch(serviceAreas);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 15.0;
    }
    return 15.0;
  }

  double get _coverageRadiusKm => _extractRadiusKm(provider.serviceAreas);

  double _getZoomForRadius(double radiusKm) {
    if (radiusKm <= 5) return 12.2;
    if (radiusKm <= 10) return 11.2;
    if (radiusKm <= 15) return 10.4;
    if (radiusKm <= 25) return 9.5;
    return 8.5;
  }

  String get _distanceDisplay {
    if (_calculatedDistanceKm != null && _calculatedDistanceKm! < 500) {
      return '${_calculatedDistanceKm!.toStringAsFixed(1)} km away';
    }
    return '${provider.distanceKm} km away';
  }

  bool get _isCustomerCovered {
    if (_calculatedDistanceKm != null && _calculatedDistanceKm! < 500) {
      return _calculatedDistanceKm! <= _coverageRadiusKm;
    }
    return provider.distanceKm <= _coverageRadiusKm;
  }

  bool get _isWithinReasonableDistance {
    if (_customerLocation == null) return false;
    if (_calculatedDistanceKm != null) {
      return _calculatedDistanceKm! < 100;
    }
    return provider.distanceKm < 100;
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoadingFeedbacks = true);
    final target = widget.provider.id.isNotEmpty
        ? widget.provider.id
        : widget.provider.fullName;
    final list = await ReviewApi.getProviderFeedbacks(target);
    if (mounted) {
      setState(() {
        _isLoadingFeedbacks = false;
        _feedbacks = list;
      });
    }
  }

  double get _displayRating {
    if (_feedbacks.isEmpty) return widget.provider.rating;
    return _feedbacks.fold<double>(0.0, (acc, f) => acc + f.rating.toDouble()) /
        _feedbacks.length;
  }

  int get _displayReviewCount {
    if (_feedbacks.isEmpty) return widget.provider.reviewCount;
    return _feedbacks.length;
  }

  Future<void> _callProvider(BuildContext context) async {
    final rawPhone = provider.phone.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available for this specialist.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final cleaned = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open dialer for $rawPhone'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open dialer for $rawPhone'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openChat(BuildContext context) async {
    final pId = provider.userId.isNotEmpty ? provider.userId : provider.id;
    if (pId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot initiate chat: Provider ID missing.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final conv = await ChatService().findOrCreateConversation(providerId: pId);

    if (context.mounted) Navigator.pop(context);

    if (conv != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActiveChatPage(
            conversationId: conv.id,
            recipientId: conv.providerId,
            recipientName: conv.providerName.isNotEmpty
                ? conv.providerName
                : provider.fullName,
            subtitle: provider.category,
          ),
        ),
      );
    } else if (context.mounted) {
      final msg = _isOwnProfile
          ? 'Cannot chat with your own profile. Try testing with another specialist!'
          : 'Could not open chat with ${provider.fullName}. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAvatar(double dimension) {
    final photoUrl = provider.profilePhotoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(dimension / 3),
        child: Image.network(
          photoUrl,
          width: dimension,
          height: dimension,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackAvatar(dimension),
        ),
      );
    }
    return _buildFallbackAvatar(dimension);
  }

  Widget _buildFallbackAvatar(double dimension) {
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(dimension / 3),
      ),
      alignment: Alignment.center,
      child: Text(
        provider.initials,
        style: TextStyle(
          color: const Color(0xFF2E7D32),
          fontWeight: FontWeight.w800,
          fontSize: dimension * 0.35,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    Color? valueColor,
    required IconData icon,
    required AppPalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: palette.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? palette.text,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: palette.muted,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

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
          'Specialist Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: palette.text,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: palette.text),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Profile link copied for ${provider.fullName}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Profile Card ──
            Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
              ),
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        _buildAvatar(88),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_rounded,
                              color: palette.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    provider.fullName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: palette.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      provider.category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
                  ),
                  if (_isOwnProfile) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 13,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Your Profile (Preview)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _displayRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '($_displayReviewCount customer ${_displayReviewCount == 1 ? 'review' : 'reviews'})',
                        style: TextStyle(fontSize: 13, color: palette.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // ── 2x2 Key Stats Grid ──
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Hourly Rate',
                    value: 'Rs. ${provider.hourlyRate.toInt()}/hr',
                    subtitle: 'Starting rate',
                    icon: Icons.payments_outlined,
                    palette: palette,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Distance',
                    value: _distanceDisplay,
                    subtitle: _customerLocation != null
                        ? 'From ${_customerLocation!.shortName}'
                        : 'From your location',
                    icon: Icons.near_me_rounded,
                    palette: palette,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Availability',
                    value: 'Available Today',
                    subtitle: 'Fast response',
                    valueColor: const Color(0xFF16A34A),
                    icon: Icons.schedule_rounded,
                    palette: palette,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Verification',
                    value: 'Identity Verified',
                    subtitle: 'Background checked',
                    valueColor: palette.primary,
                    icon: Icons.verified_user_outlined,
                    palette: palette,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),

            // ── Skills & Expertise ──
            if (provider.skills != null && provider.skills!.isNotEmpty) ...[
              Text(
                'Skills & Expertise',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: provider.skills!
                    .split('·')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                              color: palette.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              skill,
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.s20),
            ],

            // ── About Specialist ──
            Text(
              'About Specialist',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                provider.bio != null && provider.bio!.isNotEmpty
                    ? provider.bio!
                    : 'Verified professional specialist on TaskBridge delivering exceptional service quality with guaranteed workmanship.',
                style: TextStyle(
                  fontSize: 14,
                  color: palette.muted,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s20),

            // ── Service Coverage Area with Map ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Service Coverage Area',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isCustomerCovered
                        ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                        : palette.soft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isCustomerCovered
                            ? Icons.check_circle_rounded
                            : Icons.radar_rounded,
                        size: 13,
                        color: _isCustomerCovered
                            ? const Color(0xFF16A34A)
                            : palette.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isCustomerCovered
                            ? 'Within Coverage'
                            : '${_coverageRadiusKm.toInt()} km Radius',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _isCustomerCovered
                              ? const Color(0xFF16A34A)
                              : palette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border, width: 1.1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 195,
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _providerLatLng,
                            zoom: _getZoomForRadius(_coverageRadiusKm),
                          ),
                          onMapCreated: (controller) =>
                              _mapController = controller,
                          circles: {
                            Circle(
                              circleId: const CircleId(
                                'provider_coverage_circle',
                              ),
                              center: _providerLatLng,
                              radius: _coverageRadiusKm * 1000.0,
                              fillColor: palette.primary.withValues(
                                alpha: 0.16,
                              ),
                              strokeColor: palette.primary,
                              strokeWidth: 2,
                            ),
                          },
                          markers: {
                            Marker(
                              markerId: const MarkerId('provider_marker'),
                              position: _providerLatLng,
                              infoWindow: InfoWindow(
                                title: provider.fullName,
                                snippet: '${provider.category} (Base)',
                              ),
                            ),
                            if (_customerLocation != null)
                              Marker(
                                markerId: const MarkerId('customer_marker'),
                                position: LatLng(
                                  _customerLocation!.latitude,
                                  _customerLocation!.longitude,
                                ),
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueAzure,
                                ),
                                infoWindow: InfoWindow(
                                  title: 'Your Location',
                                  snippet: _customerLocation!.shortName,
                                ),
                              ),
                          },
                          polylines: {
                            if (_customerLocation != null &&
                                _isWithinReasonableDistance)
                              Polyline(
                                polylineId: const PolylineId(
                                  'customer_provider_line',
                                ),
                                points: [
                                  LatLng(
                                    _customerLocation!.latitude,
                                    _customerLocation!.longitude,
                                  ),
                                  _providerLatLng,
                                ],
                                color: palette.primary,
                                width: 3,
                                patterns: [
                                  PatternItem.dash(12),
                                  PatternItem.gap(6),
                                ],
                              ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          compassEnabled: false,
                          mapToolbarEnabled: false,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                        ),

                        // Floating Coverage Pill
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.radar_rounded,
                                  size: 14,
                                  color: palette.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${_coverageRadiusKm.toInt()} km Service Radius',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: palette.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Floating Distance Pill
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me_rounded,
                                  size: 13,
                                  color: palette.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _distanceDisplay,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: palette.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Recenter Map Button
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: InkWell(
                            onTap: () {
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  _providerLatLng,
                                  _getZoomForRadius(_coverageRadiusKm),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.my_location_rounded,
                                size: 18,
                                color: palette.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Area Description Details
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: palette.soft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            AppIcons.location,
                            color: palette.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.serviceAreas != null &&
                                        provider.serviceAreas!.isNotEmpty
                                    ? provider.serviceAreas!
                                    : 'Operational Base: Colombo Area',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: palette.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isCustomerCovered
                                    ? 'Your location is covered for on-site services'
                                    : 'Specialist travels within this operational radius',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _isCustomerCovered
                                      ? const Color(0xFF16A34A)
                                      : palette.muted,
                                  fontWeight: _isCustomerCovered
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s20),

            // ── Customer Reviews Preview (Real Feedbacks) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Reviews',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
                if (_feedbacks.isNotEmpty)
                  Text(
                    '${_displayRating.toStringAsFixed(1)} ★ (${_feedbacks.length})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingFeedbacks)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_feedbacks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s20),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 36,
                      color: palette.muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No reviews yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Completed jobs with client sign-off ratings will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              )
            else
              ..._feedbacks.map((fb) {
                final dateStr =
                    '${fb.createdAt.year}-${fb.createdAt.month.toString().padLeft(2, '0')}-${fb.createdAt.day.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildReviewCard(
                    name: fb.customerName.isNotEmpty
                        ? fb.customerName
                        : 'Verified Customer',
                    date: dateStr,
                    rating: fb.rating.toDouble(),
                    comment: fb.comment.isNotEmpty
                        ? fb.comment
                        : 'Service completed and approved with quality sign-off.',
                    palette: palette,
                  ),
                );
              }),
            const SizedBox(height: 100), // clearance for sticky bottom bar
          ],
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.only(
          left: AppSpacing.s20,
          right: AppSpacing.s20,
          top: 12,
          bottom: bottomInset > 0 ? bottomInset + 8 : 16,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: palette.border, width: 1.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (provider.phone.isNotEmpty) ...[
              Tooltip(
                message: 'Call ${provider.fullName}',
                child: Material(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => _callProvider(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.phone_rounded,
                        color: palette.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Tooltip(
              message: 'Chat with ${provider.fullName}',
              child: Material(
                color: palette.soft,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _openChat(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: palette.primary,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookSpecialistPage(
                          provider: provider,
                          user: _currentUser,
                        ),
                      ),
                    );
                    if (result == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Proposal sent to ${provider.fullName}! Saved to your bookings.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      BookingsSyncService.instance.triggerImmediateUpdate();
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Book Specialist',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard({
    required String name,
    required String date,
    required double rating,
    required String comment,
    required AppPalette palette,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(date, style: TextStyle(fontSize: 11, color: palette.muted)),
          const SizedBox(height: 6),
          Text(
            comment,
            style: TextStyle(fontSize: 13, color: palette.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

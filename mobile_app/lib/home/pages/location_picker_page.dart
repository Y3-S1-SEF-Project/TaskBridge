import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/design_system.dart';

class LocationPickerPage extends StatefulWidget {
  final UserLocation initialLocation;

  const LocationPickerPage({super.key, required this.initialLocation});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();

  late LatLng _currentCenter;
  UserLocation? _selectedLocation;
  bool _isGeocoding = false;
  bool _isLocatingGps = false;
  bool _isDragging = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentCenter = LatLng(
      widget.initialLocation.latitude,
      widget.initialLocation.longitude,
    );
    _selectedLocation = widget.initialLocation;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    _currentCenter = position.target;
    if (!_isDragging) {
      setState(() => _isDragging = true);
    }
  }

  void _onCameraIdle() {
    setState(() => _isDragging = false);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _resolveAddressForCenter();
    });
  }

  Future<void> _resolveAddressForCenter() async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    try {
      final loc = await LocationService.getAddressFromCoordinates(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );
      if (mounted) {
        setState(() {
          _selectedLocation = loc;
          _isGeocoding = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _snapToUserGps() async {
    setState(() => _isLocatingGps = true);
    try {
      final gpsLoc = await LocationService.determineCurrentPosition();
      if (!mounted) return;
      setState(() => _isLocatingGps = false);

      if (gpsLoc != null) {
        final target = LatLng(gpsLoc.latitude, gpsLoc.longitude);
        _animateCameraTo(target);
        setState(() {
          _selectedLocation = gpsLoc;
          _currentCenter = target;
        });
      }
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _isLocatingGps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          action: e.isPermanentlyDenied
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => Geolocator.openAppSettings(),
                )
              : (e.isServiceDisabled
                    ? SnackBarAction(
                        label: 'Settings',
                        textColor: Colors.white,
                        onPressed: () => Geolocator.openLocationSettings(),
                      )
                    : null),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLocatingGps = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not access current GPS location: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isGeocoding = true);

    final found = await LocationService.searchLocation(query);
    if (!mounted) return;
    setState(() => _isGeocoding = false);

    if (found != null) {
      final target = LatLng(found.latitude, found.longitude);
      _animateCameraTo(target);
      setState(() {
        _selectedLocation = found;
        _currentCenter = target;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No location found matching "$query".'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _animateCameraTo(LatLng target) async {
    final controller = await _mapController.future;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)),
    );
    if (mounted) {
      setState(() {
        _currentCenter = target;
      });
      _resolveAddressForCenter();
    }
  }

  void _confirmAndReturn() {
    final locationToReturn =
        _selectedLocation ??
        UserLocation(
          shortName: 'Custom Location',
          address:
              'Lat: ${_currentCenter.latitude.toStringAsFixed(4)}, Lng: ${_currentCenter.longitude.toStringAsFixed(4)}',
          latitude: _currentCenter.latitude,
          longitude: _currentCenter.longitude,
        );

    LocationService.saveLocation(locationToReturn);
    Navigator.pop(context, locationToReturn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map View ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 15.5,
            ),
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
            onTap: (LatLng tappedPoint) => _animateCameraTo(tappedPoint),
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Centered Map Pin with Float Animation ──
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                offset: _isDragging ? const Offset(0, -0.25) : Offset.zero,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.place_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Top Navigation & Search Bar ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 22,
                        child: IconButton(
                          icon: const Icon(
                            AppIcons.arrowLeft,
                            color: AppColors.textPrimary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _performSearch(),
                            decoration: InputDecoration(
                              hintText: 'Search city, street, landmark…',
                              hintStyle: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.primary,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.primary,
                                ),
                                onPressed: _performSearch,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Floating GPS "My Location" Button ──
          Positioned(
            right: 16,
            bottom: 240,
            child: FloatingActionButton(
              heroTag: 'gps_btn',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _isLocatingGps ? null : _snapToUserGps,
              child: _isLocatingGps
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                    ),
            ),
          ),

          // ── Bottom Address Banner & Confirmation Button ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isGeocoding
                                    ? 'Pinpointing address…'
                                    : (_selectedLocation?.shortName ??
                                          'Selected Location'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _isGeocoding
                                    ? 'Moving to target location…'
                                    : (_selectedLocation?.address ??
                                          'Target coordinates'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (_isGeocoding)
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppButton(
                      label: 'Confirm Location',
                      onPressed: _isGeocoding ? null : _confirmAndReturn,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

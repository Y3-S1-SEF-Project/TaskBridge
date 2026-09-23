import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/services/bookings_sync_service.dart';
import '../../ai/services/coordination_api.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../models/provider_item.dart';
import 'location_picker_page.dart';

class BookSpecialistPage extends StatefulWidget {
  final ProviderItem provider;
  final AuthUser? user;

  const BookSpecialistPage({super.key, required this.provider, this.user});

  @override
  State<BookSpecialistPage> createState() => _BookSpecialistPageState();
}

class _BookSpecialistPageState extends State<BookSpecialistPage> {
  ProviderItem get provider => widget.provider;
  AuthUser? _currentUser;

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _locationController;
  late final TextEditingController _priceController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String _rateType = 'Hourly';
  bool _isSubmitting = false;
  String? _errorMessage;

  UserLocation? _selectedLocation;
  GoogleMapController? _miniMapController;
  bool _isLocatingGps = false;

  List<UserLocation> _locationSuggestions = [];
  bool _showLocationDropdown = false;
  bool _isLoadingLocationSuggestions = false;
  Timer? _locationSearchDebounce;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser == null) {
      AuthApi.getCachedUser().then((u) {
        if (mounted && u != null) {
          setState(() {
            _currentUser = u;
            if (_locationController.text.isEmpty ||
                _locationController.text == 'Colombo 05') {
              _locationController.text =
                  u.location ?? u.address ?? 'Colombo 05';
            }
          });
          _initInitialLocation(_locationController.text);
        }
      });
    }

    final suggestions = _getCategorySuggestions(provider.category);
    _titleController = TextEditingController(
      text: suggestions.isNotEmpty
          ? suggestions.first
          : '${provider.category} Service',
    );
    _notesController = TextEditingController();

    final defaultLocation =
        _currentUser?.location ??
        _currentUser?.address ??
        (provider.serviceAreas?.split(',').first.trim().isNotEmpty == true
            ? provider.serviceAreas!.split(',').first.trim()
            : 'Colombo 05');
    _locationController = TextEditingController(text: defaultLocation);

    _priceController = TextEditingController(
      text: provider.hourlyRate.toInt().toString(),
    );

    _selectedDate = DateTime.now().add(const Duration(days: 1));
    _selectedTime = const TimeOfDay(hour: 10, minute: 0);

    _initInitialLocation(defaultLocation);
  }

  @override
  void dispose() {
    _locationSearchDebounce?.cancel();
    _miniMapController?.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onLocationChanged(String text) {
    _locationSearchDebounce?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _locationSuggestions = [];
        _showLocationDropdown = false;
        _isLoadingLocationSuggestions = false;
      });
      return;
    }

    final lower = trimmed.toLowerCase();
    final instantMatches = LocationService.popularSriLankanPlaces
        .where((loc) =>
            loc.shortName.toLowerCase().contains(lower) ||
            loc.address.toLowerCase().contains(lower))
        .take(5)
        .toList();

    setState(() {
      _locationSuggestions = instantMatches;
      _showLocationDropdown = true;
      _isLoadingLocationSuggestions = true;
    });

    _locationSearchDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await LocationService.searchSuggestions(trimmed, limit: 6);
      if (mounted && _locationController.text.trim() == trimmed) {
        setState(() {
          _locationSuggestions = results.isNotEmpty ? results : instantMatches;
          _isLoadingLocationSuggestions = false;
          _showLocationDropdown = _locationSuggestions.isNotEmpty;
        });
      }
    });
  }

  void _selectLocationSuggestion(UserLocation suggestion) {
    _locationSearchDebounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedLocation = suggestion;
      _locationController.text = suggestion.address;
      _showLocationDropdown = false;
      _locationSuggestions = [];
    });
    _syncMiniMapCamera();
  }

  Future<void> _initInitialLocation(String initialAddress) async {
    final saved = await LocationService.getSavedLocation();
    if (saved != null && mounted) {
      setState(() {
        _selectedLocation = saved;
        if (_locationController.text.isEmpty ||
            _locationController.text == 'Colombo 05') {
          _locationController.text = saved.address;
        }
      });
      _syncMiniMapCamera();
      return;
    }

    if (initialAddress.isNotEmpty && initialAddress != 'Colombo 05') {
      try {
        final searched = await LocationService.searchLocation(initialAddress);
        if (searched != null && mounted) {
          setState(() => _selectedLocation = searched);
          _syncMiniMapCamera();
          return;
        }
      } catch (_) {}
    }

    if (mounted && _selectedLocation == null) {
      setState(() => _selectedLocation = UserLocation.defaultLocation);
    }
  }

  void _syncMiniMapCamera() {
    if (_miniMapController != null && _selectedLocation != null) {
      _miniMapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _selectedLocation!.latitude,
              _selectedLocation!.longitude,
            ),
            zoom: 15,
          ),
        ),
      );
    }
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push<UserLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocation: _selectedLocation ?? UserLocation.defaultLocation,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result;
        _locationController.text = result.address;
      });
      _syncMiniMapCamera();
    }
  }

  Future<void> _useCurrentGpsLocation() async {
    setState(() => _isLocatingGps = true);
    try {
      final loc = await LocationService.determineCurrentPosition();
      if (loc != null && mounted) {
        setState(() {
          _selectedLocation = loc;
          _locationController.text = loc.address;
        });
        _syncMiniMapCamera();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Updated to GPS location: ${loc.shortName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not obtain GPS location: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  List<String> _getCategorySuggestions(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('plumb')) {
      return [
        'Tap & Faucet Repair',
        'Pipe Leak Repair',
        'Drain Cleaning',
        'Tank & Pump Service',
      ];
    } else if (cat.contains('electr')) {
      return [
        'Wiring & Short Circuit',
        'Socket & Switch Repair',
        'Ceiling Fan Installation',
        'Lighting Setup',
      ];
    } else if (cat.contains('clean')) {
      return [
        'Full House Cleaning',
        'Deep Bathroom Cleaning',
        'Sofa & Carpet Wash',
        'Kitchen Degreasing',
      ];
    } else if (cat.contains('carpent')) {
      return [
        'Door & Lock Repair',
        'Furniture Assembly',
        'Cabinet & Shelf Fixing',
        'Wood Polishing',
      ];
    } else if (cat.contains('paint')) {
      return [
        'Interior Wall Painting',
        'Exterior Wall Painting',
        'Waterproof Coating',
        'Touch-up Work',
      ];
    } else if (cat.contains('ac') ||
        cat.contains('air') ||
        cat.contains('appliance')) {
      return [
        'AC Servicing & Cleaning',
        'AC Gas Refill',
        'Washing Machine Repair',
        'Refrigerator Servicing',
      ];
    } else if (cat.contains('gard')) {
      return [
        'Lawn Mowing & Cleanup',
        'Tree Trimming',
        'Garden Landscaping',
        'Weed Control',
      ];
    }
    return [
      'General Maintenance',
      'Inspection & Diagnostic',
      'Emergency Repair',
      'Routine Servicing',
    ];
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

  Widget _buildQuickSlotChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppPalette palette,
  }) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppColors.primaryDark : palette.text,
        ),
      ),
      backgroundColor: isSelected
          ? AppColors.mint.withValues(alpha: 0.4)
          : palette.surface,
      side: BorderSide(color: isSelected ? AppColors.primary : palette.border),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: onTap,
    );
  }

  Future<void> _onSubmit() async {
    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final priceVal = double.tryParse(_priceController.text.trim());

    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a service or job title.');
      return;
    }
    if (location.isEmpty) {
      setState(() => _errorMessage = 'Please enter a service location.');
      return;
    }
    if (priceVal == null || priceVal <= 0) {
      setState(() => _errorMessage = 'Please enter a valid price.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      _currentUser ??= await AuthApi.getCachedUser();

      final custName = (_currentUser?.fullName.isNotEmpty == true)
          ? _currentUser!.fullName
          : 'Customer';
      final custId = _currentUser?.id;

      final scheduleDisplay =
          '${_formatDate(_selectedDate)} · ${_formatTime(_selectedTime)} · $location';
      final refNum = DateTime.now().millisecondsSinceEpoch % 9000 + 1000;
      final bookingRef = 'PR-$refNum';
      final notesText = _notesController.text.trim();

      final booking = BookingDetails(
        bookingReference: bookingRef,
        serviceTitle: title,
        providerName: provider.fullName,
        customerId: custId,
        customerName: custName,
        location: location,
        schedule: scheduleDisplay,
        price: priceVal,
        priceFormatted: _rateType == 'Hourly'
            ? 'Rs. ${priceVal.toInt()}/hr'
            : 'Rs. ${priceVal.toInt()}',
        notes: notesText.isNotEmpty ? notesText : null,
        status: 'Requested',
      );

      final provId = provider.id.isNotEmpty ? provider.id : provider.userId;

      await CoordinationApi.createQuotationRequest(
        booking: booking,
        category: provider.category,
        providerId: provId,
        customerId: custId,
        customerName: custName,
        rateType: _rateType,
        notes: notesText.isNotEmpty ? notesText : null,
      );

      BookingsSyncService.instance.triggerImmediateUpdate();

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to submit proposal: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final suggestions = _getCategorySuggestions(provider.category);
    final isHourly = _rateType == 'Hourly';
    final schedulePreview =
        '${_formatDate(_selectedDate)} · ${_formatTime(_selectedTime)}';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Book Specialist',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: palette.text,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: palette.text,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: palette.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Specialist Snapshot Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  _buildAvatar(52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                provider.fullName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: palette.text,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                provider.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 14,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  provider.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: palette.text,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '(${provider.reviewCount})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Standard Rate',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Rs. ${provider.hourlyRate.toInt()}/hr',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Service & Job Details
            Text(
              '1. Service & Job Details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              style: TextStyle(fontSize: 14, color: palette.text),
              decoration: InputDecoration(
                labelText: 'Service Needed / Job Title',
                hintText: 'e.g. Tap Leak Repair, Wiring Fix',
                prefixIcon: const Icon(
                  Icons.build_circle_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: palette.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Quick suggestion chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: suggestions.map((s) {
                final isSelected = _titleController.text == s;
                return ActionChip(
                  label: Text(
                    s,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? AppColors.primaryDark : palette.text,
                    ),
                  ),
                  backgroundColor: isSelected
                      ? AppColors.mint.withValues(alpha: 0.4)
                      : palette.surface,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : palette.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      _titleController.text = s;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Job Notes / Description
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: palette.text),
              decoration: InputDecoration(
                labelText: 'Job Details & Notes (Optional)',
                hintText:
                    'Describe the problem, materials required, or special instructions...',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 34),
                  child: Icon(
                    Icons.notes_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: palette.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Section 2: Preferred Date & Time
            Text(
              '2. Preferred Date & Time',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 10),

            // Schedule preview pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.mint),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Arrival',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          schedulePreview,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Date & Time Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 10,
                      ),
                      backgroundColor: palette.surface,
                      side: BorderSide(color: palette.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      _formatTime(_selectedTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 10,
                      ),
                      backgroundColor: palette.surface,
                      side: BorderSide(color: palette.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                      );
                      if (picked != null) {
                        setState(() => _selectedTime = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick Slots
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildQuickSlotChip(
                  label: 'Tomorrow 9:00 AM',
                  isSelected:
                      _selectedDate.day ==
                          DateTime.now().add(const Duration(days: 1)).day &&
                      _selectedTime.hour == 9,
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime.now().add(
                        const Duration(days: 1),
                      );
                      _selectedTime = const TimeOfDay(hour: 9, minute: 0);
                    });
                  },
                  palette: palette,
                ),
                _buildQuickSlotChip(
                  label: 'Tomorrow 2:00 PM',
                  isSelected:
                      _selectedDate.day ==
                          DateTime.now().add(const Duration(days: 1)).day &&
                      _selectedTime.hour == 14,
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime.now().add(
                        const Duration(days: 1),
                      );
                      _selectedTime = const TimeOfDay(hour: 14, minute: 0);
                    });
                  },
                  palette: palette,
                ),
                _buildQuickSlotChip(
                  label: 'Today 5:00 PM',
                  isSelected:
                      _selectedDate.day == DateTime.now().day &&
                      _selectedTime.hour == 17,
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                      _selectedTime = const TimeOfDay(hour: 17, minute: 0);
                    });
                  },
                  palette: palette,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Section 3: Service Location
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '3. Service Location',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _isLocatingGps ? null : _useCurrentGpsLocation,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isLocatingGps)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            else
                              const Icon(
                                Icons.my_location_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                            const SizedBox(width: 4),
                            const Text(
                              'Use GPS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _pickLocationOnMap,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 13,
                              color: AppColors.primaryDark,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pick on Map',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Embedded Mini Map Preview Card
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _selectedLocation?.latitude ?? 6.9271,
                        _selectedLocation?.longitude ?? 79.8612,
                      ),
                      zoom: 15,
                    ),
                    onMapCreated: (ctrl) {
                      _miniMapController = ctrl;
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('service_location_pin'),
                        position: LatLng(
                          _selectedLocation?.latitude ?? 6.9271,
                          _selectedLocation?.longitude ?? 79.8612,
                        ),
                        infoWindow: InfoWindow(
                          title: 'Service Location',
                          snippet:
                              _selectedLocation?.shortName ?? 'Target Location',
                        ),
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                  ),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: _pickLocationOnMap),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Tap to adjust pin',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _locationController,
              onChanged: _onLocationChanged,
              style: TextStyle(fontSize: 14, color: palette.text),
              decoration: InputDecoration(
                labelText: 'Address or Area',
                hintText: 'e.g. 45/2 Havelock Road, Colombo 05',
                prefixIcon: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingLocationSuggestions)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    else if (_locationController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _locationController.clear();
                          _onLocationChanged('');
                        },
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_location_alt_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      tooltip: 'Pick on Google Map',
                      onPressed: _pickLocationOnMap,
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: palette.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            // Floating Suggestions Dropdown
            if (_showLocationDropdown && _locationSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _locationSuggestions.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 1,
                    color: palette.border.withValues(alpha: 0.5),
                    indent: 48,
                  ),
                  itemBuilder: (context, index) {
                    final item = _locationSuggestions[index];
                    return InkWell(
                      onTap: () => _selectLocationSuggestion(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.shortName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: palette.text,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.address,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.muted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.north_west_rounded,
                              size: 14,
                              color: palette.muted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 22),

            // Section 4: Proposed Price & Rate Type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '4. Proposed Rate / Price',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
                Text(
                  'Specialist: Rs. ${provider.hourlyRate.toInt()}/hr',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Rate Type Toggle
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Hourly Rate (Rs./hr)')),
                    selected: isHourly,
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isHourly ? FontWeight.w700 : FontWeight.w500,
                      color: isHourly ? AppColors.primaryDark : palette.text,
                    ),
                    side: BorderSide(
                      color: isHourly ? AppColors.primary : palette.border,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _rateType = 'Hourly');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Fixed Total (Rs.)')),
                    selected: !isHourly,
                    selectedColor: AppColors.primaryLight,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: !isHourly ? FontWeight.w700 : FontWeight.w500,
                      color: !isHourly ? AppColors.primaryDark : palette.text,
                    ),
                    side: BorderSide(
                      color: !isHourly ? AppColors.primary : palette.border,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _rateType = 'Fixed');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Price Input
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
              decoration: InputDecoration(
                labelText: isHourly
                    ? 'Your Offered Hourly Rate'
                    : 'Your Proposed Fixed Budget',
                prefixText: 'Rs. ',
                suffixText: isHourly ? ' / hr' : ' total',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: palette.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Quick price adjustment chips
            Row(
              children: [
                ActionChip(
                  label: const Text(
                    '- Rs. 200',
                    style: TextStyle(fontSize: 11),
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final current =
                        double.tryParse(_priceController.text) ??
                        provider.hourlyRate;
                    final updated = (current - 200).clamp(500, 100000);
                    setState(() {
                      _priceController.text = updated.toInt().toString();
                    });
                  },
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text(
                    '+ Rs. 200',
                    style: TextStyle(fontSize: 11),
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    final current =
                        double.tryParse(_priceController.text) ??
                        provider.hourlyRate;
                    final updated = current + 200;
                    setState(() {
                      _priceController.text = updated.toInt().toString();
                    });
                  },
                ),
                const SizedBox(width: 6),
                ActionChip(
                  label: Text(
                    'Reset (Rs. ${provider.hourlyRate.toInt()})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _priceController.text = provider.hourlyRate
                          .toInt()
                          .toString();
                    });
                  },
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: palette.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _onSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Send Proposal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

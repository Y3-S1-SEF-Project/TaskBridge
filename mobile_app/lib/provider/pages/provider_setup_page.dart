import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/widgets/auth_input.dart';
import '../../auth/widgets/auth_layout.dart';
import '../../core/services/location_service.dart';
import '../../core/services/user_mode_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/design_system.dart';
import '../../home/pages/location_picker_page.dart';
import 'provider_main_page.dart';

class PredefinedServiceCategory {
  final String categoryName;
  final IconData icon;
  final List<String> services;

  const PredefinedServiceCategory({
    required this.categoryName,
    required this.icon,
    required this.services,
  });
}

const List<PredefinedServiceCategory> kPredefinedServiceCategories = [
  PredefinedServiceCategory(
    categoryName: 'Plumbing',
    icon: AppIcons.plumbing,
    services: [
      'Tap & Faucet Repair',
      'Pipe Leak Detection & Repair',
      'Drain Unblocking & Cleaning',
      'Water Heater Installation & Repair',
      'Toilet & Flush Repair',
      'Bathroom Fitting & Renovation',
      'Water Pump Servicing',
      'Overhead Tank Cleaning',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Electrical',
    icon: AppIcons.electrical,
    services: [
      'Wiring & Short Circuit Repair',
      'Switch, Socket & Plug Installation',
      'Ceiling Fan Repair & Mounting',
      'Light Fixture & Chandelier Installation',
      'Circuit Breaker (MCB) Replacement',
      'Generator Maintenance',
      'Solar Panel Maintenance',
      'Inverter & Battery Backup Setup',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Air Conditioning & HVAC',
    icon: AppIcons.hvac,
    services: [
      'AC General Servicing & Filter Cleaning',
      'AC Gas Leak & Refill',
      'AC Installation & Uninstallation',
      'AC Compressor & Cooling Repair',
      'HVAC Duct Cleaning & Maintenance',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Cleaning & Housekeeping',
    icon: AppIcons.cleaning,
    services: [
      'Full Home Deep Cleaning',
      'Sofa & Carpet Shampooing',
      'Kitchen Deep Degreasing',
      'Bathroom Scrubbing & Sanitization',
      'Window & Glass Cleaning',
      'Post-Construction Cleanup',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Painting & Waterproofing',
    icon: AppIcons.painting,
    services: [
      'Interior Wall Painting',
      'Exterior Weatherproof Painting',
      'Roof & Terrace Waterproofing',
      'Wall Putty & Plaster Repair',
      'Wood Varnish & Metal Enamel',
      'Wallpaper Installation',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Carpentry & Woodwork',
    icon: AppIcons.carpentry,
    services: [
      'Furniture Assembly & Repair',
      'Door & Window Frame Fixing',
      'Door Lock & Handle Replacement',
      'Custom Wardrobe & Kitchen Cabinets',
      'Wooden Floor & Deck Repair',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Appliance Repair',
    icon: AppIcons.appliances,
    services: [
      'Refrigerator & Freezer Repair',
      'Washing Machine & Dryer Repair',
      'Microwave & Oven Servicing',
      'TV Wall Mounting & Repair',
      'Gas Stove & Hob Servicing',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Vehicle & Roadside',
    icon: AppIcons.carRepair,
    services: [
      'Mobile Auto Inspection & Diagnostics',
      'Car Battery Jumpstart & Replacement',
      'Tire Puncture Repair & Replacement',
      'Engine Oil & Fluid Service',
      'Emergency Roadside Assistance',
      'Mobile Car Detailing & Wash',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'IT & Security',
    icon: AppIcons.itServices,
    services: [
      'CCTV Camera Installation & Repair',
      'Home Wi-Fi & Network Setup',
      'PC, Mac & Laptop Repair',
      'Smart Doorbell & Security Locks',
      'Printer & Peripheral Setup',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Gardening & Outdoor',
    icon: AppIcons.gardening,
    services: [
      'Lawn Mowing & Grass Trimming',
      'Garden Landscaping & Design',
      'Tree Cutting & Pruning',
      'Weed Control & Fertilization',
      'Outdoor Pressure Washing',
    ],
  ),
];

class ProviderSetupPage extends StatefulWidget {
  final AuthUser user;
  final AuthApi api;
  final bool? isFirstTime;

  const ProviderSetupPage({
    super.key,
    required this.user,
    required this.api,
    this.isFirstTime,
  });

  @override
  State<ProviderSetupPage> createState() => _ProviderSetupPageState();
}

class _ProviderSetupPageState extends State<ProviderSetupPage> {
  late final TextEditingController _skillsController;
  late final TextEditingController _experienceController;
  late final TextEditingController _availabilityController;
  late final TextEditingController _bioController;
  late final TextEditingController _hourlyRateController;

  String? _selectedCategory;
  final List<String> _selectedServices = [];
  UserLocation? _providerLocation;
  int _selectedRadiusKm = 15;
  GoogleMapController? _miniMapController;

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  String _selectedDays = 'Mon–Sat';

  final ImagePicker _picker = ImagePicker();
  String? _certificationUrl;
  String? _certFileName;
  bool _uploadingCert = false;
  bool _busy = false;
  String? _error;

  String? _detectCategoryFromServices(Iterable<String> services) {
    if (services.isEmpty) return null;
    for (final cat in kPredefinedServiceCategories) {
      for (final s in services) {
        if (cat.services.any(
          (cs) =>
              cs.toLowerCase().contains(s.toLowerCase()) ||
              s.toLowerCase().contains(cs.toLowerCase()),
        )) {
          return cat.categoryName;
        }
      }
    }
    return null;
  }

  bool get _isExistingProvider {
    if (widget.isFirstTime != null) {
      return !widget.isFirstTime!;
    }
    if (widget.user.isProvider) return true;
    final skills = widget.user.providerSkills?.trim() ?? '';
    final services = widget.user.providerServices?.trim() ?? '';
    return skills.isNotEmpty || services.isNotEmpty;
  }

  bool get _showDoLater => !_isExistingProvider;

  @override
  void initState() {
    super.initState();

    String cleanMock(String? val, List<String> mocks) {
      if (val == null) return '';
      final trimmed = val.trim();
      if (trimmed.isEmpty) return '';
      for (final m in mocks) {
        if (trimmed == m || trimmed.contains(m)) return '';
      }
      return trimmed;
    }

    _skillsController = TextEditingController(
      text: cleanMock(widget.user.providerSkills, [
        'Plumbing',
        'Plumbing · Leak detection',
      ]),
    );
    _experienceController = TextEditingController(
      text: cleanMock(widget.user.providerExperience, ['8 years']),
    );

    final availabilityRaw = cleanMock(widget.user.providerAvailability, [
      'Mon–Sat · 8 AM–6 PM',
    ]);
    _initAvailability(availabilityRaw);
    _availabilityController = TextEditingController(
      text: _formatAvailabilityString(),
    );

    _bioController = TextEditingController(
      text: cleanMock(widget.user.providerBio, [
        'Experienced plumbing & leak detection professional.',
        'Experienced plumbing & leak detection professional',
      ]),
    );

    final initialRate =
        widget.user.providerHourlyRate != null &&
            widget.user.providerHourlyRate! > 0
        ? widget.user.providerHourlyRate!.toInt().toString()
        : '2500';
    _hourlyRateController = TextEditingController(text: initialRate);

    // Populate selected services
    final servicesRaw = cleanMock(widget.user.providerServices, [
      'Tap repair',
      'Tap repair · Pipe replacement',
    ]);
    if (servicesRaw.isNotEmpty) {
      final parsed = servicesRaw
          .split(RegExp(r'[,·]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      _selectedServices.addAll(parsed.toSet());
    }

    // Populate primary category
    _selectedCategory = widget.user.providerCategory;
    if (_selectedCategory == null || _selectedCategory!.trim().isEmpty) {
      _selectedCategory = _detectCategoryFromServices(_selectedServices);
    }

    // Populate location & radius
    final areasRaw = cleanMock(widget.user.providerServiceAreas, [
      'Colombo and Nugegoda',
      'Colombo 03, 04, 05, 06',
    ]);
    final matchRadius = RegExp(
      r'Within\s+(\d+)\s*km',
      caseSensitive: false,
    ).firstMatch(areasRaw);
    if (matchRadius != null) {
      _selectedRadiusKm = int.tryParse(matchRadius.group(1) ?? '') ?? 15;
    }

    if (widget.user.location != null &&
        widget.user.location!.trim().isNotEmpty) {
      final locText = widget.user.location!.trim();
      _providerLocation = UserLocation(
        shortName: locText.split(',').first.trim(),
        address: locText,
        latitude: 6.9271,
        longitude: 79.8612,
      );
    } else if (areasRaw.isNotEmpty) {
      final cleanName = areasRaw
          .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false), '')
          .trim();
      if (cleanName.isNotEmpty) {
        _providerLocation = UserLocation(
          shortName: cleanName.split(',').first.trim(),
          address: cleanName,
          latitude: 6.9271,
          longitude: 79.8612,
        );
      }
    }

    _certificationUrl = widget.user.providerCertifications;
    if (_certificationUrl != null && _certificationUrl!.isNotEmpty) {
      final uri = Uri.tryParse(_certificationUrl!);
      _certFileName = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : 'Certificate document';
    }

    _loadDefaultLocationIfNeeded();
  }

  Future<void> _loadDefaultLocationIfNeeded() async {
    if (_providerLocation != null) return;
    try {
      final cached = await LocationService.getSavedLocation();
      if (cached != null && mounted && _providerLocation == null) {
        setState(() => _providerLocation = cached);
        _syncMiniMapCamera();
      } else if (mounted && _providerLocation == null) {
        setState(() => _providerLocation = UserLocation.defaultLocation);
        _syncMiniMapCamera();
      }
    } catch (_) {
      if (mounted && _providerLocation == null) {
        setState(() => _providerLocation = UserLocation.defaultLocation);
        _syncMiniMapCamera();
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatAvailabilityString() {
    return '$_selectedDays · ${_formatTimeOfDay(_startTime)} – ${_formatTimeOfDay(_endTime)}';
  }

  void _updateAvailabilityText() {
    _availabilityController.text = _formatAvailabilityString();
  }

  void _initAvailability(String raw) {
    if (raw.trim().isEmpty) return;
    final text = raw.trim();
    if (text.contains('Mon–Fri') || text.contains('Mon-Fri')) {
      _selectedDays = 'Mon–Fri';
    } else if (text.contains('Everyday') ||
        text.contains('All Week') ||
        text.contains('Mon–Sun')) {
      _selectedDays = 'Everyday';
    } else if (text.contains('Weekend')) {
      _selectedDays = 'Weekends';
    } else {
      _selectedDays = 'Mon–Sat';
    }
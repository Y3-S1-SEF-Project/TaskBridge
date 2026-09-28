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

    final timeRegex = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:-|–|to)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
      caseSensitive: false,
    );
    final match = timeRegex.firstMatch(text);
    if (match != null) {
      int startH = int.tryParse(match.group(1) ?? '') ?? 8;
      int startM = int.tryParse(match.group(2) ?? '') ?? 0;
      final startPeriod = match.group(3)?.toLowerCase();

      int endH = int.tryParse(match.group(4) ?? '') ?? 18;
      int endM = int.tryParse(match.group(5) ?? '') ?? 0;
      final endPeriod = match.group(6)?.toLowerCase();

      if (startPeriod == 'pm' && startH < 12) startH += 12;
      if (startPeriod == 'am' && startH == 12) startH = 0;

      if (endPeriod == 'pm' && endH < 12) endH += 12;
      if (endPeriod == 'am' && endH == 12) endH = 0;
      if (endPeriod == null && endH <= 12 && startH <= 12) {
        if (endH < startH || endH <= 7) endH += 12;
      }

      _startTime = TimeOfDay(
        hour: startH.clamp(0, 23),
        minute: startM.clamp(0, 59),
      );
      _endTime = TimeOfDay(hour: endH.clamp(0, 23), minute: endM.clamp(0, 59));
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _updateAvailabilityText();
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _updateAvailabilityText();
      });
    }
  }

   @override
  void dispose() {
    _miniMapController?.dispose();
    _skillsController.dispose();
    _experienceController.dispose();
    _availabilityController.dispose();
    _bioController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted || status.isLimited;
    } else {
      PermissionStatus status;
      if (Platform.isAndroid) {
        status = await Permission.photos.request();
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }
      return status.isGranted || status.isLimited;
    }
  }

  Future<void> _pickAndUploadCert() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload Certification / Document',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Upload PDF or Document',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'PDF, DOC, DOCX up to 10MB',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _processDocUpload();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Choose photo from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'JPG, PNG, WEBP',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final allowed = await _ensurePermission(ImageSource.gallery);
                  if (!allowed) return;
                  _processCertUpload(ImageSource.gallery);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Take photo of certificate',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Use camera to capture paper document',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final allowed = await _ensurePermission(ImageSource.camera);
                  if (!allowed) return;
                  _processCertUpload(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processDocUpload() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );
      if (files.isEmpty) return;
      final file = files.first;
      final path = file.path;
      if (path == null) return;

      setState(() {
        _uploadingCert = true;
        _certFileName = file.name;
      });

      final updated = await widget.api.uploadCertification(
        path,
        userId: widget.user.id,
      );

      if (mounted) {
        setState(() {
          _certificationUrl = updated.providerCertifications;
          _uploadingCert = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "${file.name}" uploaded successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingCert = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _processCertUpload(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1500,
        maxHeight: 1500,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _uploadingCert = true;
        _certFileName = picked.name;
      });

      final updated = await widget.api.uploadCertification(
        picked.path,
        userId: widget.user.id,
      );

      if (mounted) {
        setState(() {
          _certificationUrl = updated.providerCertifications;
          _uploadingCert = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certification photo uploaded successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingCert = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload certification: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  double _getZoomForRadius(int radiusKm) {
    switch (radiusKm) {
      case 5:
        return 12.0;
      case 10:
        return 11.0;
      case 15:
        return 10.3;
      case 25:
        return 9.4;
      case 50:
        return 8.4;
      default:
        return 10.3;
    }
  }

  void _onRadiusSelected(int radius) {
    setState(() => _selectedRadiusKm = radius);
    _syncMiniMapCamera();
  }

  void _syncMiniMapCamera() {
    if (_miniMapController != null && _providerLocation != null) {
      _miniMapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _providerLocation!.latitude,
              _providerLocation!.longitude,
            ),
            zoom: _getZoomForRadius(_selectedRadiusKm),
          ),
        ),
      );
    }
  }

  Future<void> _pickLocationOnGoogleMaps() async {
    final selected = await Navigator.push<UserLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocation: _providerLocation ?? UserLocation.defaultLocation,
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _providerLocation = selected;
      });
      _syncMiniMapCamera();
    }
  }

  void _openCustomCategoryDialog(BuildContext sheetCtx) {
    final textController = TextEditingController(
      text:
          kPredefinedServiceCategories.any(
            (c) => c.categoryName == _selectedCategory,
          )
          ? ''
          : (_selectedCategory ?? ''),
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Custom Category',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your trade or service category:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Masonry, Locksmith, Pest Control…',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () {
              final customVal = textController.text.trim();
              if (customVal.isNotEmpty) {
                setState(() {
                  _selectedCategory = customVal;
                });
                Navigator.pop(dialogCtx);
                Navigator.pop(sheetCtx);
              }
            },
            child: const Text(
              'Confirm',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _openCategoryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Select Primary Category',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose the main category that best represents your trade.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: kPredefinedServiceCategories.length + 1,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      // Custom "Other" option at the end
                      if (index == kPredefinedServiceCategories.length) {
                        final isCustom =
                            _selectedCategory != null &&
                            _selectedCategory!.trim().isNotEmpty &&
                            !kPredefinedServiceCategories.any(
                              (c) =>
                                  c.categoryName.toLowerCase() ==
                                  _selectedCategory!.toLowerCase(),
                            );

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCustom
                                  ? AppColors.primary
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_circle_outline_rounded,
                              size: 18,
                              color: isCustom
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                          title: Text(
                            isCustom
                                ? 'Other: $_selectedCategory'
                                : 'Other (Add custom category)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCustom
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isCustom
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: isCustom
                              ? const Text(
                                  'Tap to change custom category',
                                  style: TextStyle(fontSize: 12),
                                )
                              : null,
                          trailing: isCustom
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
                                ),
                          onTap: () => _openCustomCategoryDialog(ctx),
                        );
                      }

                      final cat = kPredefinedServiceCategories[index];
                      final isSelected =
                          _selectedCategory != null &&
                          _selectedCategory!.toLowerCase() ==
                              cat.categoryName.toLowerCase();
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            cat.icon,
                            size: 18,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          cat.categoryName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat.categoryName;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openServiceSelectionSheet() {
    final tempSelected = Set<String>.from(_selectedServices);
    String searchQuery = '';
    String? selectedCategoryFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchQuery.trim().toLowerCase();

            // Filter categories and services
            final visibleCategories = kPredefinedServiceCategories.where((cat) {
              if (selectedCategoryFilter != null &&
                  cat.categoryName != selectedCategoryFilter) {
                return false;
              }
              if (query.isEmpty) return true;
              return cat.categoryName.toLowerCase().contains(query) ||
                  cat.services.any((s) => s.toLowerCase().contains(query));
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.82,
              minChildSize: 0.5,
              maxChildSize: 0.94,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Sheet Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Select Services You Provide',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${tempSelected.length} service${tempSelected.length == 1 ? '' : 's'} selected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tempSelected.isNotEmpty
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (tempSelected.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setSheetState(() => tempSelected.clear());
                              },
                              child: const Text(
                                'Clear all',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Search Field
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: 'Search plumbing, AC, wiring, cleaning…',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setSheetState(() => searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setSheetState(() => searchQuery = val);
                        },
                      ),
                    ),

                    // Category Filter Pills
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: const Text('All Categories'),
                              selected: selectedCategoryFilter == null,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selectedCategoryFilter == null
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: selectedCategoryFilter == null
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              onSelected: (_) {
                                setSheetState(
                                  () => selectedCategoryFilter = null,
                                );
                              },
                            ),
                          ),
                          ...kPredefinedServiceCategories.map((cat) {
                            final isSel =
                                selectedCategoryFilter == cat.categoryName;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(cat.categoryName),
                                selected: isSel,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSel
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isSel
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                onSelected: (_) {
                                  setSheetState(() {
                                    selectedCategoryFilter = isSel
                                        ? null
                                        : cat.categoryName;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const Divider(height: 12),

                    // Services List
                    Expanded(
                      child: visibleCategories.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.search_off_rounded,
                                      size: 48,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No services found for "$searchQuery"',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        final customName = searchQuery.trim();
                                        if (customName.isNotEmpty) {
                                          setSheetState(() {
                                            tempSelected.add(customName);
                                            searchQuery = '';
                                          });
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        'Add "$searchQuery" as Custom Service',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: visibleCategories.length,
                              itemBuilder: (context, catIndex) {
                                final cat = visibleCategories[catIndex];
                                final services = cat.services.where((s) {
                                  if (query.isEmpty) return true;
                                  return s.toLowerCase().contains(query);
                                }).toList();

                                if (services.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Category Header
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  cat.icon,
                                                  size: 16,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                cat.categoryName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1),

                                        // Category Services
                                        ...services.map((service) {
                                          final isChecked = tempSelected
                                              .contains(service);
                                          return InkWell(
                                            onTap: () {
                                              setSheetState(() {
                                                if (isChecked) {
                                                  tempSelected.remove(service);
                                                } else {
                                                  tempSelected.add(service);
                                                }
                                              });
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 10,
                                                  ),
                                              child: Row(
                                                children: [
                                                  AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 180,
                                                    ),
                                                    width: 22,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                      color: isChecked
                                                          ? AppColors.primary
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: isChecked
                                                            ? AppColors.primary
                                                            : AppColors.border,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    child: isChecked
                                                        ? const Icon(
                                                            Icons.check_rounded,
                                                            size: 16,
                                                            color: Colors.white,
                                                          )
                                                        : null,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      service,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: isChecked
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                        color: isChecked
                                                            ? AppColors
                                                                  .textPrimary
                                                            : AppColors
                                                                  .textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Bottom Confirm Button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            offset: const Offset(0, -3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedServices.clear();
                                _selectedServices.addAll(tempSelected);
                                if (selectedCategoryFilter != null) {
                                  _selectedCategory = selectedCategoryFilter;
                                } else if (_selectedCategory == null ||
                                    _selectedCategory!.isEmpty) {
                                  _selectedCategory =
                                      _detectCategoryFromServices(
                                        _selectedServices,
                                      );
                                }
                                if (_skillsController.text.trim().isEmpty &&
                                    _selectedServices.isNotEmpty) {
                                  _skillsController.text = _selectedServices
                                      .take(2)
                                      .join(' · ');
                                }
                              });
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              tempSelected.isEmpty
                                  ? 'Done'
                                  : 'Done (${tempSelected.length} Selected)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _skipAndEnterProviderMode() async {
    setState(() => _busy = true);
    try {
      final servicesString = _selectedServices.isNotEmpty
          ? _selectedServices.join(', ')
          : widget.user.providerServices;
      final serviceAreasString = _providerLocation != null
          ? '${_providerLocation!.shortName} (Within $_selectedRadiusKm km)'
          : widget.user.providerServiceAreas;

      final updated = await widget.api.saveProviderProfile(
        category: _selectedCategory ?? widget.user.providerCategory,
        skills: widget.user.providerSkills,
        services: servicesString,
        experience: widget.user.providerExperience,
        serviceAreas: serviceAreasString,
        availability: widget.user.providerAvailability,
        bio: widget.user.providerBio,
        location: _providerLocation?.address ?? _providerLocation?.shortName,
        hourlyRate: widget.user.providerHourlyRate ?? 2500.0,
      );

      await UserModeService.setMode(UserMode.provider);
      if (!mounted) return;
      if (widget.user.isProvider && Navigator.canPop(context)) {
        Navigator.pop(context, updated);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderMainPage(user: updated, api: widget.api),
          ),
        );
      }
    } catch (e) {
      await UserModeService.setMode(UserMode.provider);
      final fallbackUser = widget.user.copyWith(isProvider: true);
      if (!mounted) return;
      if (widget.user.isProvider && Navigator.canPop(context)) {
        Navigator.pop(context, fallbackUser);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProviderMainPage(user: fallbackUser, api: widget.api),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

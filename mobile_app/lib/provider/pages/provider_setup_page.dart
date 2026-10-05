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
import '../../core/theme/app_palette.dart';
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
  AppPalette get palette => AppPalette.of(context);
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
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: palette.primary,
              onPrimary: palette.onPrimary,
              surface: palette.surface,
              onSurface: palette.textPrimary,
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
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: palette.primary,
              onPrimary: palette.onPrimary,
              surface: palette.surface,
              onSurface: palette.textPrimary,
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
      backgroundColor: palette.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Upload Certification / Document',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: palette.primaryLight,
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    color: palette.primary,
                  ),
                ),
                title: const Text(
                  'Upload PDF or Document',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'PDF, DOC, DOCX up to 10MB',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _processDocUpload();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: palette.primaryLight,
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: palette.primary,
                  ),
                ),
                title: const Text(
                  'Choose photo from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'JPG, PNG, WEBP',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
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
                leading: CircleAvatar(
                  backgroundColor: palette.primaryLight,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: palette.primary,
                  ),
                ),
                title: const Text(
                  'Take photo of certificate',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Use camera to capture paper document',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
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
            backgroundColor: palette.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingCert = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload document: $e'),
            backgroundColor: palette.error,
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
          SnackBar(
            content: Text('Certification photo uploaded successfully!'),
            backgroundColor: palette.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingCert = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload certification: $e'),
            backgroundColor: palette.error,
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
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Custom Category',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your trade or service category:',
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Masonry, Locksmith, Pest Control…',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: palette.textSecondary,
                ),
                filled: true,
                fillColor: palette.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: TextStyle(color: palette.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
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
      backgroundColor: palette.surface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Select Primary Category',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the main category that best represents your trade.',
                  style: TextStyle(fontSize: 13, color: palette.textSecondary),
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
                                  ? palette.primary
                                  : palette.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_circle_outline_rounded,
                              size: 18,
                              color: isCustom ? Colors.white : palette.primary,
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
                                  ? palette.primary
                                  : palette.textPrimary,
                            ),
                          ),
                          subtitle: isCustom
                              ? const Text(
                                  'Tap to change custom category',
                                  style: TextStyle(fontSize: 12),
                                )
                              : null,
                          trailing: isCustom
                              ? Icon(Icons.check_circle, color: palette.primary)
                              : Icon(
                                  Icons.chevron_right_rounded,
                                  color: palette.textSecondary,
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
                                ? palette.primary
                                : palette.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            cat.icon,
                            size: 18,
                            color: isSelected ? Colors.white : palette.primary,
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
                                ? palette.primary
                                : palette.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: palette.primary)
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
      backgroundColor: palette.surface,
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
                                Text(
                                  'Select Services You Provide',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${tempSelected.length} service${tempSelected.length == 1 ? '' : 's'} selected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: tempSelected.isNotEmpty
                                        ? palette.primary
                                        : palette.textSecondary,
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
                              child: Text(
                                'Clear all',
                                style: TextStyle(
                                  color: palette.error,
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
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: palette.textSecondary,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: palette.textSecondary,
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
                          fillColor: palette.background,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: palette.primary,
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
                                    : palette.textPrimary,
                              ),
                              selectedColor: palette.primary,
                              backgroundColor: palette.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: selectedCategoryFilter == null
                                      ? palette.primary
                                      : palette.border,
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
                                      : palette.textPrimary,
                                ),
                                selectedColor: palette.primary,
                                backgroundColor: palette.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isSel
                                        ? palette.primary
                                        : palette.border,
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
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 48,
                                      color: palette.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No services found for "$searchQuery"',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: palette.textPrimary,
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
                                        backgroundColor: palette.primary,
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
                                      color: palette.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: palette.border),
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
                                                  color: palette.primaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  cat.icon,
                                                  size: 16,
                                                  color: palette.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                cat.categoryName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: palette.textPrimary,
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
                                                          ? palette.primary
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: isChecked
                                                            ? palette.primary
                                                            : palette.border,
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
                              backgroundColor: palette.primary,
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

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final servicesString = _selectedServices.join(', ');
      final serviceAreasString = _providerLocation != null
          ? '${_providerLocation!.shortName} (Within $_selectedRadiusKm km)'
          : 'Within $_selectedRadiusKm km';

      final skillsText = _skillsController.text.trim().isNotEmpty
          ? _skillsController.text.trim()
          : (_selectedServices.isNotEmpty
                ? _selectedServices.first
                : 'Specialist');

      final cleanRate = _hourlyRateController.text
          .replaceAll(',', '')
          .replaceAll('Rs.', '')
          .replaceAll('LKR', '')
          .trim();
      final parsedRate =
          double.tryParse(cleanRate) ??
          (widget.user.providerHourlyRate ?? 2500.0);

      final updated = await widget.api.saveProviderProfile(
        category: _selectedCategory,
        skills: skillsText,
        services: servicesString,
        experience: _experienceController.text.trim(),
        certifications: _certificationUrl,
        serviceAreas: serviceAreasString,
        availability: _availabilityController.text.trim(),
        bio: _bioController.text.trim(),
        location: _providerLocation?.address ?? _providerLocation?.shortName,
        hourlyRate: parsedRate,
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
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: AppSpacing.s16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Top Tag Row with "Do Later" ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isExistingProvider
                                  ? 'EDIT PROVIDER PROFILE'
                                  : 'YOUR EXPERTISE, YOUR OPPORTUNITY',
                              style: TextStyle(
                                color: palette.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            if (_showDoLater)
                              GestureDetector(
                                onTap: _skipAndEnterProviderMode,
                                child: Text(
                                  'DO LATER',
                                  style: TextStyle(
                                    color: palette.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s4),

                        // ── Title Row with Back Arrow ──
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _isExistingProvider
                                    ? 'Edit your provider\nprofile'
                                    : 'Set up your provider\nprofile',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: palette.textPrimary,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(AppIcons.arrowLeft),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // ── 0. Primary Trade Category ──
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Primary Trade Category',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _busy ? null : _openCategoryPicker,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _selectedCategory != null
                                        ? palette.primary
                                        : palette.border,
                                    width: _selectedCategory != null
                                        ? 1.5
                                        : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      color: _selectedCategory != null
                                          ? palette.primary
                                          : palette.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedCategory ??
                                            'Select your primary trade category',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: _selectedCategory != null
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                          color: _selectedCategory != null
                                              ? palette.textPrimary
                                              : palette.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: palette.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // ── 1. Skills Field ──
                        AuthInput(
                          label: 'Primary Skills',
                          hint: 'e.g. Plumbing, Leak Detection, Home Repairs',
                          controller: _skillsController,
                          enabled: !_busy,
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // ── 2. Services I Provide Section ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Services I Provide',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    if (_selectedServices.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '${_selectedServices.length}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: palette.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Choose all tasks you are qualified to do',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _openServiceSelectionSheet,
                              style: TextButton.styleFrom(
                                foregroundColor: palette.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: palette.primary,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text(
                                'Add Service',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Selected Services Chips or Empty State
                        if (_selectedServices.isEmpty)
                          GestureDetector(
                            onTap: _openServiceSelectionSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: palette.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: palette.primary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tap "+ Add Service" to select services',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: palette.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedServices.map((service) {
                              return Container(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  top: 6,
                                  bottom: 6,
                                  right: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.primaryLight.withValues(
                                    alpha: 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: palette.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      service,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedServices.remove(service);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: palette.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: palette.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: AppSpacing.s20),

                        // ── 3. Provider Location & Coverage ──
                        Text(
                          'Provider Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your primary working location on Google Maps',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Google Maps Location Card with Embedded Live Mini Map
                        Container(
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top info bar with location details & Change button
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: palette.primaryLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.location_on_rounded,
                                        color: palette.primary,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _providerLocation?.shortName ??
                                                'Select Base Location',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: palette.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _providerLocation?.address ??
                                                'Tap to pick on Google Maps',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: palette.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: _pickLocationOnGoogleMaps,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.map_rounded,
                                              size: 14,
                                              color: palette.primary,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Change',
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
                                  ],
                                ),
                              ),

                              // Real Embedded Mini Map with dynamic service radius circle
                              SizedBox(
                                height: 180,
                                child: Stack(
                                  children: [
                                    GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(
                                          _providerLocation?.latitude ?? 6.9271,
                                          _providerLocation?.longitude ??
                                              79.8612,
                                        ),
                                        zoom: _getZoomForRadius(
                                          _selectedRadiusKm,
                                        ),
                                      ),
                                      onMapCreated: (controller) {
                                        _miniMapController = controller;
                                      },
                                      circles: {
                                        if (_providerLocation != null)
                                          Circle(
                                            circleId: const CircleId(
                                              'provider_radius_circle',
                                            ),
                                            center: LatLng(
                                              _providerLocation!.latitude,
                                              _providerLocation!.longitude,
                                            ),
                                            radius: _selectedRadiusKm * 1000.0,
                                            fillColor: palette.primary
                                                .withValues(alpha: 0.18),
                                            strokeColor: palette.primary,
                                            strokeWidth: 2,
                                          ),
                                      },
                                      markers: {
                                        if (_providerLocation != null)
                                          Marker(
                                            markerId: const MarkerId(
                                              'provider_marker',
                                            ),
                                            position: LatLng(
                                              _providerLocation!.latitude,
                                              _providerLocation!.longitude,
                                            ),
                                            infoWindow: InfoWindow(
                                              title:
                                                  _providerLocation!.shortName,
                                              snippet:
                                                  'Coverage: $_selectedRadiusKm km',
                                            ),
                                          ),
                                      },
                                      zoomControlsEnabled: false,
                                      myLocationButtonEnabled: false,
                                      compassEnabled: false,
                                      mapToolbarEnabled: false,
                                      tiltGesturesEnabled: false,
                                      rotateGesturesEnabled: false,
                                    ),

                                    // Floating Radius Badge on Map
                                    Positioned(
                                      top: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.surface.withValues(
                                            alpha: 0.94,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 4,
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
                                            const SizedBox(width: 4),
                                            Text(
                                              '$_selectedRadiusKm km Radius',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: palette.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Floating "Full Map" Button on Map
                                    Positioned(
                                      bottom: 10,
                                      right: 10,
                                      child: InkWell(
                                        onTap: _pickLocationOnGoogleMaps,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: palette.surface,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.15,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.fullscreen_rounded,
                                                size: 16,
                                                color: palette.primary,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Full Map',
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
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Service Radius Selector
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Service Radius',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Within $_selectedRadiusKm km',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: palette.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [5, 10, 15, 25, 50].map((radius) {
                                final isSelected = _selectedRadiusKm == radius;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: InkWell(
                                      onTap: () => _onRadiusSelected(radius),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 9,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? palette.primary
                                              : palette.surface,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? palette.primary
                                                : palette.border,
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          '$radius km',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : palette.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: palette.primaryLight.withValues(
                                  alpha: 0.4,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.radar_rounded,
                                    size: 16,
                                    color: palette.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Receiving tasks within $_selectedRadiusKm km of ${_providerLocation?.shortName ?? "your location"}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: palette.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // ── 4. Experience Field ──
                        AuthInput(
                          label: 'Experience (years)',
                          hint: 'e.g. 5',
                          controller: _experienceController,
                          enabled: !_busy,
                        ),

                        // ── 5. Upload Certifications Card ──
                        InkWell(
                          onTap: _uploadingCert ? null : _pickAndUploadCert,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  _certificationUrl != null &&
                                      _certificationUrl!.isNotEmpty
                                  ? palette.primaryLight.withValues(alpha: 0.3)
                                  : palette.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    _certificationUrl != null &&
                                        _certificationUrl!.isNotEmpty
                                    ? palette.primary
                                    : palette.border,
                                width:
                                    _certificationUrl != null &&
                                        _certificationUrl!.isNotEmpty
                                    ? 1.5
                                    : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            child: _uploadingCert
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox.square(
                                          dimension: 26,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  palette.primary,
                                                ),
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'Uploading document to Cloudflare R2…',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: palette.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color:
                                              _certificationUrl != null &&
                                                  _certificationUrl!.isNotEmpty
                                              ? palette.primary.withValues(
                                                  alpha: 0.12,
                                                )
                                              : palette.background,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _certificationUrl != null &&
                                                  _certificationUrl!.isNotEmpty
                                              ? (_certFileName
                                                            ?.toLowerCase()
                                                            .endsWith('.pdf') ==
                                                        true
                                                    ? Icons
                                                          .picture_as_pdf_rounded
                                                    : Icons.task_alt_rounded)
                                              : Icons.camera_alt_outlined,
                                          size: 28,
                                          color: palette.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _certificationUrl != null &&
                                                      _certificationUrl!
                                                          .isNotEmpty
                                                  ? (_certFileName ??
                                                        'Certificate uploaded')
                                                  : 'Upload certifications',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: palette.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              _certificationUrl != null &&
                                                      _certificationUrl!
                                                          .isNotEmpty
                                                  ? 'Attached · Tap to replace or add more'
                                                  : 'PDF, DOC or photo · Optional',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color:
                                                    _certificationUrl != null &&
                                                        _certificationUrl!
                                                            .isNotEmpty
                                                    ? palette.primary
                                                    : palette.textSecondary,
                                                fontWeight:
                                                    _certificationUrl != null &&
                                                        _certificationUrl!
                                                            .isNotEmpty
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_certificationUrl != null &&
                                          _certificationUrl!.isNotEmpty)
                                        IconButton(
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 20,
                                            color: palette.textSecondary,
                                          ),
                                          tooltip: 'Remove certification',
                                          onPressed: () {
                                            setState(() {
                                              _certificationUrl = null;
                                              _certFileName = null;
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // ── 6. Availability & Working Hours Section ──
                        Text(
                          'Availability & Working Hours',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set your operating days and daily working hours (AM to PM)',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Working Days Presets
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children:
                                [
                                  'Mon–Sat',
                                  'Mon–Fri',
                                  'Everyday',
                                  'Weekends',
                                ].map((days) {
                                  final isSel = _selectedDays == days;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedDays = days;
                                          _updateAvailabilityText();
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSel
                                              ? palette.primary
                                              : palette.surface,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: isSel
                                                ? palette.primary
                                                : palette.border,
                                            width: isSel ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          days,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSel
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSel
                                                ? Colors.white
                                                : palette.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Time Pickers (From AM to To PM)
                        Row(
                          children: [
                            // Start Time Card (AM)
                            Expanded(
                              child: InkWell(
                                onTap: _pickStartTime,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: palette.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.wb_sunny_outlined,
                                            size: 14,
                                            color: palette.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'FROM (AM)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: palette.textSecondary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatTimeOfDay(_startTime),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: palette.textPrimary,
                                            ),
                                          ),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 18,
                                            color: palette.textSecondary,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: palette.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: palette.primary,
                                ),
                              ),
                            ),
                            // End Time Card (PM)
                            Expanded(
                              child: InkWell(
                                onTap: _pickEndTime,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: palette.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.nightlight_round_outlined,
                                            size: 14,
                                            color: palette.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'TO (PM)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: palette.textSecondary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatTimeOfDay(_endTime),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: palette.textPrimary,
                                            ),
                                          ),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 18,
                                            color: palette.textSecondary,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Active Availability Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primaryLight.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: palette.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Working hours: $_selectedDays · ${_formatTimeOfDay(_startTime)} – ${_formatTimeOfDay(_endTime)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: palette.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // ── 7. Standard Hourly Rate (LKR) ──
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Standard Hourly Rate (LKR)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                Text(
                                  'LKR / hr',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: palette.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Set your baseline hourly rate. TaskBridge AI uses this to match you with customer job budgets.',
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AuthInput(
                              label: 'Rate per hour (LKR)',
                              hint: 'e.g. 2500',
                              controller: _hourlyRateController,
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [1500, 2000, 2500, 3500, 5000].map((
                                preset,
                              ) {
                                final isSelected =
                                    _hourlyRateController.text.trim() ==
                                    preset.toString();
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _hourlyRateController.text = preset
                                          .toString();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? palette.primary
                                          : palette.primaryLight.withValues(
                                              alpha: 0.5,
                                            ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? palette.primary
                                            : palette.primary.withValues(
                                                alpha: 0.25,
                                              ),
                                      ),
                                    ),
                                    child: Text(
                                      'Rs. $preset',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? Colors.white
                                            : palette.primary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // ── 8. Bio Field (Enlarged Multi-line Text Area) ──
                        AuthInput(
                          label: 'Bio (Optional)',
                          hint:
                              'Tell clients about your professional experience, work guarantees, tools, and background...',
                          controller: _bioController,
                          enabled: !_busy,
                          minLines: 4,
                          maxLines: 6,
                        ),

                        if (_error != null) ...[
                          AuthError(_error),
                          const SizedBox(height: 12),
                        ],

                        const SizedBox(height: AppSpacing.s16),

                        // ── Finish Setup Button ──
                        AppButton(
                          label: _isExistingProvider
                              ? 'Save Changes'
                              : 'Save & Continue',
                          loading: _busy,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


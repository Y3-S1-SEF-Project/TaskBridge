import 'package:flutter/material.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../home/pages/location_picker_page.dart';
import '../../core/services/location_service.dart';
import '../models/planning_models.dart';
import 'planning_progress_page.dart';

/// Screen C19: "A little more information"
/// Displays missing details (service location, date, time, custom budget) with job preview card and continue button.
class PlanningMissingInfoPage extends StatefulWidget {
  final JobPlan initialPlan;
  final PlanningAnalyzeResult analysisResult;
  final AuthUser? user;

  const PlanningMissingInfoPage({
    super.key,
    required this.initialPlan,
    required this.analysisResult,
    this.user,
  });

  @override
  State<PlanningMissingInfoPage> createState() =>
      _PlanningMissingInfoPageState();
}

class _PlanningMissingInfoPageState extends State<PlanningMissingInfoPage> {
  late JobPlan _plan;
  String? _selectedLocation;
  String? _selectedAddress;

  String? _selectedDate;
  String? _selectedTime;

  double? _selectedBudget;
  String? _selectedBudgetDisplay;
  final TextEditingController _customBudgetController = TextEditingController();

  bool _hasLocationError = false;
  bool _hasDateError = false;
  bool _hasTimeError = false;

  String? _savedLocationName;
  String? _savedAddressName;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _selectedLocation = _plan.location;
    _selectedAddress = _plan.locationAddress;
    _loadUserSavedLocation();

    // Only pre-fill date/time if it was explicitly parsed and NOT "Flexible" or empty
    if (_plan.scheduledDate.isNotEmpty &&
        !_plan.scheduledDate.toLowerCase().contains('flexible')) {
      _selectedDate = _plan.scheduledDate;
    }
    if (_plan.scheduledTime.isNotEmpty &&
        !_plan.scheduledTime.toLowerCase().contains('flexible')) {
      _selectedTime = _plan.scheduledTime;
    }

    _selectedBudget = _plan.budget;
    _selectedBudgetDisplay = _plan.budgetDisplay.isNotEmpty
        ? _plan.budgetDisplay
        : 'Budget not specified';

    if (_selectedBudget != null && _selectedBudget! > 0) {
      // Check if it matches any standard preset
      if (_selectedBudget != 2500 &&
          _selectedBudget != 5000 &&
          _selectedBudget != 10000) {
        _customBudgetController.text = _selectedBudget!.toInt().toString();
      }
    }
  }

  Future<void> _loadUserSavedLocation() async {
    String? loc = widget.user?.location;
    String? addr = widget.user?.address;

    if (loc == null || loc.trim().isEmpty) {
      final cached = await LocationService.getSavedLocation();
      if (cached != null) {
        loc = cached.shortName;
        addr ??= cached.address;
      }
    }

    if (mounted) {
      setState(() {
        _savedLocationName =
            (loc != null && loc.trim().isNotEmpty) ? loc.trim() : null;
        _savedAddressName =
            (addr != null && addr.trim().isNotEmpty) ? addr.trim() : null;
      });
    }
  }

  String get _savedLocationButtonLabel {
    if (_savedLocationName != null && _savedLocationName!.isNotEmpty) {
      return 'Use saved location ($_savedLocationName)';
    } else if (_savedAddressName != null && _savedAddressName!.isNotEmpty) {
      return 'Use saved address ($_savedAddressName)';
    }
    return 'Use current GPS location';
  }

  @override
  void dispose() {
    _customBudgetController.dispose();
    super.dispose();
  }

  Future<void> _useSavedHomeAddress() async {
    String? loc = _savedLocationName;
    String? addr = _savedAddressName;

    if (loc == null || loc.isEmpty) {
      try {
        final currentPos = await LocationService.determineCurrentPosition();
        if (currentPos != null) {
          loc = currentPos.shortName;
          addr = currentPos.address;
          if (mounted) {
            setState(() {
              _savedLocationName = loc;
              _savedAddressName = addr;
            });
          }
        }
      } catch (e) {
        _pickLocation();
        return;
      }
    }

    if (loc != null && loc.isNotEmpty) {
      setState(() {
        _selectedLocation = loc;
        _selectedAddress = (addr != null && addr.isNotEmpty) ? addr : loc;
        _hasLocationError = false;
        _plan = _plan.copyWith(
          location: loc,
          locationAddress: (addr != null && addr.isNotEmpty) ? addr : loc,
        );
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location applied: $loc${addr != null && addr.isNotEmpty && addr != loc ? " ($addr)" : ""}',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickLocation() async {
    final cached = await LocationService.getSavedLocation();
    final initial = _selectedLocation != null
        ? UserLocation(
            shortName: _selectedLocation!,
            address: _selectedAddress ?? _selectedLocation!,
            latitude: cached?.latitude ?? UserLocation.defaultLocation.latitude,
            longitude:
                cached?.longitude ?? UserLocation.defaultLocation.longitude,
          )
        : (cached ?? UserLocation.defaultLocation);

    if (!mounted) return;
    final picked = await Navigator.push<UserLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocation: initial,
          autoGps: false,
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedLocation = picked.shortName;
        _selectedAddress = picked.address;
        _hasLocationError = false;
        _plan = _plan.copyWith(
          location: picked.shortName,
          locationAddress: picked.address,
        );
      });
      await LocationService.saveLocation(picked);
    }
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: const Color(0xFF1E2421),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
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
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final formatted =
          '${weekdays[picked.weekday - 1]} · ${picked.day} ${months[picked.month - 1]}';
      setState(() {
        _selectedDate = formatted;
        _hasDateError = false;
      });
    }
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 15, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primary,
              surface: const Color(0xFF1E2421),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      final formatted = 'At $hour:$minute $period';
      setState(() {
        _selectedTime = formatted;
        _hasTimeError = false;
      });
    }
  }

  void _onCustomBudgetChanged(String val) {
    final cleaned = val.replaceAll(',', '').replaceAll(' ', '').trim();
    final amount = double.tryParse(cleaned);
    setState(() {
      if (amount != null && amount > 0) {
        _selectedBudget = amount;
        final formattedAmount = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
        _selectedBudgetDisplay = 'Budget up to Rs. $formattedAmount';
      } else {
        _selectedBudget = null;
        _selectedBudgetDisplay = 'Budget not specified';
      }
    });
  }

  void _onContinue() {
    bool hasError = false;

    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      setState(() => _hasLocationError = true);
      hasError = true;
    }

    if (_selectedDate == null || _selectedDate!.isEmpty) {
      setState(() => _hasDateError = true);
      hasError = true;
    }

    if (_selectedTime == null || _selectedTime!.isEmpty) {
      setState(() => _hasTimeError = true);
      hasError = true;
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedLocation == null
                ? 'Please select your service location.'
                : (_selectedDate == null
                      ? 'Please select your preferred service date.'
                      : 'Please select your preferred service time window.'),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final scheduledDate = _selectedDate!;
    final scheduledTime = _selectedTime!;

    final updatedPlan = _plan.copyWith(
      location: _selectedLocation,
      locationAddress: _selectedAddress ?? '24 Park Road',
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      budget: _selectedBudget,
      budgetDisplay:
          _selectedBudgetDisplay ??
          (_selectedBudget != null
              ? 'Budget up to Rs. ${_selectedBudget!.toInt()}'
              : 'Budget not specified'),
    );

    // Update progress steps for Screen C18
    final updatedSteps = [
      ReasoningStep(
        stepKey: 'understanding_service',
        title: 'Understanding service',
        subtitle: updatedPlan.serviceTitle,
        status: 'completed',
      ),
      const ReasoningStep(
        stepKey: 'finding_providers',
        title: 'Finding suitable providers',
        subtitle: 'Skills and service area matched',
        status: 'completed',
      ),
      ReasoningStep(
        stepKey: 'checking_availability',
        title: 'Checking availability',
        subtitle:
            '${updatedPlan.scheduledDate.split('·').first.trim()} ${updatedPlan.scheduledTime}'
                .trim(),
        status: 'completed',
      ),
      const ReasoningStep(
        stepKey: 'preparing_recommendation',
        title: 'Preparing recommendation',
        subtitle: 'Waiting for availability checks',
        status: 'pending',
      ),
    ];

    final updatedResult = PlanningAnalyzeResult(
      success: true,
      isLocationMissing: false,
      missingFields: const [],
      clarificationQuestion: widget.analysisResult.clarificationQuestion,
      jobPlan: updatedPlan,
      progressSteps: updatedSteps,
      latencyMs: widget.analysisResult.latencyMs,
      tokensUsed: widget.analysisResult.tokensUsed,
      model: widget.analysisResult.model,
    );

    // Navigate to Screen C18
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanningProgressPage(
          plan: updatedPlan,
          analysisResult: updatedResult,
          user: widget.user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final isLocMissing =
        _selectedLocation == null || _selectedLocation!.isEmpty;
    final isSchedMissing = _selectedDate == null || _selectedTime == null;

    String mintCardTitle;
    String mintCardSubtitle;

    if (isLocMissing && isSchedMissing) {
      mintCardTitle = 'Where & when do you need this done?';
      mintCardSubtitle =
          'Please provide your location and preferred schedule so TaskBridge AI can match available specialists.';
    } else if (isLocMissing) {
      mintCardTitle = 'Where do you need the service?';
      mintCardSubtitle =
          'We need your location to find verified providers who cover your area.';
    } else {
      mintCardTitle = 'When do you need the service?';
      mintCardSubtitle =
          'Select your preferred date and time so we can check specialist availability.';
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s20,
                  vertical: AppSpacing.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Back Button & Header ──
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.arrow_back,
                              color: palette.text,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // ── Header Tag ──
                    Text(
                      'AI PLANNING',
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),

                    // ── Main Screen Title ──
                    Text(
                      'A little more\ninformation',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // ── Dynamic Question Mint Card ──
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.s20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mintCardTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            mintCardSubtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── Section 1: Service Location ──
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Service location',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickLocation,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _hasLocationError
                                ? AppColors.error
                                : (_selectedLocation != null
                                      ? palette.primary
                                      : palette.border),
                            width: _hasLocationError ? 1.5 : 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedLocation != null &&
                                        _selectedLocation!.isNotEmpty
                                    ? '$_selectedLocation${_selectedAddress != null && _selectedAddress!.isNotEmpty ? " · $_selectedAddress" : ""}'
                                    : 'Select location',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: _selectedLocation != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _selectedLocation != null
                                      ? palette.text
                                      : palette.muted,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: palette.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // ── Pill Button: Use Saved Home Address ──
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: palette.primary.withValues(
                            alpha: 0.12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _useSavedHomeAddress,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _savedLocationName != null
                                  ? Icons.home_outlined
                                  : Icons.my_location_rounded,
                              size: 16,
                              color: palette.primary,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _savedLocationButtonLabel,
                                style: TextStyle(
                                  color: palette.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── Section 2: Preferred Date ──
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Preferred Date',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    if (_hasDateError) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Please choose a date or select Flexible',
                        style: TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChoiceChip(
                          label: 'Today',
                          isSelected:
                              _selectedDate?.startsWith('Today') == true,
                          onTap: () {
                            final now = DateTime.now();
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
                            setState(() {
                              _selectedDate =
                                  'Today · ${now.day} ${months[now.month - 1]}';
                              _hasDateError = false;
                            });
                          },
                          palette: palette,
                        ),
                        _buildChoiceChip(
                          label: 'Tomorrow',
                          isSelected:
                              _selectedDate?.startsWith('Tomorrow') == true,
                          onTap: () {
                            final tomorrow = DateTime.now().add(
                              const Duration(days: 1),
                            );
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
                            setState(() {
                              _selectedDate =
                                  'Tomorrow · ${tomorrow.day} ${months[tomorrow.month - 1]}';
                              _hasDateError = false;
                            });
                          },
                          palette: palette,
                        ),
                        _buildChoiceChip(
                          label: 'Flexible',
                          isSelected: _selectedDate == 'Flexible',
                          onTap: () {
                            setState(() {
                              _selectedDate = 'Flexible';
                              _hasDateError = false;
                            });
                          },
                          palette: palette,
                        ),
                        ActionChip(
                          avatar: Icon(
                            Icons.edit_calendar_rounded,
                            size: 16,
                            color: palette.primary,
                          ),
                          label: Text(
                            _selectedDate != null &&
                                    !_selectedDate!.startsWith('Today') &&
                                    !_selectedDate!.startsWith('Tomorrow') &&
                                    _selectedDate != 'Flexible'
                                ? _selectedDate!
                                : 'Pick date…',
                          ),
                          onPressed: _pickCustomDate,
                          backgroundColor:
                              _selectedDate != null &&
                                  !_selectedDate!.startsWith('Today') &&
                                  !_selectedDate!.startsWith('Tomorrow') &&
                                  _selectedDate != 'Flexible'
                              ? palette.primary.withValues(alpha: 0.15)
                              : palette.soft,
                          side: BorderSide(
                            color:
                                _selectedDate != null &&
                                    !_selectedDate!.startsWith('Today') &&
                                    !_selectedDate!.startsWith('Tomorrow') &&
                                    _selectedDate != 'Flexible'
                                ? palette.primary
                                : palette.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── Section 3: Preferred Time Window ──
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 18,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Preferred Time Window',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    if (_hasTimeError) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Please choose a time window or select Flexible',
                        style: TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChoiceChip(
                          label: 'Morning (8 AM - 12 PM)',
                          isSelected: _selectedTime == 'Morning (8 AM - 12 PM)',
                          onTap: () {
                            setState(() {
                              _selectedTime = 'Morning (8 AM - 12 PM)';
                              _hasTimeError = false;
                            });
                          },
                          palette: palette,
                        ),
                        _buildChoiceChip(
                          label: 'Afternoon (12 PM - 5 PM)',
                          isSelected:
                              _selectedTime == 'Afternoon (12 PM - 5 PM)',
                          onTap: () {
                            setState(() {
                              _selectedTime = 'Afternoon (12 PM - 5 PM)';
                              _hasTimeError = false;
                            });
                          },
                          palette: palette,
                        ),
                        _buildChoiceChip(
                          label: 'Evening (After 5 PM)',
                          isSelected: _selectedTime == 'Evening (After 5 PM)',
                          onTap: () {
                            setState(() {
                              _selectedTime = 'Evening (After 5 PM)';
                              _hasTimeError = false;
                            });
                          },
                          palette: palette,
                        ),
                        _buildChoiceChip(
                          label: 'Flexible',
                          isSelected: _selectedTime == 'Flexible',
                          onTap: () {
                            setState(() {
                              _selectedTime = 'Flexible';
                              _hasTimeError = false;
                            });
                          },
                          palette: palette,
                        ),
                        ActionChip(
                          avatar: Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: palette.primary,
                          ),
                          label: Text(
                            _selectedTime != null &&
                                    _selectedTime != 'Morning (8 AM - 12 PM)' &&
                                    _selectedTime !=
                                        'Afternoon (12 PM - 5 PM)' &&
                                    _selectedTime != 'Evening (After 5 PM)' &&
                                    _selectedTime != 'Flexible'
                                ? _selectedTime!
                                : 'Exact time…',
                          ),
                          onPressed: _pickCustomTime,
                          backgroundColor:
                              _selectedTime != null &&
                                  _selectedTime != 'Morning (8 AM - 12 PM)' &&
                                  _selectedTime != 'Afternoon (12 PM - 5 PM)' &&
                                  _selectedTime != 'Evening (After 5 PM)' &&
                                  _selectedTime != 'Flexible'
                              ? palette.primary.withValues(alpha: 0.15)
                              : palette.soft,
                          side: BorderSide(
                            color:
                                _selectedTime != null &&
                                    _selectedTime != 'Morning (8 AM - 12 PM)' &&
                                    _selectedTime !=
                                        'Afternoon (12 PM - 5 PM)' &&
                                    _selectedTime != 'Evening (After 5 PM)' &&
                                    _selectedTime != 'Flexible'
                                ? palette.primary
                                : palette.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── Section 4: Budget & Custom Budget Box ──
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Budget (LKR)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBudgetChip('Flexible', null, palette),
                        _buildBudgetChip('Rs. 2,500', 2500, palette),
                        _buildBudgetChip('Rs. 5,000', 5000, palette),
                        _buildBudgetChip('Rs. 10,000', 10000, palette),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Custom budget text field
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _customBudgetController.text.isNotEmpty
                              ? palette.primary
                              : palette.border,
                          width: _customBudgetController.text.isNotEmpty
                              ? 1.5
                              : 1.0,
                        ),
                      ),
                      child: TextField(
                        controller: _customBudgetController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                        ),
                        onChanged: _onCustomBudgetChanged,
                        decoration: InputDecoration(
                          hintText: 'Or enter custom budget (e.g. 7,500)',
                          hintStyle: TextStyle(
                            color: palette.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.currency_exchange_rounded,
                            color: _customBudgetController.text.isNotEmpty
                                ? palette.primary
                                : palette.muted,
                            size: 20,
                          ),
                          prefixText: 'Rs. ',
                          prefixStyle: TextStyle(
                            color: palette.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          suffixIcon: _customBudgetController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: palette.muted,
                                  ),
                                  onPressed: () {
                                    _customBudgetController.clear();
                                    _onCustomBudgetChanged('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── Summary Job Card (Real-time Preview) ──
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border, width: 1),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.s20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _plan.serviceTitle,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: palette.text,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _plan.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: palette.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _plan.description.isNotEmpty
                                ? _plan.description
                                : 'Repair and service request.',
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Location Detail Row
                          _buildDetailRow(
                            palette: palette,
                            icon: Icons.location_on_outlined,
                            title: _selectedLocation ?? 'Location not selected',
                            subtitle:
                                _selectedAddress ??
                                'Required to find local specialists',
                            isWarning: _selectedLocation == null,
                          ),
                          const SizedBox(height: 14),

                          // Calendar Detail Row
                          _buildDetailRow(
                            palette: palette,
                            icon: Icons.calendar_today_outlined,
                            title: _selectedDate ?? 'Date not selected',
                            subtitle:
                                _selectedTime ?? 'Time window not selected',
                            isWarning:
                                _selectedDate == null || _selectedTime == null,
                          ),
                          const SizedBox(height: 14),

                          // Budget Detail Row
                          _buildDetailRow(
                            palette: palette,
                            icon: Icons.account_balance_wallet_outlined,
                            title:
                                _selectedBudgetDisplay ??
                                'Budget not specified',
                            subtitle: null,
                            isWarning: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                  ],
                ),
              ),
            ),

            // ── Fixed Bottom Button: Continue ──
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: AppSpacing.s16,
              ),
              decoration: BoxDecoration(
                color: palette.background,
                border: Border(
                  top: BorderSide(color: palette.border, width: 0.8),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _onContinue,
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required AppPalette palette,
    required IconData icon,
    required String title,
    String? subtitle,
    bool isWarning = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: isWarning ? AppColors.error : palette.primary,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isWarning ? AppColors.error : palette.text,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isWarning
                        ? AppColors.error.withValues(alpha: 0.8)
                        : palette.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppPalette palette,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: palette.primary,
      backgroundColor: palette.soft,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? palette.onPrimary : palette.text,
      ),
      side: BorderSide(color: isSelected ? palette.primary : palette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildBudgetChip(String label, double? amount, AppPalette palette) {
    final isSelected =
        _selectedBudget == amount && _customBudgetController.text.isEmpty;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _customBudgetController.clear();
          _selectedBudget = amount;
          _selectedBudgetDisplay = amount != null
              ? 'Budget up to Rs. ${amount.toInt()}'
              : 'Budget not specified';
        });
      },
      selectedColor: palette.primary,
      backgroundColor: palette.soft,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? palette.onPrimary : palette.text,
      ),
      side: BorderSide(color: isSelected ? palette.primary : palette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

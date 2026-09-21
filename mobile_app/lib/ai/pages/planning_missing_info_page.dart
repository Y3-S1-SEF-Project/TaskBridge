import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../home/pages/location_picker_page.dart';
import '../../core/services/location_service.dart';
import '../models/planning_models.dart';
import 'planning_progress_page.dart';

/// Screen C19: "A little more information"
/// Displays missing details (e.g. service location) with job preview card and continue button.
class PlanningMissingInfoPage extends StatefulWidget {
  final JobPlan initialPlan;
  final PlanningAnalyzeResult analysisResult;

  const PlanningMissingInfoPage({
    super.key,
    required this.initialPlan,
    required this.analysisResult,
  });

  @override
  State<PlanningMissingInfoPage> createState() => _PlanningMissingInfoPageState();
}

class _PlanningMissingInfoPageState extends State<PlanningMissingInfoPage> {
  late JobPlan _plan;
  String? _selectedLocation;
  String? _selectedAddress;
  double? _selectedBudget;
  String? _selectedBudgetDisplay;
  bool _hasLocationError = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.initialPlan;
    _selectedLocation = _plan.location;
    _selectedAddress = _plan.locationAddress;
    _selectedBudget = _plan.budget;
    _selectedBudgetDisplay = _plan.budgetDisplay;
  }

  void _useSavedHomeAddress() {
    setState(() {
      _selectedLocation = 'Colombo 05';
      _selectedAddress = '24 Park Road';
      _hasLocationError = false;
      _plan = _plan.copyWith(
        location: 'Colombo 05',
        locationAddress: '24 Park Road',
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Home address applied: Colombo 05 (24 Park Road)'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.push<UserLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocation: UserLocation(
            shortName: _selectedLocation ?? 'Colombo 05',
            address: _selectedAddress ?? '24 Park Road',
            latitude: 6.8928,
            longitude: 79.8732,
          ),
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
    }
  }

  void _onContinue() {
    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      setState(() => _hasLocationError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select or provide your service location.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final updatedPlan = _plan.copyWith(
      location: _selectedLocation,
      locationAddress: _selectedAddress ?? '24 Park Road',
      budget: _selectedBudget,
      budgetDisplay: _selectedBudgetDisplay ?? (_selectedBudget != null ? 'Budget up to Rs. ${_selectedBudget!.toInt()}' : 'Budget not specified'),
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
        subtitle: '${updatedPlan.scheduledDate.split('·').first.trim()} ${updatedPlan.scheduledTime}'.trim(),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

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
                      'PLANNING AGENT',
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

                    // ── Question Mint Card ──
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.s20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Where do you need the service?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We need your location to find providers who cover your area.',
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

                    // ── Service Location Field ──
                    Text(
                      'Service location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
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
                                : palette.border,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedLocation != null && _selectedLocation!.isNotEmpty
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
                    const SizedBox(height: AppSpacing.s16),

                    // ── Pill Button: Use Saved Home Address ──
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: palette.primary.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _useSavedHomeAddress,
                        child: Text(
                          'Use saved home address',
                          style: TextStyle(
                            color: palette.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // ── Budget (Optional / Missing Field) ──
                    Text(
                      'Budget',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
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
                    const SizedBox(height: AppSpacing.s24),

                    // ── Summary Job Card ──
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
                          Text(
                            _plan.serviceTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _plan.description.isNotEmpty
                                ? _plan.description
                                : 'Repair the leaking kitchen tap and test for leaks.',
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
                            subtitle: _selectedAddress ?? 'Tap above to set address',
                          ),
                          const SizedBox(height: 14),

                          // Calendar Detail Row
                          _buildDetailRow(
                            palette: palette,
                            icon: Icons.calendar_today_outlined,
                            title: _plan.scheduledDate,
                            subtitle: _plan.scheduledTime,
                          ),
                          const SizedBox(height: 14),

                          // Budget Detail Row
                          _buildDetailRow(
                            palette: palette,
                            icon: Icons.account_balance_wallet_outlined,
                            title: _selectedBudgetDisplay ?? (_plan.budgetDisplay.isNotEmpty ? _plan.budgetDisplay : 'Budget not specified'),
                            subtitle: null,
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
                border: Border(top: BorderSide(color: palette.border, width: 0.8)),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: palette.primary, size: 22),
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
                  color: palette.text,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetChip(String label, double? amount, AppPalette palette) {
    final isSelected = _selectedBudget == amount;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
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
      side: BorderSide(
        color: isSelected ? palette.primary : palette.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

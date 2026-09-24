import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../models/planning_models.dart';
import '../services/matching_api.dart';
import 'matched_providers_page.dart';

/// Screen C18: "Finding the right help"
/// Staggered top-to-bottom animation for the 4 checklist steps with live status updates.
class PlanningProgressPage extends StatefulWidget {
  final JobPlan plan;
  final PlanningAnalyzeResult analysisResult;
  final AuthUser? user;

  const PlanningProgressPage({
    super.key,
    required this.plan,
    required this.analysisResult,
    this.user,
  });

  @override
  State<PlanningProgressPage> createState() => _PlanningProgressPageState();
}

class _PlanningProgressPageState extends State<PlanningProgressPage>
    with TickerProviderStateMixin {
  // Step state: 0 = hidden, 1 = loading/pulsing, 2 = resolved/done
  int _visibleStepsCount = 0;
  final List<int> _stepStates = [0, 0, 0, 0];
  bool _isAllComplete = false;
  bool _isMatchingLoading = false;
  Timer? _timer;

  Future<void> _navigateToMatching() async {
    setState(() => _isMatchingLoading = true);
    try {
      final response = await MatchingApi.matchProviders(
        jobPlan: widget.plan,
        customerUserId: widget.user?.id,
        customerName: widget.user?.fullName,
      );
      if (!mounted) return;
      setState(() => _isMatchingLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MatchedProvidersPage(
            jobPlan: widget.plan,
            matchingResponse: response,
            user: widget.user,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMatchingLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error matching specialists: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _startSequentialAnimation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSequentialAnimation() {
    // Step 1 activates at 300ms
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _visibleStepsCount = 1;
        _stepStates[0] = 1; // loading
      });

      // Step 1 completes at 900ms, Step 2 begins loading
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _stepStates[0] = 2; // completed (check)
          _visibleStepsCount = 2;
          _stepStates[1] = 1; // loading
        });

        // Step 2 completes at 1700ms, Step 3 begins loading
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          setState(() {
            _stepStates[1] = 2; // completed (check)
            _visibleStepsCount = 3;
            _stepStates[2] = 1; // loading
          });

          // Step 3 completes at 2500ms, Step 4 begins
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            setState(() {
              _stepStates[2] = 2; // completed (clock / checked)
              _visibleStepsCount = 4;
              _stepStates[3] = 1; // loading
            });

            // Step 4 finishes
            Future.delayed(const Duration(milliseconds: 800), () {
              if (!mounted) return;
              setState(() {
                _stepStates[3] = 2; // ready
                _isAllComplete = true;
              });
            });
          });
        });
      });
    });
  }

  void _showAiBreakdown() {
    final palette = AppPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: palette.primary, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'AI Reasoning & Inspection Trace',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metrics Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'OpenAI Latency',
                          value: '${widget.analysisResult.latencyMs} ms',
                          palette: palette,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Tokens Used',
                          value: '${widget.analysisResult.tokensUsed} tokens',
                          palette: palette,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Model',
                          value: widget.analysisResult.model,
                          palette: palette,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Agent Role',
                          value: 'Planning Agent (1)',
                          palette: palette,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Extracted Structured Job Plan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: SelectableText(
                      '• Service: ${widget.plan.serviceTitle}\n'
                      '• Category: ${widget.plan.category}\n'
                      '• Description: ${widget.plan.description}\n'
                      '• Location: ${widget.plan.location ?? "Colombo 05"} (${widget.plan.locationAddress ?? "24 Park Road"})\n'
                      '• Schedule: ${widget.plan.scheduledDate} ${widget.plan.scheduledTime}\n'
                      '• Budget: ${widget.plan.budgetDisplay}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: palette.text,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required AppPalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
        ],
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        // Live AI Inspection Chip for examiner presentation
                        ActionChip(
                          avatar: Icon(
                            Icons.auto_awesome,
                            color: palette.primary,
                            size: 16,
                          ),
                          label: Text(
                            'AI Trace',
                            style: TextStyle(
                              color: palette.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          backgroundColor: palette.primary.withValues(alpha: 0.1),
                          side: BorderSide(
                            color: palette.primary.withValues(alpha: 0.2),
                          ),
                          onPressed: _showAiBreakdown,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // ── Header Tag ──
                    Text(
                      'TASKBRIDGE AI',
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
                      'Finding the right help',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // ── Top Card: Understanding your request... ──
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
                            'Understanding your request...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "We're checking registered providers for your needs.",
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Icon(
                            Icons.auto_fix_high_rounded,
                            color: palette.primary,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── 4 Sequential Animated Checklist Items (Top to Bottom) ──
                    _buildAnimatedStep(
                      stepIndex: 0,
                      title: 'Understanding service',
                      subtitle: widget.plan.serviceTitle.isNotEmpty
                          ? widget.plan.serviceTitle
                          : 'Kitchen tap repair',
                      iconType: _StepIconType.check,
                      palette: palette,
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    _buildAnimatedStep(
                      stepIndex: 1,
                      title: 'Finding suitable providers',
                      subtitle: 'Skills and service area matched',
                      iconType: _StepIconType.check,
                      palette: palette,
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    _buildAnimatedStep(
                      stepIndex: 2,
                      title: 'Checking availability',
                      subtitle: '${widget.plan.scheduledDate.split('·').first.trim()} ${widget.plan.scheduledTime}'.trim(),
                      iconType: _StepIconType.clock,
                      palette: palette,
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    _buildAnimatedStep(
                      stepIndex: 3,
                      title: 'Preparing recommendation',
                      subtitle: _isAllComplete
                          ? 'Available specialists matched'
                          : 'Waiting for availability checks',
                      iconType: _isAllComplete ? _StepIconType.check : _StepIconType.clock,
                      palette: palette,
                    ),
                    const SizedBox(height: AppSpacing.s32),

                    // ── Bottom Card: You stay in control ──
                    AnimatedOpacity(
                      opacity: _visibleStepsCount >= 2 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Container(
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
                              'You stay in control',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'We recommend providers. You choose an actual offer and confirm the booking.',
                              style: TextStyle(
                                fontSize: 14,
                                color: palette.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                  ],
                ),
              ),
            ),

            // ── Bottom Action Button (Appears when loading finishes) ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
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
                  onPressed: (_isAllComplete && !_isMatchingLoading)
                      ? _navigateToMatching
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isAllComplete || _isMatchingLoading) ...[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              palette.onPrimary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isMatchingLoading
                              ? 'Finding top matches...'
                              : 'Analyzing providers...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'View Recommended Providers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
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

  Widget _buildAnimatedStep({
    required int stepIndex,
    required String title,
    required String subtitle,
    required _StepIconType iconType,
    required AppPalette palette,
  }) {
    final isVisible = _visibleStepsCount > stepIndex;
    final state = _stepStates[stepIndex]; // 0: hidden, 1: loading, 2: resolved

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      opacity: isVisible ? 1.0 : 0.15,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, 0.25),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step Icon with dynamic status animation
            _buildStepIcon(
              state: state,
              iconType: iconType,
              palette: palette,
            ),
            const SizedBox(width: 14),
            // Step text details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: state == 1 ? palette.primary : palette.muted,
                    ),
                    child: Text(
                      state == 1 ? 'Checking...' : subtitle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIcon({
    required int state,
    required _StepIconType iconType,
    required AppPalette palette,
  }) {
    // State 1: Active loading spinner
    if (state == 1) {
      return Container(
        width: 28,
        height: 28,
        padding: const EdgeInsets.all(4),
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
        ),
      );
    }

    // State 2: Resolved icon (Checkmark or Clock)
    if (iconType == _StepIconType.check) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.primary, width: 2),
        ),
        child: Icon(
          Icons.check,
          color: palette.primary,
          size: 18,
        ),
      );
    } else {
      // Clock / Timer outline icon
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: palette.primary, width: 2),
        ),
        child: Icon(
          Icons.alarm_rounded,
          color: palette.primary,
          size: 16,
        ),
      );
    }
  }
}

enum _StepIconType {
  check,
  clock,
}

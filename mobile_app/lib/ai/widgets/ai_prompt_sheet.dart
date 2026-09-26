import 'package:flutter/material.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../pages/planning_missing_info_page.dart';
import '../pages/planning_progress_page.dart';
import '../services/planning_api.dart';

class AiPromptSheet extends StatefulWidget {
  final String? currentLocation;
  final AuthUser? user;

  const AiPromptSheet({super.key, this.currentLocation, this.user});

  static Future<void> show(
    BuildContext context, {
    String? currentLocation,
    AuthUser? user,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AiPromptSheet(currentLocation: currentLocation, user: user),
    );
  }

  @override
  State<AiPromptSheet> createState() => _AiPromptSheetState();
}

class _AiPromptSheetState extends State<AiPromptSheet> {
  final TextEditingController _promptController = TextEditingController();
  bool _isLoading = false;

  final List<String> _quickSamples = [
    'My kitchen tap is leaking tomorrow after 3 PM. Budget is Rs. 5,000.',
    'Kitchen tap repair in Colombo 05 tomorrow afternoon, budget Rs. 5000',
    'AC not cooling in living room, need gas refill this weekend',
    'Main switch tripping whenever water heater turns on',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submitPrompt([String? overrideText]) async {
    final text = (overrideText ?? _promptController.text).trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // If user typed prompt does not specify a location, we pass null so AI detects missing location
      final promptContainsLocation =
          text.toLowerCase().contains('colombo') ||
          text.toLowerCase().contains('maharagama') ||
          text.toLowerCase().contains('kandy') ||
          text.toLowerCase().contains('galle');

      final locationContext = promptContainsLocation
          ? widget.currentLocation
          : null;

      final result = await PlanningApi.analyzePrompt(
        prompt: text,
        userLocation: locationContext,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Close modal sheet
      Navigator.pop(context);

      // Branch based on missing info: Screen C19 vs Screen C18
      final isScheduleMissing =
          result.missingFields.contains('date') ||
          result.missingFields.contains('time') ||
          result.jobPlan.scheduledDate.isEmpty ||
          result.jobPlan.scheduledTime.isEmpty;

      if (result.isLocationMissing ||
          result.jobPlan.location == null ||
          isScheduleMissing) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanningMissingInfoPage(
              initialPlan: result.jobPlan,
              analysisResult: result,
              user: widget.user,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanningProgressPage(
              plan: result.jobPlan,
              analysisResult: result,
              user: widget.user,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing request: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        AppSpacing.s24 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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
            const SizedBox(height: AppSpacing.s16),

            // Header Tag & Title
            Row(
              children: [
                Icon(Icons.auto_awesome, color: palette.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'TASKBRIDGE AI',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'What do you need help with?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Describe in your own words. AI will analyze your request and match providers.',
              style: TextStyle(fontSize: 14, color: palette.muted, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Text Input Field
            TextField(
              controller: _promptController,
              maxLines: 3,
              style: TextStyle(fontSize: 15, color: palette.text),
              decoration: InputDecoration(
                hintText:
                    'e.g. My kitchen tap is leaking tomorrow after 3 PM. Budget is Rs. 5,000.',
                hintStyle: TextStyle(color: palette.muted, fontSize: 14),
                filled: true,
                fillColor: palette.soft,
                contentPadding: const EdgeInsets.all(14),
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
                  borderSide: BorderSide(color: palette.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Quick suggestion chips
            Text(
              'Quick examples:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickSamples.map((sample) {
                return InkWell(
                  onTap: _isLoading
                      ? null
                      : () {
                          _promptController.text = sample;
                          _submitPrompt(sample);
                        },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      sample.length > 35
                          ? '${sample.substring(0, 35)}…'
                          : sample,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: palette.text,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading ? null : () => _submitPrompt(),
                child: _isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            palette.onPrimary,
                          ),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Analyze with AI',
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
    );
  }
}

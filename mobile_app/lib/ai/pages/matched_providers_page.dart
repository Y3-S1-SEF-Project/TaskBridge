import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../models/matching_models.dart';
import '../models/planning_models.dart';

/// Screen C20: "Your provider shortlist"
/// Matches the exact Figma layout:
/// - Header: MATCHING AGENT, "Your provider shortlist"
/// - Job Summary Card (Title, description, location, date/time, budget)
/// - "3 suitable providers"
/// - ProviderCard/AI with "Recommended by TaskBridge AI" mint banner,
///   avatar, verified badge, rating & distance, availability, and "View Profile" button
/// - Sticky bottom button: "Request Quotations"
class MatchedProvidersPage extends StatefulWidget {
  final JobPlan jobPlan;
  final MatchingResponse matchingResponse;

  const MatchedProvidersPage({
    super.key,
    required this.jobPlan,
    required this.matchingResponse,
  });

  @override
  State<MatchedProvidersPage> createState() => _MatchedProvidersPageState();
}

class _MatchedProvidersPageState extends State<MatchedProvidersPage> {
  void _showAiBreakdown(MatchedProvider provider) {
    final palette = AppPalette.of(context);
    final b = provider.scoreBreakdown;

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
                        'AI Matching Reasoning',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Multi-Criteria Decision Analysis for ${provider.fullName}',
                    style: TextStyle(fontSize: 13, color: palette.muted),
                  ),
                  const SizedBox(height: 16),

                  // Metrics Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Match Confidence',
                          value: '${provider.matchScore}% Match',
                          palette: palette,
                          isHighlight: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'OpenAI Latency',
                          value: '${widget.matchingResponse.latencyMs} ms',
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
                          title: 'Candidate Pool',
                          value: '${widget.matchingResponse.candidatePoolCount} registered',
                          palette: palette,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Hourly Rate',
                          value: 'Rs. ${provider.hourlyRate.toInt()}/hr',
                          palette: palette,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Multi-Criteria Scoring Weights',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildScoreRow(
                    title: 'Skill & Category Relevance (35%)',
                    score: b.skillScore,
                    maxScore: 35.0,
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  _buildScoreRow(
                    title: 'Location & Service Radius (25%)',
                    score: b.locationScore,
                    maxScore: 25.0,
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  _buildScoreRow(
                    title: 'Budget & Rate Fit (20%)',
                    score: b.budgetScore,
                    maxScore: 20.0,
                    palette: palette,
                  ),
                  const SizedBox(height: 10),
                  _buildScoreRow(
                    title: 'Rating & Track Record (20%)',
                    score: b.ratingScore,
                    maxScore: 20.0,
                    palette: palette,
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'AI Justification',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      provider.aiMatchReason,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.text,
                        height: 1.45,
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
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlight
            ? palette.primary.withValues(alpha: 0.12)
            : palette.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlight ? palette.primary : palette.border,
        ),
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
              fontWeight: FontWeight.w800,
              color: isHighlight ? palette.primary : palette.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow({
    required String title,
    required double score,
    required double maxScore,
    required AppPalette palette,
  }) {
    final ratio = (score / maxScore).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            Text(
              '${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: palette.border,
            valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  void _onRequestQuotations() {
    final count = widget.matchingResponse.matchedProviders.length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No providers currently available for this category.'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? 'Quotation requested from ${widget.matchingResponse.matchedProviders.first.fullName}!'
              : 'Quotations requested from all $count shortlisted providers!',
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final providers = widget.matchingResponse.matchedProviders;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s20,
                  vertical: AppSpacing.s12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar (Back button & AI Trace)
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
                          onPressed: () {
                            if (providers.isNotEmpty) {
                              _showAiBreakdown(providers.first);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Header Tag
                    Text(
                      'MATCHING AGENT',
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),

                    // Screen Title
                    Text(
                      'Your provider shortlist',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // ── Job Summary Card (Matches Figma C20 & C19) ──
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
                            widget.jobPlan.serviceTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.jobPlan.description.isNotEmpty
                                ? widget.jobPlan.description
                                : 'Repair the leaking kitchen tap and test for leaks.',
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Location Row
                          _buildDetailRow(
                            palette: palette,
                            icon: Icons.location_on_outlined,
                            title: widget.jobPlan.location ?? 'Colombo 05',
                            subtitle: widget.jobPlan.locationAddress ?? '24 Park Road',
                          ),
                          const SizedBox(height: 12),

                          // Calendar Row
                          _buildDetailRow(
                            palette: palette,
                            icon: Icons.calendar_today_outlined,
                            title: widget.jobPlan.scheduledDate,
                            subtitle: widget.jobPlan.scheduledTime,
                          ),
                          const SizedBox(height: 12),

                          // Budget Row
                          _buildDetailRow(
                            palette: palette,
                            icon: Icons.account_balance_wallet_outlined,
                            title: widget.jobPlan.budgetDisplay,
                            subtitle: null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── Section Title: "1 suitable provider" or "X suitable providers" ──
                    Text(
                      providers.isEmpty
                          ? 'No providers found'
                          : providers.length == 1
                              ? '1 suitable provider'
                              : '${providers.length} suitable providers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // ── Provider Cards (ProviderCard/AI from Figma) or Empty State ──
                    if (providers.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s20,
                          vertical: AppSpacing.s24,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 44,
                              color: palette.muted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No registered providers available',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No active providers are currently registered for this category in your area.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...providers.map((provider) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                          child: _buildProviderCard(
                            provider: provider,
                            palette: palette,
                          ),
                        );
                      }),
                    const SizedBox(height: AppSpacing.s20),
                  ],
                ),
              ),
            ),

            // ── Sticky Bottom Button: "Request Quotations" ──
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
                  onPressed: _onRequestQuotations,
                  child: const Text(
                    'Request Quotations',
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

  Widget _buildProviderCard({
    required MatchedProvider provider,
    required AppPalette palette,
  }) {
    // Format specialty label, e.g. "Gardening specialist" or "Plumbing specialist"
    final rawCat = provider.category.toLowerCase();
    final specialty = rawCat.contains('garden')
        ? 'Gardening specialist'
        : (rawCat.contains('clean')
            ? 'Cleaning specialist'
            : (rawCat.contains('plumb')
                ? 'Plumbing specialist'
                : (rawCat.contains('electric')
                    ? 'Electrical specialist'
                    : provider.category)));

    final locationText = widget.jobPlan.location ?? 'Colombo 05';

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Banner: "Recommended by TaskBridge AI" (Figma Exact) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: palette.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommended by TaskBridge AI',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Provider Info Row (Avatar, Name, Verified, Rating & Distance)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: palette.primary.withValues(alpha: 0.15),
                      child: Text(
                        provider.fullName.isNotEmpty
                            ? provider.fullName.substring(0, 1).toUpperCase()
                            : 'P',
                        style: TextStyle(
                          color: palette.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.fullName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Verified · $specialty',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.primary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${provider.rating} (${provider.reviewCount} reviews) · ${provider.distanceKm} km away',
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.muted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),

                // Availability & Location Line
                Text(
                  'Available tomorrow · $locationText',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── "View Profile" Full Width Mint Button (Figma Exact) ──
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary.withValues(alpha: 0.10),
                      foregroundColor: palette.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showAiBreakdown(provider),
                    child: Text(
                      'View Profile',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        Icon(icon, color: palette.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
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
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../models/matching_models.dart';
import '../models/planning_models.dart';
import '../services/coordination_api.dart';
import 'quotation_proposal_page.dart';
import '../../home/pages/provider_detail_page.dart';

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
  final AuthUser? user;

  const MatchedProvidersPage({
    super.key,
    required this.jobPlan,
    required this.matchingResponse,
    this.user,
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
      showDragHandle: false,
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
                      Icon(
                        Icons.auto_awesome,
                        color: palette.primary,
                        size: 22,
                      ),
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
                          value:
                              '${widget.matchingResponse.candidatePoolCount} registered',
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
          Text(title, style: TextStyle(fontSize: 12, color: palette.muted)),
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

  bool _isRequestingQuotes = false;

  List<MatchedProvider> _filterNonSelfProviders(List<MatchedProvider> list) {
    if (widget.user == null) return list;
    final currentUserId = widget.user!.id.toLowerCase();
    final currentName = widget.user!.fullName.trim().toLowerCase();

    return list.where((p) {
      if (p.userId.isNotEmpty && p.userId.toLowerCase() == currentUserId) {
        return false;
      }
      if (p.fullName.trim().toLowerCase() == currentName) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _onRequestQuotations() async {
    setState(() => _isRequestingQuotes = true);

    try {
      final validCandidates = _filterNonSelfProviders(
        widget.matchingResponse.matchedProviders,
      );
      final proposal = await CoordinationApi.evaluateQuotations(
        jobPlan: widget.jobPlan,
        candidateProviders: validCandidates,
        customerId: widget.user?.id,
        customerName: widget.user?.fullName,
      );

      if (!mounted) return;
      setState(() => _isRequestingQuotes = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuotationProposalPage(
            jobPlan: widget.jobPlan,
            proposalResponse: proposal,
            user: widget.user,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRequestingQuotes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error evaluating quotations: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
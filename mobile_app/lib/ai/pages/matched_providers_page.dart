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

  void _handleBack(BuildContext context, bool isEmpty) {
    if (isEmpty) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final providers = _filterNonSelfProviders(
      widget.matchingResponse.matchedProviders,
    );

    return PopScope(
      canPop: providers.isNotEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
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
                            onTap: () =>
                                _handleBack(context, providers.isEmpty),
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
                            backgroundColor: palette.primary.withValues(
                              alpha: 0.1,
                            ),
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
                        'AI MATCHING',
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
                              subtitle:
                                  widget.jobPlan.locationAddress ??
                                  '24 Park Road',
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
                                Icons.search_off_rounded,
                                size: 44,
                                color: palette.muted,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No providers currently available',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: palette.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'No providers currently available for this category in your area.',
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
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s16,
                            ),
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
                    onPressed: _isRequestingQuotes
                        ? null
                        : providers.isEmpty
                        ? () => _handleBack(context, true)
                        : _onRequestQuotations,
                    child: _isRequestingQuotes
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            providers.isEmpty
                                ? 'Back to Home'
                                : 'Request Quotations',
                            style: const TextStyle(
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
      ),
    );
  }

  void _navigateToDetail(MatchedProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderDetailPage(provider: provider.toProviderItem()),
      ),
    );
  }

  Future<void> _callProvider(BuildContext context, String phone) async {
    final rawPhone = phone.trim();
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number not available for this specialist.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final cleaned = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open dialer for $rawPhone'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching dialer for $rawPhone'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

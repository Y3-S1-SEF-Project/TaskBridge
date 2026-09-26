import 'package:flutter/material.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../home/widgets/booking_card_widget.dart';
import '../models/coordination_models.dart';
import '../models/planning_models.dart';
import '../services/coordination_api.dart';

/// Screen C21: Agent 3 (Coordination Agent) - Quotation & Booking Proposal
/// Allows customer to inspect AI recommendation, choose among candidate providers,
/// view their hourly rates, and dispatch a job proposal awaiting provider confirmation.
class QuotationProposalPage extends StatefulWidget {
  final JobPlan jobPlan;
  final BookingProposalResponse proposalResponse;
  final AuthUser? user;

  const QuotationProposalPage({
    super.key,
    required this.jobPlan,
    required this.proposalResponse,
    this.user,
  });

  @override
  State<QuotationProposalPage> createState() => _QuotationProposalPageState();
}

class _QuotationProposalPageState extends State<QuotationProposalPage> {
  late BookingProposalResponse _proposal;
  AuthUser? _user;
  int _selectedProviderIndex = 0;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _proposal = widget.proposalResponse;
    _user = widget.user;
    if (_user == null) {
      AuthApi.getCachedUser().then((u) {
        if (mounted && u != null) {
          setState(() => _user = u);
        }
      });
    }

    final quotes = _proposal.allQuotations;
    final recIndex = quotes.indexWhere((q) => q.isRecommended);
    if (recIndex != -1) {
      _selectedProviderIndex = recIndex;
    } else {
      _selectedProviderIndex = 0;
    }
  }

  ProviderQuotation get _selectedProvider {
    final quotes = _proposal.allQuotations;
    if (quotes.isEmpty) return _proposal.winningQuotation;
    if (_selectedProviderIndex >= 0 && _selectedProviderIndex < quotes.length) {
      return quotes[_selectedProviderIndex];
    }
    return quotes.first;
  }

  Future<void> _onSendProposal() async {
    setState(() => _isSending = true);

    try {
      final selected = _selectedProvider;
      final scheduleText = widget.jobPlan.scheduledTime.isNotEmpty
          ? '${widget.jobPlan.scheduledDate} (${widget.jobPlan.scheduledTime}) · ${widget.jobPlan.location}'
          : '${widget.jobPlan.scheduledDate} · ${widget.jobPlan.location}';

      final custName = (_user?.fullName.isNotEmpty == true)
          ? _user!.fullName
          : (_proposal.bookingProposal.customerName.isNotEmpty &&
                  _proposal.bookingProposal.customerName.toLowerCase() != 'customer'
              ? _proposal.bookingProposal.customerName
              : 'Customer');

      final custId = _user?.id ?? _proposal.bookingProposal.customerId;

      final booking = BookingDetails(
        bookingReference: _proposal.bookingProposal.bookingReference,
        serviceTitle: widget.jobPlan.serviceTitle,
        providerName: selected.fullName,
        customerId: custId,
        customerName: custName,
        location: widget.jobPlan.location ?? 'Colombo',
        schedule: scheduleText,
        price: selected.quotedPrice,
        priceFormatted: 'Rs. ${selected.quotedPrice.toInt()}/hr',
        status: 'Requested',
      );

      final success = await CoordinationApi.createQuotationRequest(
        booking: booking,
        category: widget.jobPlan.category,
        providerId: selected.providerId,
        customerId: custId,
        customerName: custName,
      );

      if (!mounted) return;
      setState(() => _isSending = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Job proposal sent to ${selected.fullName}! They will confirm their arrival time shortly.',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );

        // Requirement: Navigate back to Home page
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending proposal: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final quotes = _proposal.allQuotations;
    final selected = _selectedProvider;

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
                    // ── Back Button ──
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
                      'AI COORDINATION',
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),

                    // ── Title ──
                    Text(
                      'Job Proposal &\nQuotation Selection',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select a provider to send your proposal. The provider will review your schedule and confirm their arrival time and quote.',
                      style: TextStyle(
                        fontSize: 14,
                        color: palette.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // ── Agent 3 Recommendation Card ──
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.25),
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: palette.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Recommended by AI',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: palette.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _proposal.recommendationReason,
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.text,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // ── Section: Providers List ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Providers (${quotes.length})',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                        Text(
                          'Tap to select',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    ...quotes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final q = entry.value;
                      final isSelected = index == _selectedProviderIndex;
                      return _buildProviderCard(
                        q: q,
                        isSelected: isSelected,
                        palette: palette,
                        onTap: () {
                          setState(() => _selectedProviderIndex = index);
                        },
                      );
                    }),

                    const SizedBox(height: AppSpacing.s20),

                    // ── Section 2: Selected Proposal Preview ──
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 18,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Proposal to Send',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Figma BookingCard in Requested State
                    BookingCardWidget(
                      title: widget.jobPlan.serviceTitle,
                      providerName: selected.fullName,
                      reference: _proposal.bookingProposal.bookingReference,
                      schedule: widget.jobPlan.scheduledTime.isNotEmpty
                          ? '${widget.jobPlan.scheduledDate} (${widget.jobPlan.scheduledTime}) · ${widget.jobPlan.location}'
                          : '${widget.jobPlan.scheduledDate} · ${widget.jobPlan.location}',
                      price: 'Rs. ${selected.quotedPrice.toInt()}/hr',
                      status: BookingStatus.requested,
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // Human-in-the-Loop note
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border, width: 0.8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'The provider will review your requested time and location. They will confirm their exact attendance time and final quotation before the appointment is booked.',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.muted,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s24),
                  ],
                ),
              ),
            ),

            // ── Sticky Bottom Button: Send Job Proposal ──
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
                  onPressed: _isSending ? null : _onSendProposal,
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Send Proposal to ${selected.fullName.split(' ').first}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
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
    );
  }

  Widget _buildProviderCard({
    required ProviderQuotation q,
    required bool isSelected,
    required AppPalette palette,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primary.withValues(alpha: 0.05)
              : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? palette.primary : palette.border,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Radio/Check circle
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? palette.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? palette.primary : palette.muted,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),

                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: palette.primary.withValues(alpha: 0.15),
                  child: Text(
                    q.fullName.isNotEmpty
                        ? q.fullName.substring(0, 1).toUpperCase()
                        : 'P',
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              q.fullName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            color: palette.primary,
                            size: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '★ ${q.rating.toStringAsFixed(1)} (${q.reviewCount}) · ${q.distanceKm} km away',
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                    ],
                  ),
                ),

                // Hourly Rate
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs. ${q.quotedPrice.toInt()}/hr',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? palette.primary : palette.text,
                      ),
                    ),
                    Text(
                      'Hourly Rate',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (q.isRecommended) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: palette.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Top Recommendation',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

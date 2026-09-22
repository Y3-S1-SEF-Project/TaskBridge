import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../home/pages/home_page.dart';
import '../../home/widgets/booking_card_widget.dart';
import '../models/coordination_models.dart';
import '../models/planning_models.dart';
import '../services/coordination_api.dart';

/// Screen C21: Agent 3 (Coordination Agent) - Quotation & Booking Proposal
/// Enforces Human-in-the-Loop (HITL) approval before confirming bookings.
class QuotationProposalPage extends StatefulWidget {
  final JobPlan jobPlan;
  final BookingProposalResponse proposalResponse;

  const QuotationProposalPage({
    super.key,
    required this.jobPlan,
    required this.proposalResponse,
  });

  @override
  State<QuotationProposalPage> createState() => _QuotationProposalPageState();
}

class _QuotationProposalPageState extends State<QuotationProposalPage> {
  late BookingProposalResponse _proposal;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _proposal = widget.proposalResponse;
  }

  Future<void> _onAcceptBooking() async {
    setState(() => _isConfirming = true);

    try {
      final success = await CoordinationApi.confirmBooking(
        booking: _proposal.bookingProposal,
        category: widget.jobPlan.category,
        providerId: _proposal.winningQuotation.providerId,
      );

      if (!mounted) return;
      setState(() {
        _isConfirming = false;
      });

      if (success) {
        _showBookingSuccessModal();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming booking: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showBookingSuccessModal() {
    final palette = AppPalette.of(context);
    final booking = _proposal.bookingProposal;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s24,
              vertical: AppSpacing.s20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: palette.primary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Booking Confirmed!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your appointment with ${booking.providerName} has been officially locked and scheduled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Figma BookingCard in Confirmed State
                BookingCardWidget(
                  title: booking.serviceTitle,
                  providerName: booking.providerName,
                  reference: booking.bookingReference,
                  schedule: booking.schedule,
                  price: booking.priceFormatted,
                  status: BookingStatus.upcoming,
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomePage()),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Done & Return to Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final booking = _proposal.bookingProposal;
    final quotes = _proposal.allQuotations;

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
                      'COORDINATION AGENT',
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
                      'Quotation &\nBooking Proposal',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // ── Agent 3 Explainable AI (XAI) Recommendation Card ──
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
                                'Recommended by Agent 3',
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

                    // ── Section 1: Submitted Quotations ──
                    Text(
                      'Submitted Quotations (${quotes.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    ...quotes.map((q) => _buildQuotationCard(q, palette)),

                    const SizedBox(height: AppSpacing.s24),

                    // ── Section 2: Final Booking Proposal ──
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 18,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Booking Proposal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Exact Figma BookingCard Component
                    BookingCardWidget(
                      title: booking.serviceTitle,
                      providerName: booking.providerName,
                      reference: booking.bookingReference,
                      schedule: booking.schedule,
                      price: booking.priceFormatted,
                      status: BookingStatus.upcoming,
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // Human-in-the-Loop governance note
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Human-in-the-Loop Governance: Agent 3 prepares optimal proposals but never finalizes charges without your explicit consent.',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.muted,
                                height: 1.4,
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

            // ── Sticky Bottom Button: Accept & Confirm Booking ──
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
                  onPressed: _isConfirming ? null : _onAcceptBooking,
                  child: _isConfirming
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Accept Quotation & Confirm Booking',
                              style: TextStyle(
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

  Widget _buildQuotationCard(ProviderQuotation q, AppPalette palette) {
    final isWinner = q.isRecommended;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner ? palette.primary : palette.border,
          width: isWinner ? 1.8 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: palette.primary.withValues(alpha: 0.15),
                child: Text(
                  q.fullName.isNotEmpty
                      ? q.fullName.substring(0, 1).toUpperCase()
                      : 'P',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${q.quotedPrice.toInt()}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isWinner ? palette.primary : palette.text,
                    ),
                  ),
                  if (isWinner)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Best Fit Offer',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: palette.primary),
              const SizedBox(width: 6),
              Text(
                'Available: ${q.availableTime}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ],
          ),
          if (q.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              q.notes,
              style: TextStyle(fontSize: 12, color: palette.muted, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../models/dispute_model.dart';
import '../services/disputes_api.dart';

class CustomerDisputesPage extends StatefulWidget {
  final AuthUser? user;

  const CustomerDisputesPage({super.key, this.user});

  @override
  State<CustomerDisputesPage> createState() => _CustomerDisputesPageState();
}

class _CustomerDisputesPageState extends State<CustomerDisputesPage> {
  List<DisputeItem> _disputes = [];
  bool _isLoading = true;
  AuthUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() => _isLoading = true);
    _currentUser = widget.user ?? await AuthApi.getCachedUser();

    final list = await DisputesApi.getCustomerDisputes(
      customerId: _currentUser?.id,
      customerName: _currentUser?.fullName,
    );

    if (mounted) {
      setState(() {
        _disputes = list;
        _isLoading = false;
      });
    }
  }

  void _showDisputeDetailsModal(DisputeItem dispute) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final palette = AppPalette.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconsax.shield_security,
                          color: dispute.isResolved
                              ? Colors.green
                              : Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${dispute.disputeReference}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusChip(dispute),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Linked to Booking #${dispute.bookingReference} · Filed ${_formatDate(dispute.createdAt)}',
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
                const SizedBox(height: 16),

                // Service & Specialist Info Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispute.serviceTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Specialist: ${dispute.providerName} · ${dispute.category}',
                        style: TextStyle(fontSize: 12.5, color: palette.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fee: Rs. ${dispute.feeAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Customer statement
                Text(
                  'DISPUTE REASON & DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispute.reasonCategory,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dispute.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.text,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Desired Resolution: ${dispute.desiredResolution}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Admin Resolution Outcome (if resolved)
                if (dispute.isResolved ||
                    dispute.resolutionSummary?.isNotEmpty == true) ...[
                  Text(
                    'ADMIN MEDIATION OUTCOME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dispute.resolutionAction == 'Cancelled'
                                  ? 'Booking Cancelled & Refunded'
                                  : 'Issue Resolved & Completed',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                        if (dispute.resolutionSummary != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            dispute.resolutionSummary!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.green.shade900,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (dispute.resolvedAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Resolved on ${_formatDate(dispute.resolvedAt!)} by ${dispute.resolvedByAdminName ?? "Operations"}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: Colors.amber.shade900,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Admin investigation in progress. The job is on freeze until an administrator concludes the mediation.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.brown.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Close Details',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildStatusChip(DisputeItem dispute) {
    Color bg;
    Color fg;
    String text;

    if (dispute.isResolved) {
      bg = Colors.green.shade100;
      fg = Colors.green.shade800;
      text = 'Resolved';
    } else if (dispute.isCancelled) {
      bg = Colors.grey.shade200;
      fg = Colors.grey.shade800;
      text = 'Cancelled';
    } else {
      bg = Colors.amber.shade100;
      fg = Colors.amber.shade900;
      text = 'Under Admin Review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrowLeft, color: palette.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Disputes',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: palette.text,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _disputes.isEmpty
          ? _buildEmptyState(palette)
          : RefreshIndicator(
              onRefresh: _loadDisputes,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.s16),
                itemCount: _disputes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final disp = _disputes[i];
                  return _buildDisputeCard(disp, palette);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState(AppPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.soft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.shield_tick,
                size: 36,
                color: palette.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Disputes on Record',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All your jobs are in good standing. If you encounter quality issues on a service completion, you can raise a direct dispute from the Quality Sign-Off screen.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: palette.muted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisputeCard(DisputeItem disp, AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(
          color: disp.isPending ? Colors.red.shade200 : palette.border,
          width: disp.isPending ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDisputeDetailsModal(disp),
          borderRadius: BorderRadius.circular(AppRadius.r16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconsax.shield_security,
                          size: 16,
                          color: disp.isResolved
                              ? Colors.green
                              : Colors.red.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '#${disp.disputeReference}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· Booking #${disp.bookingReference}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusChip(disp),
                  ],
                ),
                const SizedBox(height: 10),

                // Service & Reason
                Text(
                  disp.serviceTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reason: ${disp.reasonCategory}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  disp.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: palette.muted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Footer row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Specialist: ${disp.providerName}',
                      style: TextStyle(fontSize: 11.5, color: palette.muted),
                    ),
                    Row(
                      children: [
                        Text(
                          'View Case Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: palette.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: palette.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

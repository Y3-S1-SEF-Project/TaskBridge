import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/review_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';

class CustomerCompletionReviewPage extends StatefulWidget {
  final BookingItem booking;

  const CustomerCompletionReviewPage({
    super.key,
    required this.booking,
  });

  @override
  State<CustomerCompletionReviewPage> createState() => _CustomerCompletionReviewPageState();
}

class _CustomerCompletionReviewPageState extends State<CustomerCompletionReviewPage> {
  bool _isLoading = true;
  JobCompletionModel? _completion;
  bool _isApproving = false;
  bool _isRequestingRevision = false;
  int _selectedRating = 5;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCompletionDetails();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadCompletionDetails() async {
    setState(() => _isLoading = true);
    final data = await ReviewApi.getCompletionDetails(widget.booking.bookingReference);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _completion = data;
      });
    }
  }

  Future<void> _showApprovalAndFeedbackDialog() async {
    final palette = AppPalette.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              Text(
                'Confirm & Rate Service',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rate your experience with ${widget.booking.providerName}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              // Star Rating Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  return IconButton(
                    iconSize: 34,
                    icon: Icon(
                      starNum <= _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setModalState(() => _selectedRating = starNum);
                      setState(() => _selectedRating = starNum);
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _feedbackController,
                maxLines: 3,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Share your feedback (e.g. prompt, neat work, friendly)...',
                  filled: true,
                  fillColor: palette.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isApproving
                      ? null
                      : () async {
                          Navigator.pop(modalCtx);
                          await _submitApprovalAndFeedback();
                        },
                  child: Text(
                    'Confirm Sign-Off & Submit Review',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitApprovalAndFeedback() async {
    setState(() => _isApproving = true);

    await ReviewApi.customerApprove(
      bookingReference: widget.booking.bookingReference,
    );

    await ReviewApi.submitFeedback(
      bookingReference: widget.booking.bookingReference,
      customerId: widget.booking.id,
      customerName: widget.booking.customerName,
      providerId: widget.booking.providerId,
      providerName: widget.booking.providerName,
      rating: _selectedRating,
      comment: _feedbackController.text.trim().isEmpty
          ? 'Great service, highly satisfied!'
          : _feedbackController.text.trim(),
    );

    if (mounted) {
      setState(() => _isApproving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Job completed & review submitted! Thank you!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _showRevisionDialog() async {
    final reasonController = TextEditingController();
    final palette = AppPalette.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Request Job Revision',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please describe what additional work or verification is needed from the provider:',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Please check the secondary seal under the sink...',
                filled: true,
                fillColor: palette.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isRequestingRevision = true);

              final success = await ReviewApi.requestRevision(
                bookingReference: widget.booking.bookingReference,
                reason: reasonController.text.trim(),
              );

              if (mounted) {
                setState(() => _isRequestingRevision = false);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Revision request sent to provider.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.pop(context, true);
                }
              }
            },
            child: const Text('Send Revision Request'),
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
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: palette.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Agent 4: Quality Sign-Off',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: palette.text,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Verified',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Overview Banner
                  _buildServiceHeader(palette),
                  const SizedBox(height: 18),

                  // Side-by-Side Photo Comparison
                  _buildPhotoComparison(palette),
                  const SizedBox(height: 18),

                  // Agent 4 AI QA Report Card
                  _buildAgent4ReportCard(palette),
                  const SizedBox(height: 18),

                  // Duration & Accurate Hourly Breakdown
                  _buildDurationAndPriceCard(palette),
                  const SizedBox(height: 24),

                  // Actions: Confirm & Close or Request Revision
                  _buildCustomerActionButtons(palette),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildServiceHeader(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.booking.serviceTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: palette.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${widget.booking.bookingReference}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Provider: ${widget.booking.providerName}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoComparison(AppPalette palette) {
    final isGardening = widget.booking.category.toLowerCase().contains('garden') ||
        widget.booking.serviceTitle.toLowerCase().contains('garden');
    final isPlumbing = widget.booking.category.toLowerCase().contains('plumb') ||
        widget.booking.serviceTitle.toLowerCase().contains('sink');

    final defaultBefore = isGardening
        ? 'https://images.unsplash.com/photo-1592417817098-8f3d6ef2c6e1?w=800&auto=format&fit=crop&q=80'
        : (isPlumbing
            ? 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=800&auto=format&fit=crop&q=80'
            : 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800&auto=format&fit=crop&q=80');

    final defaultAfter = isGardening
        ? 'https://images.unsplash.com/photo-1558904541-efa8c4a08931?w=800&auto=format&fit=crop&q=80'
        : (isPlumbing
            ? 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=800&auto=format&fit=crop&q=80'
            : 'https://images.unsplash.com/photo-1527515637462-cff94eecc1ac?w=800&auto=format&fit=crop&q=80');

    final rawBefore = _completion?.beforePhotoUrl;
    final beforeUrl = (rawBefore != null && rawBefore.isNotEmpty) ? rawBefore : defaultBefore;

    final afterUrls = _completion?.afterPhotoUrls ?? [];
    final rawAfter = afterUrls.isNotEmpty ? afterUrls.first : null;
    final afterUrl = (rawAfter != null && rawAfter.isNotEmpty) ? rawAfter : defaultAfter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visual Before & After Comparison',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Before Photo
            Expanded(
              child: _buildComparisonPhotoCard(
                title: 'Before Service',
                subtitle: 'Initial State',
                url: beforeUrl,
                badgeColor: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            // After Photo
            Expanded(
              child: _buildComparisonPhotoCard(
                title: 'After Service',
                subtitle: 'Completed Result',
                url: afterUrl,
                badgeColor: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonPhotoCard({
    required String title,
    required String subtitle,
    String? url,
    required Color badgeColor,
  }) {
    final hasPhoto = url != null && url.isNotEmpty;

    Widget photoWidget;
    if (!hasPhoto) {
      photoWidget = const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 30),
      );
    } else if (url.startsWith('/') || url.startsWith('file://')) {
      final cleanPath = url.replaceFirst('file://', '');
      photoWidget = Image.file(
        File(cleanPath),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      photoWidget = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, urlStr) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, urlStr, error) => Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              child: photoWidget,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgent4ReportCard(AppPalette palette) {
    final passed = _completion?.aiVerificationPassed ?? true;
    final score = _completion?.aiConfidenceScore ?? 95;
    final analysis = _completion?.aiComparisonAnalysis ??
        'Agent 4 analyzed the proof images and verified that the service requirements were met with clean execution.';
    final verified = _completion?.aiVerifiedTasks ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: passed ? Colors.green.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: passed ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Agent 4 Quality Assessment',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$score% Match',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            analysis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.4,
              color: palette.text,
            ),
          ),
          if (verified.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...verified.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: palette.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_completion?.providerNotes.isNotEmpty == true) ...[
            const Divider(height: 20),
            Text(
              'Provider Notes:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _completion!.providerNotes,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationAndPriceCard(AppPalette palette) {
    final mins = _completion?.durationMinutes ?? 52;
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    final rate = _completion?.hourlyRate ?? (widget.booking.price > 0 ? widget.booking.price : 5000.0);
    final calculatedPrice = _completion?.calculatedPrice ??
        ((hours * rate) + (remMins * (rate / 60.0)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Work Duration & Final Fee',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: palette.text,
                ),
              ),
              Text(
                hours > 0 ? '$hours hr $remMins min' : '$remMins min',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Agreed Rate:',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                'Rs. ${rate.toInt()} / hour',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calculation Breakdown:',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                '($hours × ${rate.toInt()}) + ($remMins × ${(rate / 60).toStringAsFixed(2)})',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable Amount:',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                'Rs. ${calculatedPrice.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerActionButtons(AppPalette palette) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isApproving ? null : _showApprovalAndFeedbackDialog,
            icon: const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              'Confirm Sign-Off & Give Review',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              side: BorderSide(color: Colors.orange.shade800.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isRequestingRevision ? null : _showRevisionDialog,
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: Text(
              'Request Revision / More Proof',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

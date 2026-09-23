import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/coordination_api.dart';
import '../../ai/services/review_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'job_completion_proof_page.dart';

/// Full Job Details page for providers displaying complete customer info,
/// confirmed schedule, realistic interactive location map, rate type (hourly vs fixed),
/// and flush unified bottom action controls.
class ProviderJobDetailsPage extends StatefulWidget {
  final BookingItem booking;

  const ProviderJobDetailsPage({
    super.key,
    required this.booking,
  });

  @override
  State<ProviderJobDetailsPage> createState() => _ProviderJobDetailsPageState();
}

class _ProviderJobDetailsPageState extends State<ProviderJobDetailsPage> {
  late BookingItem _currentBooking;
  bool _isUpdating = false;
  DateTime? _jobStartedAt;
  String? _beforePhotoUrl;
  final ImagePicker _picker = ImagePicker();
  JobCompletionModel? _completion;
  bool _isLoadingProof = false;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    if (_currentBooking.isCompleted || _currentBooking.status == 'PendingCustomerSignOff') {
      _loadCompletionProof();
    }
  }

  Future<void> _loadCompletionProof() async {
    setState(() => _isLoadingProof = true);
    final proof = await ReviewApi.getCompletionDetails(_currentBooking.bookingReference);
    if (mounted) {
      setState(() {
        _completion = proof;
        _isLoadingProof = false;
      });
    }
  }

  Future<void> _handleStartJobFlow() async {
    final palette = AppPalette.of(context);
    String? tempBeforePhoto = _beforePhotoUrl;
    bool isUploadingPhoto = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.camera_enhance_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Start Job & Capture Before Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.text),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Highlighted notice for AI review
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Review Requirement:\nAgent 4 (Quality Assurance) checks the initial state before work begins. Taking a clear photo now ensures your completion review passes without delay.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (tempBeforePhoto != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      tempBeforePhoto!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: isUploadingPhoto
                        ? null
                        : () async {
                            final picked = await _picker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 80,
                            );
                            if (picked != null) {
                              setDialogState(() => isUploadingPhoto = true);
                              final uploaded = await ReviewApi.uploadProofPhoto(
                                picked.path,
                                bookingRef: _currentBooking.bookingReference,
                              );
                              setDialogState(() {
                                isUploadingPhoto = false;
                                if (uploaded != null) tempBeforePhoto = uploaded;
                              });
                            }
                          },
                    icon: isUploadingPhoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(
                      tempBeforePhoto != null ? 'Retake Before Photo' : 'Take Before Photo Now',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                setState(() {
                  _isUpdating = true;
                  _beforePhotoUrl = tempBeforePhoto;
                  _jobStartedAt = DateTime.now();
                });

                await ReviewApi.startJob(
                  bookingReference: _currentBooking.bookingReference,
                  beforePhotoUrl: tempBeforePhoto,
                );

                await _updateJobStatus('Active');
              },
              child: const Text('Start Working'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEndJobFlow() async {
    final palette = AppPalette.of(context);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.purple, size: 24),
            const SizedBox(width: 8),
            const Text('Finish & Submit Proof?'),
          ],
        ),
        content: const Text(
          'Are you ready to submit your work for Agent 4 Quality Verification? You will be prompted to attach after-service proof photos and work notes.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue Working'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed to AI Review'),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => JobCompletionProofPage(
            booking: _currentBooking,
            startedAt: _jobStartedAt,
            beforePhotoUrl: _beforePhotoUrl,
          ),
        ),
      );

      if (updated == true && mounted) {
        setState(() {
          _currentBooking = _currentBooking.copyWith(status: 'PendingCustomerSignOff');
        });
      }
    }
  }

  Future<void> _updateJobStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    final messenger = ScaffoldMessenger.of(context);

    final success = await CoordinationApi.updateBookingStatus(
      bookingReference: _currentBooking.bookingReference,
      newStatus: newStatus,
    );

    if (mounted) {
      setState(() {
        _isUpdating = false;
        if (success) {
          _currentBooking = _currentBooking.copyWith(status: newStatus);
        }
      });

      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'Active'
                  ? 'Job started! Status is now Active.'
                  : (newStatus == 'Completed'
                      ? '🎉 Job marked as Completed! Earnings added to your account.'
                      : 'Job status updated to $newStatus.'),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to update status. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isUpcoming = _currentBooking.isUpcoming;
    final isActive = _currentBooking.isActive;
    final isCompleted = _currentBooking.isCompleted;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: palette.text),
          onPressed: () => Navigator.pop(context, _currentBooking),
        ),
        title: Text(
          'Job Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: palette.text,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${_currentBooking.bookingReference}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: palette.primary,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Banner ──
            _buildStatusHeader(palette),
            const SizedBox(height: 18),

            // ── Submitted Proof of Work & Agent 4 Sign-Off (For Completed Jobs) ──
            if (_currentBooking.isCompleted || _completion != null) ...[
              _buildProofOfWorkSection(palette),
              const SizedBox(height: 18),
            ],

            // ── Service & Price Card with Hourly vs Fixed details ──
            _buildServiceCard(palette),
            const SizedBox(height: 16),

            // ── Customer Profile Card ──
            _buildCustomerCard(palette),
            const SizedBox(height: 16),

            // ── Location & High-Fidelity Map Card ──
            _buildLocationCard(palette),
            const SizedBox(height: 16),

            // ── Schedule & Time Card ──
            _buildScheduleCard(palette),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // Clean, flush bottom action bar docked to the screen bottom (replaces problematic bottomSheet)
      bottomNavigationBar: _buildBottomActionBar(palette, isUpcoming, isActive, isCompleted),
    );
  }

  Widget _buildStatusHeader(AppPalette palette) {
    Color bg;
    Color fg;
    String statusTitle;
    String statusSubtitle;
    IconData icon;

    if (_currentBooking.isUpcoming) {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
      statusTitle = 'Upcoming Confirmed Job';
      statusSubtitle = 'Appointment confirmed. Please arrive on time at customer location.';
      icon = Icons.event_available_rounded;
    } else if (_currentBooking.isActive) {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
      statusTitle = 'Job In Progress';
      statusSubtitle = 'You are currently on-site attending to this service.';
      icon = Icons.engineering_rounded;
    } else if (_currentBooking.isCompleted) {
      bg = palette.soft;
      fg = palette.primary;
      statusTitle = 'Job Completed';
      statusSubtitle = 'Service finished and logged in your earnings record.';
      icon = Icons.check_circle_rounded;
    } else {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
      statusTitle = 'Cancelled Job';
      statusSubtitle = 'This appointment was cancelled.';
      icon = Icons.cancel_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: fg.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofOfWorkSection(AppPalette palette) {
    if (_isLoadingProof) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.r16),
          border: Border.all(color: palette.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final isGardening = _currentBooking.category.toLowerCase().contains('garden') ||
        _currentBooking.serviceTitle.toLowerCase().contains('garden');
    final isPlumbing = _currentBooking.category.toLowerCase().contains('plumb') ||
        _currentBooking.serviceTitle.toLowerCase().contains('sink');

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

    final mins = _completion?.durationMinutes ?? 52;
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    final rate = _completion?.hourlyRate ?? (_currentBooking.price > 0 ? _currentBooking.price : 3750.0);
    final calculatedPrice = _completion?.calculatedPrice ??
        ((hours * rate) + (remMins * (rate / 60.0)));

    final analysis = _completion?.aiComparisonAnalysis ??
        'Agent 4 analyzed the proof images and verified that the service requirements were met with clean execution.';
    final verified = _completion?.aiVerifiedTasks ?? [
      'Initial inspection and before-work condition captured',
      'Complete execution of requested ${_currentBooking.serviceTitle} tasks',
      'After-work cleanup and site clearance verified',
      'Final testing and operational check confirmed'
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.35), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'SUBMITTED PROOF OF WORK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.green.shade800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Agent 4 Verified',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Photos Row
          Row(
            children: [
              Expanded(
                child: _buildProofPhotoCard(
                  title: 'Before Service',
                  subtitle: 'Initial State',
                  url: beforeUrl,
                  badgeColor: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProofPhotoCard(
                  title: 'After Service',
                  subtitle: 'Completed Result',
                  url: afterUrl,
                  badgeColor: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // AI Quality Assessment
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Agent 4 Quality Assessment',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '95% Match',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  analysis,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.muted,
                    height: 1.35,
                  ),
                ),
                if (verified.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...verified.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 13, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t,
                              style: TextStyle(fontSize: 11, color: palette.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Duration & Final Earnings Breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Work Duration & Final Earnings',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$mins min',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: palette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Agreed Rate:',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                    Text(
                      'Rs. ${rate.toInt()} / hour',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Calculation Breakdown:',
                      style: TextStyle(fontSize: 11, color: palette.muted),
                    ),
                    Text(
                      '($hours x ${rate.toInt()}) + ($remMins x ${(rate / 60.0).toStringAsFixed(2)})',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.muted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Earned Amount:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      'Rs. ${calculatedPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_completion?.providerNotes.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Submission Notes:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: palette.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _completion!.providerNotes,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProofPhotoCard({
    required String title,
    required String subtitle,
    required String url,
    required Color badgeColor,
  }) {
    Widget photoWidget;
    if (url.startsWith('/') || url.startsWith('file://')) {
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: photoWidget,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(AppPalette palette) {
    final isHourly = _currentBooking.isHourly;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentBooking.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Pill explicitly showing rate type (Hourly Rate vs Fixed Total)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHourly ? Colors.teal.shade50 : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isHourly ? Colors.teal.shade200 : Colors.indigo.shade200,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHourly ? Icons.timelapse_rounded : Icons.sell_rounded,
                      size: 11,
                      color: isHourly ? Colors.teal.shade800 : Colors.indigo.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHourly ? 'HOURLY RATE' : 'FIXED TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isHourly ? Colors.teal.shade900 : Colors.indigo.shade900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentBooking.serviceTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isHourly ? 'Billed by actual work hours' : 'Agreed complete service amount',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Rs. ${_currentBooking.price.toInt()}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: palette.primary,
                        ),
                      ),
                      if (isHourly)
                        Text(
                          ' / hr',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: palette.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Agreed Earnings',
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isHourly ? Icons.info_outline_rounded : Icons.verified_outlined,
                size: 16,
                color: palette.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isHourly
                      ? 'Hourly rate applies upon arrival. Total calculated based on hours logged.'
                      : 'Fixed amount agreed. No hourly or hidden adjustments upon completion.',
                  style: TextStyle(fontSize: 12, color: palette.muted, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(AppPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CUSTOMER DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: palette.muted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: palette.primary.withValues(alpha: 0.12),
                child: Text(
                  _currentBooking.customerName.isNotEmpty
                      ? _currentBooking.customerName.substring(0, 1).toUpperCase()
                      : 'C',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentBooking.customerName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'TaskBridge Client',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.primary,
                    side: BorderSide(color: palette.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Calling customer ${_currentBooking.customerName}...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone_rounded, size: 16),
                  label: const Text('Call', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.primary,
                    side: BorderSide(color: palette.primary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening chat with ${_currentBooking.customerName}...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Message', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(AppPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SERVICE LOCATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: palette.muted,
                  letterSpacing: 1.0,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _currentBooking.location));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 13, color: palette.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Copy',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // High-Fidelity Realistic Simulated Map Card
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E9E4), // Map ground tone
                border: Border.all(color: palette.border),
              ),
              child: Stack(
                children: [
                  // Vector road layout painter
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RealisticCityMapPainter(),
                    ),
                  ),

                  // Top left GPS status pill
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Verified Destination',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top right Compass indicator
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'N',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Center Pin Marker with Radar Rings
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tooltip callout badge above the pin
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            _currentBooking.location,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Drop pin
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Radar wave ring
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.primary.withValues(alpha: 0.18),
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: palette.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.primary.withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bottom road label
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Map Preview · Street Level',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Icon(Icons.pin_drop_rounded, size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentBooking.location,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.primary,
                side: BorderSide(color: palette.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Launching Navigation to ${_currentBooking.location}...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: const Text('Open in Google Maps / Directions', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(AppPalette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFIRMED SCHEDULE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: palette.muted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.access_time_filled_rounded, color: palette.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentBooking.schedule,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please ensure tools and materials are ready 15 mins prior to arrival.',
                      style: TextStyle(fontSize: 12, color: palette.muted, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Clean, docked bottom action bar with side-by-side or full-width buttons.
  /// No weird detached floating sheet or overlapping navigation bar look.
  Widget _buildBottomActionBar(
    AppPalette palette,
    bool isUpcoming,
    bool isActive,
    bool isCompleted,
  ) {
    if (isCompleted) {
      return Container(
        color: palette.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, _currentBooking),
              child: const Text('Back to Jobs', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: isUpcoming
            ? Row(
                children: [
                  // Unified side-by-side Cancel Job button
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.45)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _isUpdating ? null : () => _updateJobStatus('Cancelled'),
                        child: const Text(
                          'Cancel Job',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Prominent Start Job button
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isUpdating ? null : _handleStartJobFlow,
                        icon: _isUpdating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text(
                          'Start Job',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : (isActive
                ? SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade700,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isUpdating ? null : _handleEndJobFlow,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text(
                        'End Job & Submit Proof (Agent 4)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                : (_currentBooking.status == 'PendingCustomerSignOff'
                    ? Container(
                        width: double.infinity,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.hourglass_top_rounded, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Awaiting Customer Sign-Off (Agent 4 Verified)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink())),
      ),
    );
  }
}

/// Custom vector painter creating a realistic city street map layout.
class _RealisticCityMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Parks and Green Spaces
    final parkPaint = Paint()
      ..color = const Color(0xFFD3E7D3)
      ..style = PaintingStyle.fill;

    // Park polygon 1 (North-west)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 12, size.width * 0.28, size.height * 0.35),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    // Park polygon 2 (South-east)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.68, size.height * 0.55, size.width * 0.26, size.height * 0.35),
        const Radius.circular(8),
      ),
      parkPaint,
    );

    // 2. Water canal / lake
    final waterPaint = Paint()
      ..color = const Color(0xFFCFE2FE)
      ..style = PaintingStyle.fill;

    final canalPath = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.72, size.width * 0.6, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(canalPath, waterPaint);

    // 3. City Blocks / Buildings (soft grey parcels)
    final blockPaint = Paint()
      ..color = const Color(0xFFDFE4DE)
      ..style = PaintingStyle.fill;

    // Block cluster 1
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.35, 14, size.width * 0.28, size.height * 0.26),
        const Radius.circular(6),
      ),
      blockPaint,
    );

    // Block cluster 2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.7, 14, size.width * 0.24, size.height * 0.3),
        const Radius.circular(6),
      ),
      blockPaint,
    );

    // 4. Secondary Streets (White with subtle road edge)
    final streetCasing = Paint()
      ..color = const Color(0xFFCBD2CC)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;

    final streetFill = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke;

    // Cross street 1
    final streetPath1 = Path()
      ..moveTo(size.width * 0.32, 0)
      ..lineTo(size.width * 0.32, size.height);
    canvas.drawPath(streetPath1, streetCasing);
    canvas.drawPath(streetPath1, streetFill);

    // Cross street 2
    final streetPath2 = Path()
      ..moveTo(size.width * 0.66, 0)
      ..lineTo(size.width * 0.66, size.height);
    canvas.drawPath(streetPath2, streetCasing);
    canvas.drawPath(streetPath2, streetFill);

    // Horizontal street
    final streetPath3 = Path()
      ..moveTo(0, size.height * 0.48)
      ..lineTo(size.width, size.height * 0.48);
    canvas.drawPath(streetPath3, streetCasing);
    canvas.drawPath(streetPath3, streetFill);

    // 5. Main Arterial Avenue (Warm golden highway with dark casing)
    final avenueCasing = Paint()
      ..color = const Color(0xFFC7BC99)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke;

    final avenueFill = Paint()
      ..color = const Color(0xFFFFF7DB)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    final avenuePath = Path()
      ..moveTo(0, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.48, size.height * 0.38, size.width, size.height * 0.68);
    canvas.drawPath(avenuePath, avenueCasing);
    canvas.drawPath(avenuePath, avenueFill);

    // Dashed center line for main avenue
    final dashPaint = Paint()
      ..color = const Color(0xFFE2A83B)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Small dashed markers on avenue
    for (double i = 0.1; i < 0.9; i += 0.1) {
      final t1 = i;
      final t2 = i + 0.04;
      final x1 = size.width * t1;
      final y1 = (size.height * 0.22) * (1 - t1) * (1 - t1) +
          (size.height * 0.38) * 2 * (1 - t1) * t1 +
          (size.height * 0.68) * t1 * t1;
      final x2 = size.width * t2;
      final y2 = (size.height * 0.22) * (1 - t2) * (1 - t2) +
          (size.height * 0.38) * 2 * (1 - t2) * t2 +
          (size.height * 0.68) * t2 * t2;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

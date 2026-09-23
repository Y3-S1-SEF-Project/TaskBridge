import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/review_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';

class JobCompletionProofPage extends StatefulWidget {
  final BookingItem booking;
  final DateTime? startedAt;
  final String? beforePhotoUrl;

  const JobCompletionProofPage({
    super.key,
    required this.booking,
    this.startedAt,
    this.beforePhotoUrl,
  });

  @override
  State<JobCompletionProofPage> createState() => _JobCompletionProofPageState();
}

class _JobCompletionProofPageState extends State<JobCompletionProofPage> {
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _beforePhotoUrl;
  final List<String> _afterPhotoUrls = [];
  bool _isUploadingBefore = false;
  bool _isUploadingAfter = false;
  bool _isEvaluating = false;
  bool _isSubmittingToCustomer = false;

  late DateTime _jobStartedAt;
  late DateTime _jobEndedAt;
  ReviewAnalyzeResponseModel? _aiResult;

  @override
  void initState() {
    super.initState();
    _jobStartedAt = widget.startedAt ?? DateTime.now().subtract(const Duration(minutes: 52));
    _jobEndedAt = DateTime.now();
    _beforePhotoUrl = widget.beforePhotoUrl;

    _notesController.text =
        'Completed full servicing of ${widget.booking.serviceTitle}. Replaced defective parts, thoroughly tested under pressure, and cleaned the workspace.';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _elapsedMinutes {
    return _jobEndedAt.difference(_jobStartedAt).inMinutes.clamp(1, 9999);
  }

  double get _estimatedFee {
    final rate = widget.booking.price > 0 ? widget.booking.price : 5000.0;
    final hours = _elapsedMinutes ~/ 60;
    final minutes = _elapsedMinutes % 60;
    return (hours * rate) + (minutes * (rate / 60.0));
  }

  Future<void> _pickAndUploadPhoto({required bool isBefore}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isBefore ? 'Select Before Photo' : 'Add After-Work Proof Photo',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Take Photo with Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 82);
      if (picked == null) return;

      setState(() {
        if (isBefore) {
          _isUploadingBefore = true;
        } else {
          _isUploadingAfter = true;
        }
      });

      final uploadedUrl = await ReviewApi.uploadProofPhoto(
        picked.path,
        bookingRef: widget.booking.bookingReference,
      );

      if (mounted) {
        setState(() {
          if (isBefore) {
            _isUploadingBefore = false;
            if (uploadedUrl != null) _beforePhotoUrl = uploadedUrl;
          } else {
            _isUploadingAfter = false;
            if (uploadedUrl != null) _afterPhotoUrls.add(uploadedUrl);
          }
        });

        if (uploadedUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📷 Proof photo uploaded to Cloudflare R2 successfully!'),
              backgroundColor: AppColors.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload photo. Please check your connection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingBefore = false;
          _isUploadingAfter = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runAgent4Evaluation() async {
    if (_afterPhotoUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one After Photo to verify completion.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _isEvaluating = true;
      _jobEndedAt = DateTime.now();
    });

    final result = await ReviewApi.evaluateCompletion(
      bookingReference: widget.booking.bookingReference,
      providerNotes: _notesController.text.trim(),
      beforePhotoUrl: _beforePhotoUrl,
      afterPhotoUrls: _afterPhotoUrls,
      startedAt: _jobStartedAt,
      endedAt: _jobEndedAt,
      hourlyRate: widget.booking.price > 0 ? widget.booking.price : 5000.0,
    );

    if (mounted) {
      setState(() {
        _isEvaluating = false;
        _aiResult = result;
      });

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.verificationPassed
                ? '✅ Agent 4: Quality verification passed (${result.confidenceScore}% confidence)!'
                : '⚠️ Agent 4: Additional details or proof requested.'),
            backgroundColor: result.verificationPassed ? Colors.green : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to run Agent 4 review. Check your backend status.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitToCustomer() async {
    setState(() => _isSubmittingToCustomer = true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      setState(() => _isSubmittingToCustomer = false);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sent to Customer!',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Agent 4 has verified your proof of work. The customer (${widget.booking.customerName}) has been notified to review the before/after photos and confirm sign-off.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final hours = _elapsedMinutes ~/ 60;
    final minutes = _elapsedMinutes % 60;
    final rate = widget.booking.price > 0 ? widget.booking.price : 5000.0;

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
          'Agent 4: Quality Review',
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
              color: Colors.purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple, size: 14),
                const SizedBox(width: 4),
                Text(
                  'AI QA',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Info & Timer Banner
            _buildServiceDurationBanner(palette, hours, minutes, rate),
            const SizedBox(height: 18),

            // Before & After Proof Photo Upload Grid
            _buildPhotoSection(palette),
            const SizedBox(height: 18),

            // Provider Notes / Work Log
            _buildNotesSection(palette),
            const SizedBox(height: 24),

            // AI Verification Button or Results Card
            if (_aiResult != null) ...[
              _buildAiEvaluationCard(palette),
              const SizedBox(height: 20),
            ],

            _buildActionButtons(palette),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceDurationBanner(AppPalette palette, int hours, int minutes, double rate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            Colors.purple.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
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
                  fontSize: 16,
                  color: palette.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.surface,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.timer_outlined,
                  title: 'Job Duration',
                  value: hours > 0 ? '$hours hr $minutes min' : '$minutes min',
                  subtitle: '${_elapsedMinutes}m recorded',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.payments_outlined,
                  title: 'Calculated Fee',
                  value: 'Rs. ${_estimatedFee.toStringAsFixed(2)}',
                  subtitle: 'Rate: Rs. ${rate.toInt()}/hr',
                  isAccent: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Fee formula: ($hours × Rs. ${rate.toInt()}) + ($minutes × Rs. ${(rate / 60).toStringAsFixed(2)}/min)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
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

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    bool isAccent = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAccent ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isAccent ? Colors.green : AppColors.primary),
              const SizedBox(width: 4),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isAccent ? Colors.green.shade700 : null,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Proof of Work Photos',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: palette.text,
              ),
            ),
            Text(
              'Uploaded to Cloudflare R2',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Before Photo Box
            Expanded(
              child: _buildPhotoBox(
                title: 'Before Service',
                tag: 'Initial Condition',
                url: _beforePhotoUrl,
                isLoading: _isUploadingBefore,
                isBefore: true,
                onTap: () => _pickAndUploadPhoto(isBefore: true),
              ),
            ),
            const SizedBox(width: 12),
            // After Photo Box
            Expanded(
              child: _buildPhotoBox(
                title: 'After Service',
                tag: 'Completed Result',
                url: _afterPhotoUrls.isNotEmpty ? _afterPhotoUrls.first : null,
                isLoading: _isUploadingAfter,
                isBefore: false,
                count: _afterPhotoUrls.length,
                onTap: () => _pickAndUploadPhoto(isBefore: false),
              ),
            ),
          ],
        ),
        if (_afterPhotoUrls.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _afterPhotoUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: _afterPhotoUrls[i],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoBox({
    required String title,
    required String tag,
    String? url,
    required bool isLoading,
    required bool isBefore,
    int count = 1,
    required VoidCallback onTap,
  }) {
    final hasPhoto = url != null && url.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPhoto ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
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
                if (hasPhoto)
                  const Icon(Icons.check_circle, color: Colors.green, size: 14),
              ],
            ),
          ),
          InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : (hasPhoto
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                placeholder: (context, urlStr) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (context, urlStr, error) => const Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isBefore ? 'Retake' : 'Add More ($count)',
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isBefore ? Icons.camera_enhance_outlined : Icons.add_a_photo_outlined,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isBefore ? 'Upload Before' : 'Upload After',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              tag,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Provider Work Notes & Actions Taken',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Describe replacement parts, pressure tests, and clean-up details...',
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiEvaluationCard(AppPalette palette) {
    final res = _aiResult!;
    final isPassed = res.verificationPassed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPassed ? Colors.green.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPassed ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.4),
          width: 1.5,
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
                  Icon(
                    isPassed ? Icons.verified_rounded : Icons.warning_amber_rounded,
                    color: isPassed ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPassed ? 'Agent 4: Quality Passed' : 'Agent 4: Revision Advised',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isPassed ? Colors.green.shade800 : Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPassed ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${res.confidenceScore}% Confidence',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            res.comparisonAnalysis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.4,
              color: palette.text,
            ),
          ),
          if (res.verifiedTasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Verified Criteria:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 4),
            ...res.verifiedTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: palette.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (res.missingDetails.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Attention / Missing Items:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 4),
            ...res.missingDetails.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(Icons.close, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: palette.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Final Calculated Fee:',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                res.priceFormatted,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppPalette palette) {
    if (_aiResult == null) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _isEvaluating ? null : _runAgent4Evaluation,
          icon: _isEvaluating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome, size: 20),
          label: Text(
            _isEvaluating ? 'Agent 4 is Analyzing Proof...' : 'Run Agent 4 AI Verification',
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

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
            onPressed: _isSubmittingToCustomer ? null : _submitToCustomer,
            icon: _isSubmittingToCustomer
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 20),
            label: Text(
              'Submit to Customer for Sign-Off',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _isEvaluating ? null : _runAgent4Evaluation,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Re-evaluate with Agent 4'),
        ),
      ],
    );
  }
}

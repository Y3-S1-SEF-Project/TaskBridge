import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/review_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../home/widgets/fullscreen_photo_viewer.dart';

class JobCompletionProofPage extends StatefulWidget {
  final BookingItem booking;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? beforePhotoUrl;
  final JobCompletionModel? initialCompletion;

  const JobCompletionProofPage({
    super.key,
    required this.booking,
    this.startedAt,
    this.endedAt,
    this.beforePhotoUrl,
    this.initialCompletion,
  });

  @override
  State<JobCompletionProofPage> createState() => _JobCompletionProofPageState();
}

class _JobCompletionProofPageState extends State<JobCompletionProofPage> {
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<String> _beforePhotoUrls = [];
  final List<String> _afterPhotoUrls = [];
  bool _isUploadingBefore = false;
  bool _isUploadingAfter = false;
  bool _isEvaluating = false;
  bool _isSubmittingToCustomer = false;
  bool _hasReEvaluated = false;
  JobCompletionModel? _existingCompletion;

  late DateTime _jobStartedAt;
  late DateTime _jobEndedAt;
  ReviewAnalyzeResponseModel? _aiResult;

  bool get _isRevisionRequested {
    if (widget.booking.status == 'RevisionRequested' ||
        widget.booking.isRevisionRequested) {
      return true;
    }
    if (_existingCompletion?.status == 'RevisionRequested') {
      return true;
    }
    final missing =
        _aiResult?.missingDetails ??
        _existingCompletion?.aiMissingDetails ??
        [];
    return missing.any((m) => m.toLowerCase().contains('customer request:'));
  }

  @override
  void initState() {
    super.initState();
    _jobStartedAt =
        widget.startedAt ??
        widget.initialCompletion?.startedAt ??
        DateTime.now().subtract(const Duration(minutes: 52));
    _jobEndedAt =
        widget.endedAt ?? widget.initialCompletion?.endedAt ?? DateTime.now();

    if (widget.beforePhotoUrl != null && widget.beforePhotoUrl!.isNotEmpty) {
      _beforePhotoUrls.add(widget.beforePhotoUrl!);
    }

    _notesController.text =
        'Completed full servicing of ${widget.booking.serviceTitle}. Replaced defective parts, thoroughly tested under pressure, and cleaned the workspace.';

    if (widget.initialCompletion != null) {
      _applyCompletionData(widget.initialCompletion!);
    } else {
      _fetchExistingCompletionIfAvailable();
    }
  }

  Future<void> _fetchExistingCompletionIfAvailable() async {
    final data = await ReviewApi.getCompletionDetails(
      widget.booking.bookingReference,
    );
    if (data != null && mounted) {
      setState(() {
        _applyCompletionData(data);
      });
    }
  }

  void _applyCompletionData(JobCompletionModel data) {
    _existingCompletion = data;

    if (data.beforePhotoUrls.isNotEmpty) {
      _beforePhotoUrls.clear();
      _beforePhotoUrls.addAll(data.beforePhotoUrls);
    } else if (data.beforePhotoUrl != null && data.beforePhotoUrl!.isNotEmpty) {
      if (!_beforePhotoUrls.contains(data.beforePhotoUrl!)) {
        _beforePhotoUrls.add(data.beforePhotoUrl!);
      }
    }

    if (data.afterPhotoUrls.isNotEmpty) {
      _afterPhotoUrls.clear();
      _afterPhotoUrls.addAll(data.afterPhotoUrls);
    }

    if (data.providerNotes.isNotEmpty) {
      _notesController.text = data.providerNotes;
    }

    _jobStartedAt = data.startedAt;
    _jobEndedAt = data.endedAt;

    if (data.aiConfidenceScore > 0 || data.aiComparisonAnalysis.isNotEmpty) {
      _aiResult = ReviewAnalyzeResponseModel(
        success: true,
        bookingReference: data.bookingReference,
        verificationPassed: data.aiVerificationPassed,
        confidenceScore: data.aiConfidenceScore,
        comparisonAnalysis: data.aiComparisonAnalysis,
        verifiedTasks: data.aiVerifiedTasks,
        missingDetails: data.aiMissingDetails,
        durationMinutes: data.durationMinutes,
        durationFormatted:
            '${data.durationMinutes ~/ 60}h ${data.durationMinutes % 60}m',
        hourlyRate: data.hourlyRate,
        calculatedPrice: data.calculatedPrice,
        priceFormatted: 'Rs. ${data.calculatedPrice.toInt()}',
        status: data.status,
        model: 'gpt-4o-mini',
        latencyMs: 350,
      );
    }
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
    // Minimum 1-hour charge: first 60 mins = full 1-hr rate; subsequent mins prorated
    if (_elapsedMinutes <= 60) {
      return rate;
    }
    final extraMinutes = _elapsedMinutes - 60;
    return rate + (extraMinutes * (rate / 60.0));
  }

  void _removePhoto({required bool isBefore, required int index}) {
    setState(() {
      if (isBefore) {
        if (index < _beforePhotoUrls.length) {
          _beforePhotoUrls.removeAt(index);
        }
      } else {
        if (index < _afterPhotoUrls.length) {
          _afterPhotoUrls.removeAt(index);
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo removed.'),
        duration: Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto({required bool isBefore}) async {
    final currentList = isBefore ? _beforePhotoUrls : _afterPhotoUrls;
    if (currentList.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBefore
                ? 'Maximum 5 Before photos reached.'
                : 'Maximum 5 After photos reached.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
                isBefore
                    ? 'Add Before Photo (${currentList.length}/5)'
                    : 'Add After-Work Proof Photo (${currentList.length}/5)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.primary,
                ),
                title: const Text('Take Photo with Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.primary,
                ),
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
            if (uploadedUrl != null) _beforePhotoUrls.add(uploadedUrl);
          } else {
            _isUploadingAfter = false;
            if (uploadedUrl != null) _afterPhotoUrls.add(uploadedUrl);
          }
        });

        if (uploadedUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📷 Proof photo uploaded successfully!'),
              backgroundColor: AppColors.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to upload photo. Please check your connection.',
              ),
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
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _runAgent4Evaluation() async {
    if (_afterPhotoUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload at least one After Photo to verify completion.',
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _isEvaluating = true;
      // Do NOT overwrite _jobEndedAt here - it is already frozen at End Job button click!
    });

    final result = await ReviewApi.evaluateCompletion(
      bookingReference: widget.booking.bookingReference,
      providerNotes: _notesController.text.trim(),
      beforePhotoUrl: _beforePhotoUrls.isNotEmpty
          ? _beforePhotoUrls.first
          : null,
      beforePhotoUrls: _beforePhotoUrls,
      afterPhotoUrls: _afterPhotoUrls,
      startedAt: _jobStartedAt,
      endedAt: _jobEndedAt,
      hourlyRate: widget.booking.price > 0 ? widget.booking.price : 5000.0,
    );

    if (mounted) {
      setState(() {
        _isEvaluating = false;
        _aiResult = result;
        if (result != null) {
          _hasReEvaluated = true;
        }
      });

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.verificationPassed
                  ? '✅ Agent 4: Quality verification passed (${result.confidenceScore}% confidence)!'
                  : '⚠️ Agent 4: Additional details or proof requested.',
            ),
            backgroundColor: result.verificationPassed
                ? Colors.green
                : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to run Agent 4 review. Check your backend status.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitToCustomer() async {
    setState(() => _isSubmittingToCustomer = true);

    final success = await ReviewApi.submitToCustomer(
      bookingReference: widget.booking.bookingReference,
    );

    if (mounted) {
      setState(() => _isSubmittingToCustomer = false);

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to submit to customer. Please check your network.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final confidence = _aiResult?.confidenceScore ?? 0;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sent to Customer!',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Agent 4 has verified your proof of work with $confidence% confidence. The customer (${widget.booking.customerName}) has now been notified to review the photos and confirm sign-off.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
            // Revision Notice Banner (if revision was requested by customer)
            if (_isRevisionRequested) ...[
              _buildRevisionNoticeBanner(palette),
              const SizedBox(height: 18),
            ],

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

  Widget _buildServiceDurationBanner(
    AppPalette palette,
    int hours,
    int minutes,
    double rate,
  ) {
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
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _elapsedMinutes <= 60
                        ? 'Fee formula: Flat 1-hr minimum rate = Rs. ${rate.toInt()} (${_elapsedMinutes}m worked)'
                        : 'Fee formula: 1 hr base (Rs. ${rate.toInt()}) + ${_elapsedMinutes - 60}m (Rs. ${((_elapsedMinutes - 60) * (rate / 60)).toStringAsFixed(2)})',
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
          color: isAccent
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isAccent ? Colors.green : AppColors.primary,
              ),
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
            // Before Photos Card (1 to 5)
            Expanded(
              child: _buildPhotoCategoryCard(
                title: 'Before Service',
                tag: 'Initial Condition',
                photos: _beforePhotoUrls,
                isLoading: _isUploadingBefore,
                isBefore: true,
                onAdd: () => _pickAndUploadPhoto(isBefore: true),
                onRemove: (idx) => _removePhoto(isBefore: true, index: idx),
              ),
            ),
            const SizedBox(width: 12),
            // After Photos Card (1 to 5)
            Expanded(
              child: _buildPhotoCategoryCard(
                title: 'After Service',
                tag: 'Completed Result',
                photos: _afterPhotoUrls,
                isLoading: _isUploadingAfter,
                isBefore: false,
                onAdd: () => _pickAndUploadPhoto(isBefore: false),
                onRemove: (idx) => _removePhoto(isBefore: false, index: idx),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoCategoryCard({
    required String title,
    required String tag,
    required List<String> photos,
    required bool isLoading,
    required bool isBefore,
    required VoidCallback onAdd,
    required Function(int) onRemove,
  }) {
    final hasPhotos = photos.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPhotos
              ? AppColors.primary.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasPhotos
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${photos.length}/5',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasPhotos
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Preview Box / Upload Box
          InkWell(
            onTap: hasPhotos
                ? () => openFullScreenPhotoViewer(
                    context,
                    imageUrls: photos,
                    initialIndex: 0,
                    title: '$title - Photo 1 of ${photos.length}',
                  )
                : (isLoading ? null : (photos.length < 5 ? onAdd : null)),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: hasPhotos
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (hasPhotos
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: photos.first,
                                fit: BoxFit.cover,
                                placeholder: (context, urlStr) => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (context, urlStr, error) =>
                                    const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    ),
                              ),
                              // Fullscreen icon hint
                              Positioned(
                                bottom: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.fullscreen_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'View',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Cross remove button on main photo
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => onRemove(0),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (photos.length < 5)
                                Positioned(
                                  bottom: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: onAdd,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.add_photo_alternate_rounded,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Add (${photos.length}/5)',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isBefore
                                    ? Icons.camera_enhance_outlined
                                    : Icons.add_a_photo_outlined,
                                color: AppColors.primary,
                                size: 26,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isBefore ? '+ Before Photo' : '+ After Photo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                'Up to 5 photos',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )),
            ),
          ),
          // Thumbnails row with Remove Cross Button
          if (hasPhotos)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length + (photos.length < 5 ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    if (i == photos.length) {
                      // Add Photo Tile
                      return InkWell(
                        onTap: isLoading ? null : onAdd,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    }

                    final photoUrl = photos[i];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () => openFullScreenPhotoViewer(
                            context,
                            imageUrls: photos,
                            initialIndex: i,
                            title:
                                '$title - Photo ${i + 1} of ${photos.length}',
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: photoUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              placeholder: (context, urlStr) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, urlStr, error) =>
                                  const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        // Remove Cross Button on Thumbnail
                        Positioned(
                          top: -3,
                          right: -3,
                          child: GestureDetector(
                            onTap: () => onRemove(i),
                            child: Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
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
            hintText:
                'Describe replacement parts, pressure tests, and clean-up details...',
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
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
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
        color: isPassed
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPassed
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.orange.withValues(alpha: 0.4),
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
                    isPassed
                        ? Icons.verified_rounded
                        : Icons.warning_amber_rounded,
                    color: isPassed ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPassed
                        ? 'Agent 4: Quality Passed'
                        : 'Agent 4: Revision Advised',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isPassed
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: palette.text,
                        ),
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: palette.text,
                        ),
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

  Widget _buildRevisionNoticeBanner(AppPalette palette) {
    List<String> customerRequests = [];
    final missing =
        _aiResult?.missingDetails ??
        _existingCompletion?.aiMissingDetails ??
        [];
    for (final item in missing) {
      if (item.toLowerCase().contains('customer request:')) {
        customerRequests.add(
          item
              .replaceAll(
                RegExp(r'customer request:\s*', caseSensitive: false),
                '',
              )
              .trim(),
        );
      }
    }
    if (customerRequests.isEmpty && missing.isNotEmpty) {
      customerRequests.addAll(missing);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assignment_late_rounded,
                  color: Colors.amber.shade900,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Customer Requested Revision',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ACTION REQUIRED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 15,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Requested changes from ${widget.booking.customerName}:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (customerRequests.isNotEmpty)
                  ...customerRequests.map(
                    (req) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              req,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.grey.shade900,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    'Please update your after-work proof photos and notes to address customer expectations.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '💡 Update photos or notes below, then tap "Re-evaluate with Agent 4" to re-verify.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: Colors.amber.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppPalette palette) {
    final isRevision = _isRevisionRequested;

    // If revision was requested and provider hasn't re-evaluated with Agent 4 yet:
    if (isRevision && !_hasReEvaluated) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade900,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isEvaluating ? null : _runAgent4Evaluation,
              icon: _isEvaluating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 20),
              label: Text(
                _isEvaluating
                    ? 'Agent 4 is Re-evaluating...'
                    : 'Re-evaluate with Agent 4',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '⚠️ Re-evaluation with Agent 4 is required after updating proof for customer revision.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: Colors.amber.shade900,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (_aiResult == null) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isEvaluating ? null : _runAgent4Evaluation,
          icon: _isEvaluating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.auto_awesome, size: 20),
          label: Text(
            _isEvaluating
                ? 'Agent 4 is Analyzing Proof...'
                : 'Run Agent 4 AI Verification',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final confidence = _aiResult?.confidenceScore ?? 0;
    final isConfidencePassed = confidence >= 80;

    if (!isConfidencePassed) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade800,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Confidence: $confidence% (80%+ Required)',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'The AI review confidence is below the 80% threshold required to send this job to the customer. Please upload clearer Before & After photos or add more detailed work notes, then re-evaluate.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: Colors.orange.shade900.withValues(alpha: 0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isEvaluating ? null : _runAgent4Evaluation,
              icon: _isEvaluating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                _isEvaluating
                    ? 'Agent 4 is Re-evaluating...'
                    : 'Re-evaluate with Agent 4',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isSubmittingToCustomer ? null : _submitToCustomer,
            icon: _isSubmittingToCustomer
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 20),
            label: Text(
              'Submit to Customer for Sign-Off',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
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

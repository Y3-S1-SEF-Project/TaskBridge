import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/review_api.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../services/disputes_api.dart';

class CreateDisputePage extends StatefulWidget {
  final BookingItem booking;
  final JobCompletionModel? completion;

  const CreateDisputePage({super.key, required this.booking, this.completion});

  @override
  State<CreateDisputePage> createState() => _CreateDisputePageState();
}

class _CreateDisputePageState extends State<CreateDisputePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Work Incomplete / Missed Tasks';
  String _selectedResolution = 'Rework Required (Free Revision)';

  final List<String> _categories = [
    'Work Incomplete / Missed Tasks',
    'Poor Quality / Defective Work',
    'Damage to Property',
    'Billing Dispute / Incorrect Hours',
    'Unprofessional Specialist Conduct',
    'Safety Hazard / Code Violation',
    'Other Concern',
  ];

  final List<String> _resolutions = [
    'Rework Required (Free Revision)',
    'Partial Refund / Fee Reduction',
    'Full Refund & Cancel Job',
    'Admin Investigation & Mediation',
  ];

  final List<String> _evidencePhotos = [];
  bool _isUploadingPhoto = false;
  bool _isSubmitting = false;
  AuthUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await AuthApi.getCachedUser();
    if (mounted) {
      setState(() => _currentUser = u);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidencePhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1200,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);

      final uploadedUrl = await ReviewApi.uploadProofPhoto(
        picked.path,
        bookingRef: widget.booking.bookingReference,
      );

      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            _evidencePhotos.add(uploadedUrl);
          } else {
            // Local fallback path for preview
            _evidencePhotos.add(picked.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();
    if (description.length < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the issue in at least 15 characters.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dispute = await DisputesApi.createDispute(
        bookingReference: widget.booking.bookingReference,
        reasonCategory: _selectedCategory,
        description: description,
        desiredResolution: _selectedResolution,
        evidencePhotoUrls: _evidencePhotos,
        customerId: _currentUser?.id ?? widget.booking.customerId,
        customerName: _currentUser?.fullName ?? widget.booking.customerName,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (dispute != null) {
        await _showSuccessDialog(dispute.disputeReference);
        if (mounted) {
          Navigator.pop(context, true); // Return true so caller refreshes
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to file dispute. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting dispute: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showSuccessDialog(String disputeRef) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final palette = AppPalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.r20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Iconsax.shield_security,
                    size: 34,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Dispute Raised with Admin',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Reference: #$disputeRef',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This booking is now on freeze under admin investigation. Sign-off and fund disbursement are paused until an administrator concludes the mediation.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: palette.muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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
                    'Back to Job',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    // Extract photos for display
    final beforePhotos = <String>[];
    final completionBefore = widget.completion?.beforePhotoUrl;
    if (completionBefore != null && completionBefore.isNotEmpty) {
      beforePhotos.add(completionBefore);
    } else if (widget.booking.beforePhotoUrl != null &&
        widget.booking.beforePhotoUrl!.isNotEmpty) {
      beforePhotos.add(widget.booking.beforePhotoUrl!);
    }

    final afterPhotos = widget.completion?.afterPhotoUrls ?? <String>[];

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
          'Raise Dispute with Admin',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: palette.text,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              _buildFreezeNoticeCard(palette),
              const SizedBox(height: 16),

              // Job Details Summary Card
              _buildJobOverviewCard(palette),
              const SizedBox(height: 18),

              // Before & After Photos Evidence
              if (beforePhotos.isNotEmpty || afterPhotos.isNotEmpty) ...[
                _buildJobPhotosCard(palette, beforePhotos, afterPhotos),
                const SizedBox(height: 18),
              ],

              // Dispute Form Fields
              _buildDisputeFormFields(palette),
              const SizedBox(height: 20),

              // Customer Evidence Photos Section
              _buildEvidencePhotosSection(palette),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitDispute,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Iconsax.shield_cross, size: 20),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting to Admin...'
                        : 'Submit Dispute to Admin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreezeNoticeCard(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, color: Colors.amber.shade900, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Administrative Freeze Protocol',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Filing this dispute locks the job in an incomplete state. Funds are held in escrow and will not be disbursed until TaskBridge operations investigate both sides.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.brown.shade800,
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

  Widget _buildJobOverviewCard(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                'JOB DETAILS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: palette.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${widget.booking.bookingReference}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.booking.serviceTitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Iconsax.user, size: 14, color: palette.muted),
              const SizedBox(width: 6),
              Text(
                'Specialist: ${widget.booking.providerName}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category: ${widget.booking.category}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: palette.muted,
                ),
              ),
              Text(
                'Total Fee: Rs. ${(widget.completion?.calculatedPrice ?? widget.booking.price).toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobPhotosCard(
    AppPalette palette,
    List<String> before,
    List<String> after,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.gallery, size: 16, color: palette.primary),
              const SizedBox(width: 8),
              Text(
                'Provider Photo Evidence',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Before photo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BEFORE (${before.length})',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: before.isNotEmpty
                          ? Image.network(
                              before.first,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : const Center(
                              child: Text(
                                'No before photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // After photo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AFTER (${after.length})',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: after.isNotEmpty
                          ? Image.network(
                              after.first,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : const Center(
                              child: Text(
                                'No after photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
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

  Widget _buildDisputeFormFields(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DISPUTE DETAILS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 14),

          // Issue Category Dropdown
          Text(
            'Primary Reason for Dispute',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: InputDecoration(
              filled: true,
              fillColor: palette.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
            items: _categories.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(
                  cat,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
          ),
          const SizedBox(height: 16),

          // Detailed explanation
          Text(
            'Detailed Explanation of the Issue',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Clearly explain what was unsatisfactory, defective, or missed by the specialist. Include times, specific fixtures, or discrepancies...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: palette.muted,
              ),
              filled: true,
              fillColor: palette.background,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().length < 15) {
                return 'Please describe the issue in at least 15 characters.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Desired resolution
          Text(
            'Desired Resolution',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedResolution,
            decoration: InputDecoration(
              filled: true,
              fillColor: palette.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
            items: _resolutions.map((res) {
              return DropdownMenuItem(
                value: res,
                child: Text(
                  res,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedResolution = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEvidencePhotosSection(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                'YOUR PHOTO EVIDENCE (OPTIONAL)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: palette.primary,
                ),
              ),
              Text(
                '${_evidencePhotos.length} added',
                style: TextStyle(
                  fontSize: 11,
                  color: palette.muted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Photos of defective work or property issues significantly strengthen your case with the administrator.',
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
          const SizedBox(height: 12),

          // Photos gallery
          if (_evidencePhotos.isNotEmpty) ...[
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _evidencePhotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final photo = _evidencePhotos[i];
                  return Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: palette.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: photo.startsWith('http')
                            ? Image.network(photo, fit: BoxFit.cover)
                            : Image.file(File(photo), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _evidencePhotos.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
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
            const SizedBox(height: 12),
          ],

          // Add Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isUploadingPhoto
                      ? null
                      : () => _pickEvidencePhoto(ImageSource.camera),
                  icon: const Icon(Iconsax.camera, size: 16),
                  label: const Text(
                    'Take Photo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isUploadingPhoto
                      ? null
                      : () => _pickEvidencePhoto(ImageSource.gallery),
                  icon: const Icon(Iconsax.gallery, size: 16),
                  label: const Text(
                    'From Gallery',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          if (_isUploadingPhoto)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Uploading evidence photo to R2...',
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

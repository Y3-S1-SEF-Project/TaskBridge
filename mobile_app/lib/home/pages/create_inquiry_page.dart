import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../ai/services/review_api.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../services/inquiries_api.dart';

class CreateInquiryPage extends StatefulWidget {
  final AuthUser? user;

  const CreateInquiryPage({super.key, this.user});

  @override
  State<CreateInquiryPage> createState() => _CreateInquiryPageState();
}

class _CreateInquiryPageState extends State<CreateInquiryPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  final List<String> _categories = [
    'System Issue / Bug',
    'App Feature Glitch',
    'Billing & Payments',
    'Account & Profile',
    'Service Booking Question',
    'General Inquiry',
  ];

  late String _selectedCategory;
  String _selectedPriority = 'Normal';

  final List<String> _screenshotUrls = [];
  bool _isUploadingPhoto = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categories.first;
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);

      final uploadedUrl = await ReviewApi.uploadProofPhoto(
        picked.path,
        bookingRef: 'INQUIRY',
      );

      if (uploadedUrl != null && mounted) {
        setState(() {
          _screenshotUrls.add(uploadedUrl);
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _submitInquiry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = widget.user ?? await AuthApi.getCachedUser();

      final inquiry = await InquiriesApi.createInquiry(
        subject: _subjectController.text.trim(),
        category: _selectedCategory,
        message: _messageController.text.trim(),
        priority: _selectedPriority,
        attachmentUrls: _screenshotUrls,
        userId: currentUser?.id,
        userName: currentUser?.fullName,
        userRole: 'Customer',
      );

      if (inquiry != null && mounted) {
        _showSuccessDialog(inquiry.inquiryReference);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not create inquiry. Please check your connection.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(String reference) {
    final palette = AppPalette.of(context);
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade700,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Inquiry Submitted!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.text,
                ),
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
                  'Reference: #$reference',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: palette.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Our administration team will review your inquiry. You will receive a notification and can view the admin response directly under My Inquiries.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: palette.muted,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, true);
                  },
                  child: const Text(
                    'View My Inquiries',
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

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'New System Inquiry',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: palette.text,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: palette.text,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              _buildHelpBanner(palette),
              const SizedBox(height: 16),

              // Form card
              Container(
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
                      'INQUIRY DETAILS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category
                    Text(
                      'Issue Category',
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
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Subject
                    Text(
                      'Subject / Headline',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Cannot complete payment or app freeze',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: palette.muted,
                        ),
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
                      validator: (v) {
                        if (v == null || v.trim().length < 5) {
                          return 'Please provide a subject of at least 5 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Message
                    Text(
                      'Detailed Description',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Describe what occurred, any error messages displayed, or steps to reproduce the issue...',
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

                    // Priority
                    Text(
                      'Priority / Urgency',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPriorityChip('Normal', palette),
                        const SizedBox(width: 8),
                        _buildPriorityChip('High', palette),
                        const SizedBox(width: 8),
                        _buildPriorityChip('Urgent', palette),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Attachment section
              _buildAttachmentsCard(palette),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitInquiry,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Iconsax.send_1, size: 20),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting Inquiry...'
                        : 'Submit Inquiry to Admin',
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

  Widget _buildHelpBanner(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.info_circle, color: Color(0xFF1D4ED8), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support & System Assistance',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Submit questions, report app glitches or billing questions directly to platform supervisors. You will see admin responses right on your device.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF1E40AF),
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

  Widget _buildPriorityChip(String level, AppPalette palette) {
    final isSelected = _selectedPriority == level;
    final color = level == 'Urgent'
        ? Colors.red.shade700
        : level == 'High'
        ? Colors.orange.shade800
        : palette.primary;

    return ChoiceChip(
      showCheckmark: true,
      checkmarkColor: Colors.white,
      label: Text(
        level,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? Colors.white : palette.text,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: palette.soft,
      side: BorderSide(
        color: isSelected ? color : palette.border,
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _selectedPriority = level),
    );
  }

  Widget _buildAttachmentsCard(AppPalette palette) {
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
                'SCREENSHOT ATTACHMENTS (OPTIONAL)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: palette.primary,
                ),
              ),
              Text(
                '${_screenshotUrls.length} added',
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
            'Attach screenshots of any glitches or error messages to help our engineers diagnose faster.',
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
          const SizedBox(height: 12),

          if (_screenshotUrls.isNotEmpty) ...[
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _screenshotUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final url = _screenshotUrls[i];
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
                        child: Image.network(url, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _screenshotUrls.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
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
                      : () => _pickAttachment(ImageSource.camera),
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
                      : () => _pickAttachment(ImageSource.gallery),
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
                    'Uploading screenshot...',
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

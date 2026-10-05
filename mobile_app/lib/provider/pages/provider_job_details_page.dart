import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/coordination_api.dart';
import '../../ai/services/review_api.dart';
import '../../ai/services/bookings_sync_service.dart';
import '../../core/services/location_service.dart';
import '../../home/widgets/fullscreen_photo_viewer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import 'job_completion_proof_page.dart';
import '../../chat/pages/active_chat_page.dart';
import '../../chat/services/chat_service.dart';
import '../../auth/data/auth_api.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Full Job Details page for providers displaying complete customer info,
/// confirmed schedule, realistic interactive location map, rate type (hourly vs fixed),
/// and flush unified bottom action controls.
class ProviderJobDetailsPage extends StatefulWidget {
  final BookingItem booking;

  const ProviderJobDetailsPage({super.key, required this.booking});

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

  bool get _isDisputed =>
      _currentBooking.status == 'Disputed' ||
      _currentBooking.isDisputed ||
      _completion?.status == 'Disputed';

  bool get _isRevisionRequested =>
      !_isDisputed &&
      (_currentBooking.status == 'RevisionRequested' ||
          _currentBooking.isRevisionRequested ||
          _completion?.status == 'RevisionRequested');

  bool get _isDraftProof =>
      _completion != null &&
      _completion!.status.toLowerCase() == 'draft' &&
      !_isPendingSignOff &&
      !_isRevisionRequested &&
      !_isDisputed &&
      !_currentBooking.isCompleted;

  bool get _isPendingSignOff =>
      !_isDisputed &&
      (_currentBooking.status == 'PendingCustomerSignOff' ||
          _currentBooking.isPendingSignOff ||
          _completion?.status == 'PendingCustomerSignOff');

  LatLng? _bookingLatLng;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    _jobStartedAt = widget.booking.startedAt;
    _beforePhotoUrl = widget.booking.beforePhotoUrl;
    BookingsSyncService.instance.addListener(_onSyncUpdate);
    _reloadBookingAndProof();
    _resolveLocationCoordinates();
  }

  @override
  void dispose() {
    BookingsSyncService.instance.removeListener(_onSyncUpdate);
    _mapController?.dispose();
    super.dispose();
  }

  void _onSyncUpdate() {
    if (mounted) {
      _reloadBookingAndProof(silent: true);
    }
  }

  Future<void> _reloadBookingAndProof({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoadingProof = true);
    }
    try {
      final bookings = await CoordinationApi.getBookings(
        providerId: _currentBooking.providerId,
        providerName: _currentBooking.providerName,
      );
      final fresh = bookings.firstWhere(
        (b) => b.bookingReference == _currentBooking.bookingReference,
        orElse: () => _currentBooking,
      );
      final proof = await ReviewApi.getCompletionDetails(
        _currentBooking.bookingReference,
      );
      if (mounted) {
        setState(() {
          _currentBooking = fresh;
          _completion = proof;
          if (fresh.startedAt != null) {
            _jobStartedAt = fresh.startedAt;
          } else if (proof != null) {
            _jobStartedAt = proof.startedAt;
          }
          if (fresh.beforePhotoUrl != null &&
              fresh.beforePhotoUrl!.isNotEmpty) {
            _beforePhotoUrl = fresh.beforePhotoUrl;
          } else if (proof != null &&
              proof.beforePhotoUrl != null &&
              proof.beforePhotoUrl!.isNotEmpty) {
            _beforePhotoUrl = proof.beforePhotoUrl;
          }
          _isLoadingProof = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProof = false);
      }
    }
  }

  /// Geocodes or extracts coordinates for the booking's service location
  Future<void> _resolveLocationCoordinates() async {
    final locationText = _currentBooking.location.trim();
    if (locationText.isEmpty) return;

    // 1. Check if location contains explicit coordinates e.g. "6.8402, 79.9015"
    final coordMatch = RegExp(
      r'(-?\d+\.\d+)[,\s]+(-?\d+\.\d+)',
    ).firstMatch(locationText);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null && mounted) {
        setState(() => _bookingLatLng = LatLng(lat, lng));
        return;
      }
    }

    // 2. Geocode via LocationService
    try {
      final loc = await LocationService.searchLocation(locationText);
      if (loc != null && mounted) {
        setState(() => _bookingLatLng = LatLng(loc.latitude, loc.longitude));
        return;
      }
    } catch (_) {}

    // 3. Default to Boralesgamuwa/Colombo coordinates if mentioned
    final lower = locationText.toLowerCase();
    if (lower.contains('boralesgamuwa')) {
      if (mounted) {
        setState(() => _bookingLatLng = const LatLng(6.8480, 79.9015));
      }
    } else if (mounted) {
      setState(() => _bookingLatLng = const LatLng(6.8833, 79.8653));
    }
  }

  /// Formats a concise street / neighborhood label without repeated fragments
  String get _cleanShortLocation {
    final raw = _currentBooking.location.trim();
    if (raw.isEmpty) return 'Job Location';
    final parts = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Job Location';
    if (parts.length == 1) return parts.first;

    final p0 = parts[0];
    final p1 = parts[1];
    if (p1.startsWith('$p0 ') || p1.toLowerCase() == p0.toLowerCase()) {
      return parts.length >= 3 ? '$p1, ${parts[2]}' : p1;
    }
    return '$p0, $p1';
  }

  /// Opens the destination directly in native Google Maps or external browser navigation
  Future<void> _openInGoogleMaps() async {
    final locationStr = _currentBooking.location.trim();
    final query = Uri.encodeComponent(locationStr);

    Uri mapsUri;
    if (_bookingLatLng != null) {
      // Directions directly to destination coordinate
      mapsUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${_bookingLatLng!.latitude},${_bookingLatLng!.longitude}',
      );
    } else {
      // Universal Google Maps search URI
      mapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );
    }

    try {
      final launched = await launchUrl(
        mapsUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        final webFallback = Uri.parse('https://maps.google.com/?q=$query');
        await launchUrl(webFallback, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Google Maps: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.camera_enhance_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Start Job & Capture Before Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
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
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Review Requirement:\nAI Quality Assurance checks the initial state before work begins. Taking a clear photo now ensures your completion review passes without delay.',
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                                if (uploaded != null) {
                                  tempBeforePhoto = uploaded;
                                }
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
                      tempBeforePhoto != null
                          ? 'Retake Before Photo'
                          : 'Take Before Photo Now',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                final now = DateTime.now();
                setState(() {
                  _isUpdating = true;
                  _beforePhotoUrl = tempBeforePhoto;
                  _jobStartedAt = now;
                  _currentBooking = _currentBooking.copyWith(
                    startedAt: now,
                    beforePhotoUrl: tempBeforePhoto,
                    status: 'In Progress',
                  );
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
    final isRevision = _isRevisionRequested;
    final isPending = _isPendingSignOff;
    final isDraft = _isDraftProof;

    bool proceed = true;
    if (!isRevision && !isPending && !isDraft) {
      final proceedConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: palette.primary, size: 24),
              const SizedBox(width: 8),
              const Text('Finish & Submit Proof?'),
            ],
          ),
          content: const Text(
            'Are you ready to submit your work for AI Quality Verification? You will be prompted to attach after-service proof photos and work notes.',
            style: TextStyle(fontSize: 14),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.text,
                      side: BorderSide(color: palette.border),
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Continue Working',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Proceed to AI Review',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      proceed = proceedConfirm == true;
    }

    if (proceed == true && mounted) {
      final jobEndedAt = _completion?.endedAt ?? DateTime.now();
      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => JobCompletionProofPage(
            booking: _currentBooking,
            startedAt:
                _currentBooking.startedAt ??
                _jobStartedAt ??
                _completion?.startedAt,
            endedAt: jobEndedAt,
            beforePhotoUrl:
                _currentBooking.beforePhotoUrl ??
                _completion?.beforePhotoUrl ??
                _beforePhotoUrl,
            initialCompletion: _completion,
          ),
        ),
      );

      if (updated == true && mounted) {
        _reloadBookingAndProof();
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

  /// Displays confirmation alert dialog before cancelling a job
  Future<void> _confirmCancelJob() async {
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Cancel Job?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel booking #${_currentBooking.bookingReference}? This will release the job and notify the client.',
          style: TextStyle(fontSize: 14, color: palette.muted, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'No, Keep Job',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Yes, Cancel Job',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _updateJobStatus('Cancelled');
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
      body: RefreshIndicator(
        onRefresh: () => _reloadBookingAndProof(),
        color: palette.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status Banner ──
              _buildStatusHeader(palette),
              const SizedBox(height: 14),

              // ── Revision Feedback Card (If customer requested changes) ──
              if (_isRevisionRequested) ...[
                _buildRevisionRequestCard(palette),
                const SizedBox(height: 14),
              ],

              // ── Submitted Proof of Work & AI Sign-Off (For Completed / In-Review Jobs) ──
              if (_currentBooking.isCompleted || _completion != null) ...[
                _buildProofOfWorkSection(palette),
                const SizedBox(height: 14),
              ],

              // ── Service & Price Card with Hourly vs Fixed details ──
              _buildServiceCard(palette),
              const SizedBox(height: 14),

              // ── Schedule & Time Card (Moved UP!) ──
              _buildScheduleCard(palette),
              const SizedBox(height: 14),

              // ── Customer Profile Card (Minimalist & Compact) ──
              _buildCustomerCard(palette),
              const SizedBox(height: 14),

              // ── Location & High-Fidelity Map Card (Moved to BOTTOM!) ──
              _buildLocationCard(palette),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      // Clean, flush bottom action bar docked to the screen bottom (replaces problematic bottomSheet)
      bottomNavigationBar: _buildBottomActionBar(
        palette,
        isUpcoming,
        isActive,
        isCompleted,
        _isRevisionRequested,
        _isPendingSignOff,
      ),
    );
  }

  Widget _buildRevisionRequestCard(AppPalette palette) {
    List<String> revisionItems = [];
    if (_completion != null) {
      for (final item in _completion!.aiMissingDetails) {
        if (item.toLowerCase().contains('customer request:')) {
          revisionItems.add(
            item
                .replaceAll(
                  RegExp(r'customer request:\s*', caseSensitive: false),
                  '',
                )
                .trim(),
          );
        }
      }
      if (revisionItems.isEmpty && _completion!.aiMissingDetails.isNotEmpty) {
        revisionItems.addAll(_completion!.aiMissingDetails);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: palette.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assignment_late_rounded,
                  color: palette.text,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Requested Revisions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      'Action needed to finalize job sign-off',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  'REVISION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 16,
                      color: palette.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Feedback from ${_currentBooking.customerName}:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (revisionItems.isNotEmpty)
                  ...revisionItems.map(
                    (rev) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: palette.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rev,
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.text,
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
                    'The customer asked to review the completed service and provide clearer proof photos or updated notes.',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: palette.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.text,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _handleEndJobFlow,
              icon: const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: const Text(
                'Update Proof & Re-evaluate (AI)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(AppPalette palette) {
    Color bg;
    Color fg;
    String statusTitle;
    String statusSubtitle;
    IconData icon;

    if (_isDisputed) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade900;
      statusTitle = 'Job On Hold • Under Admin Dispute Review';
      statusSubtitle =
          'The customer has raised a formal dispute regarding this service. All actions are frozen while TaskBridge administrators review the case and mediate.';
      icon = Iconsax.shield_cross;
    } else if (_isRevisionRequested) {
      bg = palette.surface;
      fg = palette.text;
      statusTitle = 'Revision Requested by Customer';
      statusSubtitle =
          'The customer requested changes before final sign-off. Please check the requested items below, update your proof or notes, and re-evaluate with AI.';
      icon = Icons.assignment_return_rounded;
    } else if (_isDraftProof) {
      bg = Colors.teal.shade50;
      fg = Colors.teal.shade900;
      statusTitle = 'Work Finished • Proof Draft Saved';
      statusSubtitle =
          'You recorded the end of this job. Review or update photos/notes at your own pace before submitting to the customer.';
      icon = Icons.edit_note_rounded;
    } else if (_isPendingSignOff) {
      bg = Colors.purple.shade50;
      fg = Colors.purple.shade800;
      statusTitle = 'Awaiting Customer Sign-Off';
      statusSubtitle =
          'Proof of work submitted with AI quality verification. Waiting for customer approval.';
      icon = Icons.hourglass_top_rounded;
    } else if (_currentBooking.isUpcoming) {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
      statusTitle = 'Upcoming Confirmed Job';
      statusSubtitle =
          'Appointment confirmed. Please arrive on time at customer location.';
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRevisionRequested
              ? palette.border
              : fg.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _isRevisionRequested
                  ? palette.background
                  : fg.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isRevisionRequested
                        ? palette.muted
                        : fg.withValues(alpha: 0.85),
                    height: 1.3,
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
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final isGardening =
        _currentBooking.category.toLowerCase().contains('garden') ||
        _currentBooking.serviceTitle.toLowerCase().contains('garden');
    final isPlumbing =
        _currentBooking.category.toLowerCase().contains('plumb') ||
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
    final beforeUrl = (rawBefore != null && rawBefore.isNotEmpty)
        ? rawBefore
        : defaultBefore;

    final afterUrls = _completion?.afterPhotoUrls ?? [];
    final rawAfter = afterUrls.isNotEmpty ? afterUrls.first : null;
    final afterUrl = (rawAfter != null && rawAfter.isNotEmpty)
        ? rawAfter
        : defaultAfter;

    final effectiveStart =
        _completion?.startedAt ?? _currentBooking.startedAt ?? _jobStartedAt;
    final effectiveEnd =
        _completion?.endedAt ?? _currentBooking.endedAt ?? DateTime.now();
    final mins =
        _completion?.durationMinutes ??
        _currentBooking.durationMinutes ??
        (effectiveStart != null
            ? effectiveEnd.difference(effectiveStart).inMinutes.clamp(1, 9999)
            : 15);
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    final rate =
        _completion?.hourlyRate ??
        (_currentBooking.price > 0 ? _currentBooking.price : 3750.0);
    final calculatedPrice =
        _completion?.calculatedPrice ??
        ((hours * rate) + (remMins * (rate / 60.0)));

    final analysis =
        _completion?.aiComparisonAnalysis ??
        'AI analyzed the proof images and verified that the service requirements were met with clean execution.';
    final verified =
        _completion?.aiVerifiedTasks ??
        [
          'Initial inspection and before-work condition captured',
          'Complete execution of requested ${_currentBooking.serviceTitle} tasks',
          'After-work cleanup and site clearance verified',
          'Final testing and operational check confirmed',
        ];

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(
          color: _isRevisionRequested
              ? palette.border
              : (_isDraftProof ? palette.border : palette.border),
          width: 1.2,
        ),
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
                  Icon(
                    _isRevisionRequested
                        ? Icons.assignment_late_outlined
                        : Icons.fact_check_outlined,
                    color: palette.text,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SUBMITTED PROOF OF WORK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: palette.text,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  _isRevisionRequested
                      ? 'Revision Requested'
                      : (_isPendingSignOff
                            ? 'Awaiting Sign-Off'
                            : (_isDraftProof ? 'Proof Draft' : 'Verified')),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Photos Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildProofPhotoGalleryCard(
                  title: 'Before Service',
                  subtitle: 'Initial State',
                  photos: _completion?.beforePhotoUrls ?? [],
                  fallbackUrl: beforeUrl,
                  badgeColor: palette.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildProofPhotoGalleryCard(
                  title: 'After Service',
                  subtitle: 'Completed Result',
                  photos: _completion?.afterPhotoUrls ?? [],
                  fallbackUrl: afterUrl,
                  badgeColor: palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // AI Quality Assessment
          Builder(
            builder: (context) {
              final isAiPassed = _completion?.aiVerificationPassed ?? true;
              final aiScore = _completion?.aiConfidenceScore ?? 90;

              final String badgeText = _isRevisionRequested
                  ? 'Needs Revision'
                  : (!isAiPassed
                        ? 'Mismatch Flagged ($aiScore%)'
                        : '$aiScore% Match');

              final IconData aiIcon = _isRevisionRequested
                  ? Icons.rule_rounded
                  : (!isAiPassed
                        ? Icons.warning_amber_rounded
                        : Icons.auto_awesome);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(aiIcon, color: palette.text, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'AI Quality Assessment',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: palette.text,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: palette.text,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
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
                              Icon(
                                Icons.check_circle_outline,
                                size: 13,
                                color: _isRevisionRequested
                                    ? palette.muted
                                    : Colors.green,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.text,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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

  Widget _buildProofPhotoGalleryCard({
    required String title,
    required String subtitle,
    required List<String> photos,
    required String fallbackUrl,
    required Color badgeColor,
  }) {
    final effectivePhotos = photos.isNotEmpty ? photos : [fallbackUrl];
    final primaryPhoto = effectivePhotos.first;

    Widget buildSinglePhoto(String url) {
      if (url.startsWith('/') || url.startsWith('file://')) {
        final cleanPath = url.replaceFirst('file://', '');
        return Image.file(
          File(cleanPath),
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) =>
              const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        );
      }
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, urlStr) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (context, urlStr, error) => Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) =>
              const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    effectivePhotos.length > 1
                        ? '${effectivePhotos.length} photos'
                        : subtitle,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => openFullScreenPhotoViewer(
              context,
              imageUrls: effectivePhotos,
              initialIndex: 0,
              title: '$title · Photo 1 of ${effectivePhotos.length}',
            ),
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(effectivePhotos.length > 1 ? 0 : 12),
            ),
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(effectivePhotos.length > 1 ? 0 : 12),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(
                        effectivePhotos.length > 1 ? 0 : 12,
                      ),
                    ),
                    child: buildSinglePhoto(primaryPhoto),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fullscreen_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'View',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (effectivePhotos.length > 1)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: effectivePhotos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (ctx, idx) {
                    return InkWell(
                      onTap: () => openFullScreenPhotoViewer(
                        context,
                        imageUrls: effectivePhotos,
                        initialIndex: idx,
                        title:
                            '$title · Photo ${idx + 1} of ${effectivePhotos.length}',
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: idx == 0
                                  ? badgeColor
                                  : Colors.grey.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: buildSinglePhoto(effectivePhotos[idx]),
                        ),
                      ),
                    );
                  },
                ),
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _currentBooking.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
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
                    color: isHourly
                        ? Colors.teal.shade200
                        : Colors.indigo.shade200,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHourly ? Icons.timelapse_rounded : Icons.sell_rounded,
                      size: 11,
                      color: isHourly
                          ? Colors.teal.shade800
                          : Colors.indigo.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHourly ? 'HOURLY RATE' : 'FIXED TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isHourly
                            ? Colors.teal.shade900
                            : Colors.indigo.shade900,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isHourly
                          ? 'Billed by actual work hours'
                          : 'Agreed complete service amount',
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
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: palette.primary,
                        ),
                      ),
                      if (isHourly)
                        Text(
                          ' / hr',
                          style: TextStyle(
                            fontSize: 12,
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
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.border.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isHourly ? Icons.info_outline_rounded : Icons.verified_outlined,
                size: 15,
                color: palette.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isHourly
                      ? 'Hourly rate applies upon arrival. Total calculated based on hours logged.'
                      : 'Fixed amount agreed. No hourly or hidden adjustments upon completion.',
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.muted,
                    height: 1.3,
                  ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CUSTOMER DETAILS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: palette.muted,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 12,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Client',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: palette.primary.withValues(alpha: 0.12),
                child: Text(
                  _currentBooking.customerName.isNotEmpty
                      ? _currentBooking.customerName
                            .substring(0, 1)
                            .toUpperCase()
                      : 'C',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentBooking.customerName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '5.0 (Client Rating)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                        Text(
                          ' · Direct Client',
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Cool Compact Action Buttons
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      const rawPhone = '0779876543';
                      final uri = Uri(scheme: 'tel', path: rawPhone);
                      try {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Calling customer ${_currentBooking.customerName}...',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 15,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Call Customer',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) =>
                            const Center(child: CircularProgressIndicator()),
                      );

                      final providerUser = await AuthApi.getCachedUser();
                      final myProviderId =
                          providerUser?.id ?? _currentBooking.providerId ?? '';

                      final conv = await ChatService().findOrCreateConversation(
                        providerId: myProviderId,
                        customerId: _currentBooking.customerId,
                        bookingReference: _currentBooking.bookingReference,
                      );

                      if (mounted) Navigator.pop(context);

                      if (conv != null && mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ActiveChatPage(
                              conversationId: conv.id,
                              recipientId: conv.customerId,
                              recipientName: conv.customerName.isNotEmpty
                                  ? conv.customerName
                                  : _currentBooking.customerName,
                              subtitle:
                                  'Booking #${_currentBooking.bookingReference}',
                              bookingReference:
                                  _currentBooking.bookingReference,
                            ),
                          ),
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not open chat with ${_currentBooking.customerName}.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color: palette.onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Message',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(AppPalette palette) {
    final shortLoc = _cleanShortLocation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
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
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: palette.muted,
                  letterSpacing: 0.8,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: _currentBooking.location),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 12, color: palette.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Copy',
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
          ),
          const SizedBox(height: 10),

          // High-Fidelity Realistic Map Card with Proper Pin & Navigation
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 145,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E9E4), // Map ground tone
                border: Border.all(color: palette.border),
              ),
              child: Stack(
                children: [
                  if (_bookingLatLng != null)
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _bookingLatLng!,
                        zoom: 15.0,
                      ),
                      onMapCreated: (ctrl) {
                        _mapController = ctrl;
                      },
                      markers: {
                        Marker(
                          markerId: const MarkerId('job_destination_pin'),
                          position: _bookingLatLng!,
                          infoWindow: InfoWindow(
                            title: 'Job Destination',
                            snippet: shortLoc,
                          ),
                        ),
                      },
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      tiltGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                    )
                  else
                    // Vector City Map with realistic Pin Needle
                    Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RealisticCityMapPainter(),
                          ),
                        ),
                        // Sleek authentic teardrop pin positioned properly
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF22C55E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      shortLoc,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Red Teardrop Location Pin
                              const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFFE11D48),
                                size: 36,
                              ),
                              // Ground shadow
                              Container(
                                width: 14,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  // Tap gesture on the map to open directly in Google Maps
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: _openInGoogleMaps),
                    ),
                  ),

                  // Top left GPS status pill
                  Positioned(
                    top: 10,
                    left: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
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
                  ),

                  // Bottom label indicating tap opens Google Maps
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Tap Map for Live Directions',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: palette.primary,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _currentBooking.location,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.primary,
                side: BorderSide(
                  color: palette.primary.withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _openInGoogleMaps,
              icon: const Icon(Icons.directions_rounded, size: 17),
              label: const Text(
                'Open in Google Maps / Directions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(AppPalette palette) {
    String scheduleTime = _currentBooking.schedule;
    String? scheduleLocationNote;

    if (_currentBooking.schedule.contains(' · ')) {
      final parts = _currentBooking.schedule.split(' · ');
      scheduleTime = parts.first.trim();
      if (parts.length > 1) {
        scheduleLocationNote = parts.sublist(1).join(' · ').trim();
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CONFIRMED SCHEDULE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: palette.muted,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Booked Slot',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.access_time_filled_rounded,
                  color: palette.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheduleTime,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        height: 1.25,
                      ),
                    ),
                    if (scheduleLocationNote != null &&
                        scheduleLocationNote.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        scheduleLocationNote,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: palette.muted,
                        ),
                      ),
                    ],
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
    bool isRevisionRequested,
    bool isPendingSignOff,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, _currentBooking),
              child: const Text(
                'Back to Jobs',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      );
    }

    if (_isDisputed) {
      return Container(
        color: palette.surface,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SafeArea(
          top: false,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.shield_cross,
                  color: Colors.red.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Job Frozen • Under Admin Dispute Review',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentBooking.isCancelled) {
      return const SizedBox.shrink();
    }

    Widget content;

    if (isUpcoming) {
      content = Row(
        children: [
          // Unified side-by-side Cancel Job button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                onPressed: _isUpdating ? null : _confirmCancelJob,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isUpdating ? null : _handleStartJobFlow,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
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
      );
    } else if (isRevisionRequested) {
      content = SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.text,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isUpdating ? null : _handleEndJobFlow,
          icon: const Icon(
            Icons.assignment_return_rounded,
            size: 20,
            color: Colors.white,
          ),
          label: const Text(
            'Update Proof & Re-evaluate (AI)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (_isDraftProof) {
      content = SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isUpdating ? null : _handleEndJobFlow,
          icon: const Icon(Icons.edit_note_rounded, size: 20),
          label: const Text(
            'Resume Proof Draft & Submit (AI)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      );
    } else if (isPendingSignOff) {
      content = Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: palette.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Awaiting Customer Sign-Off',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: palette.primary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.primary,
                side: BorderSide(color: palette.primary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _handleEndJobFlow,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text(
                'Edit Proof',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    } else if (isActive) {
      content = SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isUpdating ? null : _handleEndJobFlow,
          child: const Text(
            'End Job & Submit Proof (AI)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
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
      child: SafeArea(top: false, child: content),
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
        Rect.fromLTWH(
          size.width * 0.68,
          size.height * 0.55,
          size.width * 0.26,
          size.height * 0.35,
        ),
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
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.72,
        size.width * 0.6,
        size.height,
      )
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
        Rect.fromLTWH(
          size.width * 0.35,
          14,
          size.width * 0.28,
          size.height * 0.26,
        ),
        const Radius.circular(6),
      ),
      blockPaint,
    );

    // Block cluster 2
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.7,
          14,
          size.width * 0.24,
          size.height * 0.3,
        ),
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
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.38,
        size.width,
        size.height * 0.68,
      );
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
      final y1 =
          (size.height * 0.22) * (1 - t1) * (1 - t1) +
          (size.height * 0.38) * 2 * (1 - t1) * t1 +
          (size.height * 0.68) * t1 * t1;
      final x2 = size.width * t2;
      final y2 =
          (size.height * 0.22) * (1 - t2) * (1 - t2) +
          (size.height * 0.38) * 2 * (1 - t2) * t2 +
          (size.height * 0.68) * t2 * t2;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

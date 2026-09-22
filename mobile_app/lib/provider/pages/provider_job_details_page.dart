import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/services/coordination_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

/// Full Job Details page for providers displaying complete customer info,
/// confirmed schedule, exact location with direction actions, price breakdown, and lifecycle controls.
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

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
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

            // ── Service & Price Card ──
            _buildServiceCard(palette),
            const SizedBox(height: 16),

            // ── Customer Profile Card ──
            _buildCustomerCard(palette),
            const SizedBox(height: 16),

            // ── Location & Navigation Card ──
            _buildLocationCard(palette),
            const SizedBox(height: 16),

            // ── Schedule & Time Card ──
            _buildScheduleCard(palette),
            const SizedBox(height: 100), // padding for bottom bar
          ],
        ),
      ),
      bottomSheet: _buildBottomActions(palette, isUpcoming, isActive, isCompleted),
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

  Widget _buildServiceCard(AppPalette palette) {
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
              Text(
                'Earnings',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _currentBooking.serviceTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
              ),
              Text(
                'Rs. ${_currentBooking.price.toInt()}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.payment_rounded, size: 16, color: palette.muted),
              const SizedBox(width: 8),
              Text(
                'Payment Method: Cash or Bank Transfer upon arrival',
                style: TextStyle(fontSize: 12, color: palette.muted),
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

          // Styled Map Preview Card
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Abstract road lines
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapRoadsPainter(color: palette.border.withValues(alpha: 0.6)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      _currentBooking.location,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ),
                ),
              ],
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
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.primary,
                side: BorderSide(color: palette.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening Navigation to ${_currentBooking.location}...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.directions_rounded, size: 18),
              label: const Text('Open in Google Maps / Directions'),
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

  Widget _buildBottomActions(AppPalette palette, bool isUpcoming, bool isActive, bool isCompleted) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, _currentBooking),
              child: const Text('Back to Jobs'),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUpcoming) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isUpdating ? null : () => _updateJobStatus('Active'),
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Start Job (Set Active / En Route)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isUpdating ? null : () => _updateJobStatus('Cancelled'),
                  child: const Text('Cancel Job', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ] else if (isActive) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isUpdating ? null : () => _updateJobStatus('Completed'),
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text(
                    'Mark Job as Completed',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapRoadsPainter extends CustomPainter {
  final Color color;
  _MapRoadsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Diagonal crossing lines to simulate a map grid
    canvas.drawLine(const Offset(0, 30), Offset(size.width, 80), paint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.7, size.height), paint);
    canvas.drawLine(const Offset(0, 90), Offset(size.width, 20), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

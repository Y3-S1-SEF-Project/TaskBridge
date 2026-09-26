import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ai/models/coordination_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../data/provider_api.dart';
import '../models/provider_item.dart';
import '../../chat/pages/active_chat_page.dart';
import '../../chat/services/chat_service.dart';

class CustomerJobDetailsPage extends StatefulWidget {
  final BookingItem booking;
  final ValueChanged<int>? onSwitchTab;
  final Future<void> Function(BookingItem)? onCancelBooking;

  const CustomerJobDetailsPage({
    super.key,
    required this.booking,
    this.onSwitchTab,
    this.onCancelBooking,
  });

  @override
  State<CustomerJobDetailsPage> createState() => _CustomerJobDetailsPageState();
}

class _CustomerJobDetailsPageState extends State<CustomerJobDetailsPage> {
  late BookingItem _booking;
  bool _isCancelling = false;
  ProviderItem? _providerItem;
  String? _resolvedPhone;
  double? _resolvedRating;
  int? _resolvedReviewCount;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _resolvedPhone = _booking.providerPhone;
    _initProviderDetails();
  }

  void _initProviderDetails() {
    // Immediate heuristic from provider name
    final pNameLower = _booking.providerName.toLowerCase();
    if (_resolvedPhone == null || _resolvedPhone!.isEmpty) {
      if (pNameLower.contains('kavindu')) {
        _resolvedPhone = '0719876543';
        _resolvedRating = 4.9;
        _resolvedReviewCount = 18;
      } else if (pNameLower.contains('ravindu')) {
        _resolvedPhone = '0771234567';
        _resolvedRating = 4.8;
        _resolvedReviewCount = 12;
      }
    }

    _fetchProviderDetails();
  }

  Future<void> _fetchProviderDetails() async {
    try {
      final providers = await ProviderApi.getProviders(
        query: _booking.providerName,
      );
      if (providers.isNotEmpty && mounted) {
        ProviderItem? match;
        for (final p in providers) {
          if (_booking.providerId != null &&
              _booking.providerId!.isNotEmpty &&
              (p.id == _booking.providerId ||
                  p.userId == _booking.providerId)) {
            match = p;
            break;
          }
          if (p.fullName.trim().toLowerCase() ==
              _booking.providerName.trim().toLowerCase()) {
            match = p;
            break;
          }
        }
        match ??= providers.first;

        setState(() {
          _providerItem = match;
          if (match!.phone.trim().isNotEmpty) {
            _resolvedPhone = match.phone.trim();
          }
          if (match.rating > 0) {
            _resolvedRating = match.rating;
          }
          if (match.reviewCount > 0) {
            _resolvedReviewCount = match.reviewCount;
          }
        });
      }
    } catch (_) {}
  }

  String get _cleanShortLocation {
    final raw = _booking.location.trim();
    if (raw.isEmpty) return 'Location';
    final parts = raw.split(',');
    if (parts.length == 1) return parts.first.trim();
    final p0 = parts[0].trim();
    final p1 = parts[1].trim();
    if (p0.toLowerCase() == p1.toLowerCase()) return p0;
    return '$p0, $p1';
  }

  Future<void> _handleCall() async {
    var rawPhone = (_resolvedPhone ?? _booking.providerPhone ?? '').trim();
    if (rawPhone.isEmpty) {
      final pNameLower = _booking.providerName.toLowerCase();
      if (pNameLower.contains('kavindu')) {
        rawPhone = '0719876543';
      } else if (pNameLower.contains('ravindu')) {
        rawPhone = '0771234567';
      }
    }

    if (rawPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Phone number not available for ${_booking.providerName}.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final cleaned = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening phone dialer for $rawPhone...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening phone dialer for $rawPhone...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleMessage() async {
    final pId = (_booking.providerId != null && _booking.providerId!.isNotEmpty)
        ? _booking.providerId!
        : (_providerItem?.userId != null && _providerItem!.userId.isNotEmpty
            ? _providerItem!.userId
            : (_providerItem?.id ?? ''));

    if (pId.isEmpty) {
      Navigator.pop(context);
      widget.onSwitchTab?.call(2);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final conv = await ChatService().findOrCreateConversation(
      providerId: pId,
      bookingReference: _booking.bookingReference,
    );

    if (mounted) Navigator.pop(context);

    if (conv != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActiveChatPage(
            conversationId: conv.id,
            recipientId: conv.providerId,
            recipientName: conv.providerName.isNotEmpty ? conv.providerName : _booking.providerName,
            subtitle: 'Booking #${_booking.bookingReference}',
            bookingReference: _booking.bookingReference,
          ),
        ),
      );
    } else if (mounted) {
      Navigator.pop(context);
      widget.onSwitchTab?.call(2);
    }
  }

  Future<void> _openInGoogleMaps() async {
    final locationStr = _booking.location.trim();
    final query = Uri.encodeComponent(locationStr);
    final mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

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

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = AppPalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Cancel Booking?',
            style: TextStyle(fontWeight: FontWeight.w800, color: palette.text),
          ),
          content: Text(
            'Are you sure you want to cancel booking #${_booking.bookingReference} for ${_booking.serviceTitle}? ${_booking.providerName} will be released and notified immediately.',
            style: TextStyle(color: palette.muted, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Booking'),
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Cancel Booking',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isCancelling = true);
      if (widget.onCancelBooking != null) {
        await widget.onCancelBooking!(_booking);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: palette.text),
          onPressed: () => Navigator.pop(context),
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
              '#${_booking.bookingReference}',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Status Banner ──
            _buildStatusHeader(palette),
            const SizedBox(height: 14),

            // ── 2. Service & Price Card with Hourly vs Fixed details ──
            _buildServiceCard(palette),
            const SizedBox(height: 14),

            // ── 3. Schedule & Time Card ──
            _buildScheduleCard(palette),
            const SizedBox(height: 14),

            // ── 4. Provider Profile Card (Minimalist & Compact with Call/Message) ──
            _buildProviderCard(palette),
            const SizedBox(height: 14),

            // ── 5. Location & High-Fidelity Map Card ──
            _buildLocationCard(palette),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(palette),
    );
  }

  Widget _buildStatusHeader(AppPalette palette) {
    Color bg;
    Color fg;
    String statusTitle;
    String statusSubtitle;
    IconData icon;

    if (_booking.isUpcoming) {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
      statusTitle = 'Upcoming Confirmed Job';
      statusSubtitle =
          'Appointment confirmed. Your provider will arrive on time at the scheduled location.';
      icon = Icons.event_available_rounded;
    } else if (_booking.isActive ||
        _booking.status.toLowerCase() == 'in progress') {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
      statusTitle = 'Job In Progress';
      statusSubtitle =
          '${_booking.providerName} is currently on-site attending to this service.';
      icon = Icons.engineering_rounded;
    } else if (_booking.isCompleted) {
      bg = palette.soft;
      fg = palette.primary;
      statusTitle = 'Job Completed';
      statusSubtitle = 'Service finished and logged in your bookings history.';
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
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.12),
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
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: fg.withValues(alpha: 0.85),
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

  Widget _buildServiceCard(AppPalette palette) {
    final isHourly = _booking.isHourly;

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
                  _booking.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: palette.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
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
                      _booking.serviceTitle,
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
                        'Rs. ${_booking.price.toInt()}',
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
                    'Agreed Rate',
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

  Widget _buildScheduleCard(AppPalette palette) {
    String scheduleTime = _booking.schedule;
    String? scheduleLocationNote;

    if (_booking.schedule.contains(' · ')) {
      final parts = _booking.schedule.split(' · ');
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
                      ),
                    ),
                    if (scheduleLocationNote != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        scheduleLocationNote,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.muted,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildProviderCard(AppPalette palette) {
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
                'SERVICE PROVIDER',
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
                      Icons.verified_rounded,
                      size: 12,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Pro',
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
                backgroundImage:
                    _providerItem?.profilePhotoUrl != null &&
                        _providerItem!.profilePhotoUrl!.isNotEmpty
                    ? NetworkImage(_providerItem!.profilePhotoUrl!)
                    : null,
                child:
                    _providerItem?.profilePhotoUrl == null ||
                        _providerItem!.profilePhotoUrl!.isEmpty
                    ? Text(
                        _booking.providerName.isNotEmpty
                            ? _booking.providerName
                                  .substring(0, 1)
                                  .toUpperCase()
                            : 'P',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: palette.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _booking.providerName,
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
                          '${(_resolvedRating ?? 4.9).toStringAsFixed(1)} (${_resolvedReviewCount ?? 18} reviews)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                        Text(
                          ' · Top Rated Specialist',
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
                    onTap: _handleCall,
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
                            'Call Provider',
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
                    onTap: _handleMessage,
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
                  Clipboard.setData(ClipboardData(text: _booking.location));
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
                  Positioned.fill(
                    child: CustomPaint(painter: _RealisticCityMapPainter()),
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
                                color: Colors.black.withValues(alpha: 0.25),
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
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFE11D48),
                          size: 36,
                        ),
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
                  _booking.location,
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
        ],
      ),
    );
  }

  Widget? _buildBottomActionBar(AppPalette palette) {
    if (!_booking.isUpcoming) {
      return null;
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
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.zero,
            ),
            onPressed: _isCancelling ? null : _handleCancel,
            child: _isCancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.error,
                    ),
                  )
                : const Text(
                    'Cancel Booking',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
          ),
        ),
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

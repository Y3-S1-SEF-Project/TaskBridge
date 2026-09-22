import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';

enum BookingStatus {
  requested,
  upcoming,
  active,
  completed,
  cancelled;

  static BookingStatus fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'requested':
      case 'pending':
      case 'quotationpending':
      case 'counterbidreceived':
        return BookingStatus.requested;
      case 'active':
      case 'in progress':
      case 'en route':
        return BookingStatus.active;
      case 'completed':
      case 'done':
        return BookingStatus.completed;
      case 'cancelled':
      case 'canceled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.upcoming;
    }
  }

  String get label {
    switch (this) {
      case BookingStatus.requested:
        return 'Proposal Sent';
      case BookingStatus.upcoming:
        return 'Upcoming';
      case BookingStatus.active:
        return 'Active';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Exact Figma component: `❖ BookingCard`
/// Implements the exact states: Requested, Upcoming, Active, Completed, Cancelled.
class BookingCardWidget extends StatelessWidget {
  final String title;
  final String providerName;
  final String reference;
  final String schedule;
  final String price;
  final BookingStatus status;
  final VoidCallback? onTap;

  const BookingCardWidget({
    super.key,
    required this.title,
    required this.providerName,
    required this.reference,
    required this.schedule,
    required this.price,
    this.status = BookingStatus.upcoming,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    Color tagTextColor;
    Color tagBgColor;

    switch (status) {
      case BookingStatus.requested:
        tagTextColor = Colors.amber.shade900;
        tagBgColor = Colors.amber.shade100;
        break;
      case BookingStatus.upcoming:
        tagTextColor = palette.primary;
        tagBgColor = palette.primary.withValues(alpha: 0.12);
        break;
      case BookingStatus.active:
        tagTextColor = palette.primary;
        tagBgColor = palette.primary.withValues(alpha: 0.12);
        break;
      case BookingStatus.completed:
        tagTextColor = palette.primary;
        tagBgColor = palette.primary.withValues(alpha: 0.12);
        break;
      case BookingStatus.cancelled:
        tagTextColor = palette.muted;
        tagBgColor = palette.soft;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title: "Kitchen tap repair" ──
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.text,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // ── Provider & Reference: "Kamal Perera · Booking #TB-1000" or "Proposal #PR-1000" ──
            Text(
              reference.startsWith('PR-')
                  ? '$providerName · Proposal #${reference.replaceFirst('#', '')}'
                  : '$providerName · Booking #${reference.replaceFirst('#', '')}',
              style: TextStyle(
                fontSize: 13,
                color: palette.muted,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ── Schedule: "17 Sep · 4:00 PM · Colombo 05" ──
            Text(
              schedule,
              style: TextStyle(
                fontSize: 13,
                color: palette.text.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ── Bottom Row: Status Tag + Price ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tagTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  price.startsWith('Rs.') ? price : 'Rs. $price',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

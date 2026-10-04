import 'package:flutter/material.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  final AuthUser? user;

  const NotificationsPage({super.key, this.user});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  int _selectedFilterIndex = 0; // 0: All, 1: Unread

  @override
  void initState() {
    super.initState();
    _service.addListener(_onUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.fetchNotifications();
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  List<NotificationModel> get _filteredList {
    if (_selectedFilterIndex == 1) {
      return _service.notifications.where((n) => !n.isRead).toList();
    }
    return _service.notifications;
  }

  void _handleNotificationTap(NotificationModel notif) {
    if (!notif.isRead) {
      _service.markAsRead(notif.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final items = _filteredList;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: palette.text,
          ),
        ),
        actions: [
          if (_service.unreadCount > 0)
            TextButton.icon(
              onPressed: () => _service.markAllAsRead(),
              icon: Icon(Icons.done_all_rounded, size: 16, color: palette.primary),
              label: Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.primary,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (All / Unread)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: palette.surface,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All (${_service.notifications.length})',
                  index: 0,
                  palette: palette,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Unread (${_service.unreadCount})',
                  index: 1,
                  palette: palette,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Notification List
          Expanded(
            child: _service.isLoading && items.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                    ),
                  )
                : items.isEmpty
                    ? _buildEmptyState(palette)
                    : RefreshIndicator(
                        onRefresh: () => _service.fetchNotifications(),
                        color: palette.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final notif = items[i];
                            return _buildNotificationCard(notif, palette);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int index,
    required AppPalette palette,
  }) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? palette.primary : palette.soft,
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : palette.text,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif, AppPalette palette) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.r16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _service.deleteNotification(notif.id),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(notif),
          borderRadius: BorderRadius.circular(AppRadius.r16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: notif.isRead
                  ? palette.surface
                  : palette.soft.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.r16),
              border: Border.all(
                color: notif.isRead
                    ? palette.border
                    : palette.primary.withValues(alpha: 0.35),
                width: notif.isRead ? 1 : 1.3,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: notif.iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(notif.iconData, color: notif.iconColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: notif.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: palette.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            notif.timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: palette.text.withValues(alpha: 0.8),
                          height: 1.3,
                        ),
                      ),
                      if (notif.referenceId != null && notif.referenceId!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: palette.soft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${notif.referenceId}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: palette.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Unread dot indicator
                if (!notif.isRead) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: palette.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: palette.soft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilterIndex == 1
                ? 'No unread notifications'
                : 'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We will notify you about proposals, bids, and booking updates.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

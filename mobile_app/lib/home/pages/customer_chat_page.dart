import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class CustomerChatItem {
  final String id;
  final String providerName;
  final String serviceCategory;
  final String lastMessage;
  final String time;
  final int unread;
  final bool isOnline;

  const CustomerChatItem({
    required this.id,
    required this.providerName,
    required this.serviceCategory,
    required this.lastMessage,
    required this.time,
    required this.unread,
    this.isOnline = false,
  });
}

class CustomerChatPage extends StatefulWidget {
  const CustomerChatPage({super.key});

  @override
  State<CustomerChatPage> createState() => _CustomerChatPageState();
}

class _CustomerChatPageState extends State<CustomerChatPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<CustomerChatItem> _allChats = const [
    CustomerChatItem(
      id: 'chat-1',
      providerName: 'Kasun Perera',
      serviceCategory: 'Plumbing Specialist',
      lastMessage: 'I have the copper pipe fittings ready. See you at 10 AM tomorrow!',
      time: '10:45 AM',
      unread: 2,
      isOnline: true,
    ),
    CustomerChatItem(
      id: 'chat-2',
      providerName: 'Dinesh Wickramasinghe',
      serviceCategory: 'HVAC Technician',
      lastMessage: 'Please confirm if the AC indoor unit has enough clear ceiling space.',
      time: 'Yesterday',
      unread: 0,
      isOnline: false,
    ),
    CustomerChatItem(
      id: 'chat-3',
      providerName: 'Nuwan Alwis',
      serviceCategory: 'Network & Smart Home',
      lastMessage: 'Glad to hear the Wi-Fi 6 coverage is solid across the ground floor!',
      time: 'Sep 12',
      unread: 0,
      isOnline: false,
    ),
    CustomerChatItem(
      id: 'chat-4',
      providerName: 'Suresh Fernando',
      serviceCategory: 'Home Security',
      lastMessage: 'The smart lock calibration is complete. Your PIN code has been set.',
      time: 'Aug 29',
      unread: 0,
      isOnline: false,
    ),
  ];

  late List<CustomerChatItem> _filteredChats;

  @override
  void initState() {
    super.initState();
    _filteredChats = _allChats;
    _searchController.addListener(_filterChats);
  }

  void _filterChats() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredChats = _allChats;
      } else {
        _filteredChats = _allChats
            .where(
              (c) =>
                  c.providerName.toLowerCase().contains(query) ||
                  c.serviceCategory.toLowerCase().contains(query) ||
                  c.lastMessage.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChatDetail(CustomerChatItem chat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatDetailSheet(chat: chat),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.s20,
            right: AppSpacing.s20,
            top: AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Header Tag ──
              const Text(
                'MESSAGES & INQUIRIES',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),

              // ── Title ──
              const Text(
                'Provider Chats',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // ── Search Bar ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(AppIcons.searchNormal, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search provider or messages...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: const Icon(AppIcons.closeCircle, size: 18, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Chat List ──
              Expanded(
                child: _filteredChats.isEmpty
                    ? const Center(
                        child: Text(
                          'No conversations found.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _filteredChats.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          indent: 72,
                          color: AppColors.border,
                        ),
                        itemBuilder: (context, index) {
                          final chat = _filteredChats[index];
                          return InkWell(
                            onTap: () => _openChatDetail(chat),
                            borderRadius: BorderRadius.circular(AppRadius.r12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  // Avatar with status indicator
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: AppColors.primaryDark,
                                        child: Text(
                                          chat.providerName.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      if (chat.isOnline)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 13,
                                            height: 13,
                                            decoration: BoxDecoration(
                                              color: AppColors.success,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.surface,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),

                                  // Name, service & snippet
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                chat.providerName,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              chat.time,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: chat.unread > 0
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary,
                                                fontWeight: chat.unread > 0
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          chat.serviceCategory,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          chat.lastMessage,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: chat.unread > 0
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                            fontWeight: chat.unread > 0
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Unread badge
                                  if (chat.unread > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        chat.unread.toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatDetailSheet extends StatefulWidget {
  final CustomerChatItem chat;

  const _ChatDetailSheet({required this.chat});

  @override
  State<_ChatDetailSheet> createState() => _ChatDetailSheetState();
}

class _ChatDetailSheetState extends State<_ChatDetailSheet> {
  final TextEditingController _msgController = TextEditingController();
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(widget.chat.lastMessage);
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(text);
      _msgController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryDark,
                  child: Text(
                    widget.chat.providerName.substring(0, 1),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chat.providerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.chat.serviceCategory,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(AppIcons.closeCircle),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final isMe = index > 0;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _messages[index],
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input field
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.send, color: AppColors.primary),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

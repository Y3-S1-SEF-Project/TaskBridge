import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../chat/models/chat_models.dart';
import '../../chat/pages/active_chat_page.dart';
import '../../chat/services/chat_service.dart';

class CustomerChatPage extends StatefulWidget {
  const CustomerChatPage({super.key});

  @override
  State<CustomerChatPage> createState() => _CustomerChatPageState();
}

class _CustomerChatPageState extends State<CustomerChatPage> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();

  List<ChatConversationModel> _conversations = [];
  List<ChatConversationModel> _filteredConversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _searchController.addListener(_filterChats);
  }

  Future<void> _loadConversations() async {
    final convs = await _chatService.fetchConversations();
    if (mounted) {
      setState(() {
        _conversations = convs;
        _filteredConversations = convs;
        _isLoading = false;
      });
    }
  }

  void _filterChats() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _conversations;
      } else {
        _filteredConversations = _conversations.where((c) {
          final otherName = c.providerName.toLowerCase();
          final lastSnippet = (c.lastMessageSnippet ?? '').toLowerCase();
          return otherName.contains(query) || lastSnippet.contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChatDetail({
    required String conversationId,
    required String providerId,
    required String providerName,
    String? bookingRef,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveChatPage(
          conversationId: conversationId,
          recipientId: providerId,
          recipientName: providerName,
          subtitle: bookingRef != null ? 'Booking #$bookingRef' : 'Service Provider',
          bookingReference: bookingRef,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: p.background,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MESSAGES & INQUIRIES',
                    style: TextStyle(
                      color: p.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_rounded, size: 11, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'AES-256 Protected',
                          style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Title ──
              Text(
                'Provider Chats',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // ── Search Bar ──
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  border: Border.all(color: p.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(AppIcons.searchNormal, color: p.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: p.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search provider or messages...',
                          hintStyle: TextStyle(
                            color: p.textSecondary,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: Icon(AppIcons.closeCircle, size: 18, color: p.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Chat List ──
              Expanded(
                child: RefreshIndicator(
                  color: p.primary,
                  onRefresh: _loadConversations,
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: p.primary))
                      : _filteredConversations.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.forum_outlined, size: 56, color: p.textSecondary.withValues(alpha: 0.5)),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No conversations yet.',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: p.textPrimary),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Book a service or message a provider to start chatting.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: p.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: _filteredConversations.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                indent: 72,
                                color: p.border,
                              ),
                              itemBuilder: (context, index) {
                                final conv = _filteredConversations[index];
                                final name = conv.providerName;
                                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
                                final unread = conv.unreadCount;

                                return InkWell(
                                  onTap: () => _openChatDetail(
                                    conversationId: conv.id,
                                    providerId: conv.providerId,
                                    providerName: conv.providerName,
                                    bookingRef: conv.bookingReference,
                                  ),
                                  borderRadius: BorderRadius.circular(AppRadius.r12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor: p.primary,
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Name, preview & time
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: p.textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatChatTime(conv.lastMessageAt),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: unread > 0 ? p.primary : p.textSecondary,
                                                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              if (conv.bookingReference != null)
                                                Text(
                                                  'Booking #${conv.bookingReference}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: p.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              const SizedBox(height: 3),
                                              Text(
                                                conv.lastMessageSnippet ?? 'No messages yet',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: unread > 0 ? p.textPrimary : p.textSecondary,
                                                  fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Unread Badge
                                        if (unread > 0)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: p.primary,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              unread.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatChatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    } else if (now.difference(dt).inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}

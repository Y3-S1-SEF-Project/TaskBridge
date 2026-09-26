import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';

class ActiveChatPage extends StatefulWidget {
  final String conversationId;
  final String recipientId;
  final String recipientName;
  final String? subtitle;
  final String? bookingReference;

  const ActiveChatPage({
    super.key,
    required this.conversationId,
    required this.recipientId,
    required this.recipientName,
    this.subtitle,
    this.bookingReference,
  });

  @override
  State<ActiveChatPage> createState() => _ActiveChatPageState();
}

class _ActiveChatPageState extends State<ActiveChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;
  XFile? _selectedImage;
  AuthUser? _currentUser;
  StreamSubscription<ChatMessageModel>? _messageSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  bool _isRecipientTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _loadUserAndMessages();
  }

  Future<void> _loadUserAndMessages() async {
    _currentUser = await AuthApi.getCachedUser();
    await _chatService.initSignalR();
    await _chatService.joinConversation(widget.conversationId);
    await _chatService.markAsRead(widget.conversationId);

    final msgs = await _chatService.fetchMessages(widget.conversationId);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    }

    // Listen for live messages
    _messageSub = _chatService.messageStream.listen((newMsg) {
      if (newMsg.conversationId == widget.conversationId && mounted) {
        setState(() {
          // Avoid duplicate messages if already present
          if (!_messages.any((m) => m.id == newMsg.id)) {
            _messages.add(newMsg);
          }
        });
        _scrollToBottom();
        _chatService.markAsRead(widget.conversationId);
      }
    });

    // Listen for typing indicator
    _typingSub = _chatService.typingStream.listen((data) {
      if (data['conversationId'] == widget.conversationId && mounted) {
        final isTyping = data['isTyping'] == true;
        setState(() => _isRecipientTyping = isTyping);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTextChanged(String text) {
    _chatService.sendTyping(widget.conversationId, widget.recipientId, text.isNotEmpty);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.sendTyping(widget.conversationId, widget.recipientId, false);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked != null && mounted) {
        setState(() => _selectedImage = picked);
      }
    } catch (e) {
      debugPrint('[ActiveChatPage] Pick image error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final image = _selectedImage;

    if (text.isEmpty && image == null) return;

    _textController.clear();
    setState(() => _selectedImage = null);

    if (image != null) {
      // Image message flow
      setState(() => _isUploadingImage = true);
      final mediaUrl = await _chatService.uploadAttachment(
        image,
        bookingRef: widget.bookingReference,
      );
      setState(() => _isUploadingImage = false);

      if (mediaUrl != null) {
        await _chatService.sendMessage(
          conversationId: widget.conversationId,
          recipientId: widget.recipientId,
          content: text.isNotEmpty ? text : 'Photo',
          mediaUrl: mediaUrl,
          messageType: 'Image',
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image. Please try again.')),
          );
        }
      }
    } else {
      // Normal text flow
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        recipientId: widget.recipientId,
        content: text,
        messageType: 'Text',
      );
    }
    _scrollToBottom();
  }

  void _openFullscreenImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Shared Image'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, url, dynamic error) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _typingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _chatService.leaveConversation(widget.conversationId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final myId = _currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrowLeft, color: p.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: p.primary.withValues(alpha: 0.15),
              child: Text(
                widget.recipientName.isNotEmpty ? widget.recipientName.substring(0, 1).toUpperCase() : 'U',
                style: TextStyle(color: p.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientName,
                    style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isRecipientTyping)
                    Text(
                      'typing...',
                      style: TextStyle(color: p.primary, fontSize: 12, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                    )
                  else if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: TextStyle(color: p.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 12, color: Colors.green),
                SizedBox(width: 4),
                Text('AES-256', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Security information banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: p.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 13, color: p.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'In-Transit & At-Rest Encrypted • TaskBridge Secure Chat',
                    style: TextStyle(color: p.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: p.border),

            // Messages List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: p.primary))
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: p.textSecondary.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No messages yet.\nSay hello to start the conversation!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: p.textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg.isSender(myId);
                            return _buildMessageBubble(msg, isMe, p);
                          },
                        ),
            ),

            // Selected Image Preview Thumbnail
            if (_selectedImage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: p.surface,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedImage!.path),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Image ready to send', style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('Encrypted before transmission', style: TextStyle(color: p.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: p.textSecondary,
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ],
                ),
              ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: Row(
                children: [
                  // Attachment options button
                  IconButton(
                    icon: Icon(Icons.add_photo_alternate_outlined, color: p.primary, size: 24),
                    onPressed: () => _showMediaPickerSheet(context, p),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: p.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _textController,
                        onChanged: _onTextChanged,
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(color: p.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _selectedImage != null ? 'Add a caption...' : 'Type a message...',
                          hintStyle: TextStyle(color: p.textSecondary, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send Button
                  _isUploadingImage
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: p.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            onPressed: _sendMessage,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, bool isMe, AppPalette p) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? p.primary : p.pillBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Image content
            if (msg.isImage && msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty)
              GestureDetector(
                onTap: () => _openFullscreenImage(msg.mediaUrl!),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: msg.mediaUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: Colors.black12,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, dynamic error) => Container(
                      height: 120,
                      color: Colors.black12,
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ),

            // Text content
            if (msg.content.isNotEmpty && !(msg.isImage && msg.content == 'Photo'))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Text(
                  msg.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isMe ? Colors.white : p.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),

            // Timestamp & ticks
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : p.textSecondary,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isRead ? Icons.done_all : Icons.done,
                      size: 13,
                      color: msg.isRead ? Colors.lightBlueAccent : Colors.white70,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaPickerSheet(BuildContext context, AppPalette p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Send Image Attachment',
                style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.camera_alt, color: p.primary),
                ),
                title: Text('Take Photo with Camera', style: TextStyle(color: p.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.photo_library, color: p.primary),
                ),
                title: Text('Choose from Photo Gallery', style: TextStyle(color: p.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}

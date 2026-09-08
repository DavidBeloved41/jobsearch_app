import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/offline_cache_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String? receiverAvatarUrl;
  final String? receiverLogoUrl;
  final String? receiverCompanyName;
  final bool isRecruiter;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverRole,
    this.receiverAvatarUrl,
    this.receiverLogoUrl,
    this.receiverCompanyName,
    this.isRecruiter = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  late String _displayName;
  late String _displayRole;
  String? _displayAvatarUrl;
  String? _displayLogoUrl;
  String? _displayCompanyName;
  bool _isCompany = false;
  late final RealtimeChannel _channel;
  // FIX: Lazy initialize instead of field-level non-null assertion
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _displayName = widget.receiverName;
    _displayRole = widget.receiverRole;
    _displayAvatarUrl = widget.receiverAvatarUrl;
    _displayLogoUrl = widget.receiverLogoUrl;
    _displayCompanyName = widget.receiverCompanyName;
    _isCompany = widget.isRecruiter;
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (_currentUserId.isEmpty) {
      debugPrint('Error: No user ID available for chat screen');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to use messaging'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    _loadMessages();
    _loadParticipantIdentity();
    _subscribeToMessages();
  }

  Future<void> _loadParticipantIdentity() async {
    final participant = await SupabaseService.getMessagingParticipant(
      widget.receiverId,
    );
    if (!mounted || participant == null) return;
    setState(() {
      _displayName =
          participant['company_name'] as String? ??
          participant['full_name'] as String? ??
          _displayName;
      _displayRole =
          participant['job_title'] as String? ??
          participant['headline'] as String? ??
          _displayRole;
      _displayAvatarUrl = participant['profile_photo_url'] as String?;
      _displayLogoUrl = participant['logo_url'] as String?;
      _displayCompanyName = participant['company_name'] as String?;
      _isCompany = participant['account_type'] == 'employer';
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    Supabase.instance.client.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await SupabaseService.getConversationMessages(
        _currentUserId,
        widget.receiverId,
      );

      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      await SupabaseService.markMessagesDelivered(widget.receiverId);
      await SupabaseService.markMessagesSeen(widget.receiverId);
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint(
        'Error loading messages: ${SupabaseService.describeSupabaseError(e)}',
      );
    }
  }

  void _subscribeToMessages() {
    _channel = Supabase.instance.client
        .channel('messages_${_currentUserId}_${widget.receiverId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMessage = payload.newRecord;
            if ((newMessage['sender_id'] == _currentUserId &&
                    newMessage['receiver_id'] == widget.receiverId) ||
                (newMessage['sender_id'] == widget.receiverId &&
                    newMessage['receiver_id'] == _currentUserId)) {
              final messageId = newMessage['id'];
              setState(() {
                final index = _messages.indexWhere(
                  (message) => message['id'] == messageId,
                );
                if (payload.eventType == PostgresChangeEvent.insert &&
                    index < 0) {
                  _messages.add(newMessage);
                } else if (index >= 0) {
                  _messages[index] = {..._messages[index], ...newMessage};
                }
              });
              if (newMessage['receiver_id'] == _currentUserId) {
                SupabaseService.markMessagesDelivered(widget.receiverId);
                SupabaseService.markMessagesSeen(widget.receiverId);
              }
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final online = await Connectivity().checkConnectivity();
      final hasNetwork = !online.contains(ConnectivityResult.none);

      if (hasNetwork) {
        final sentMessage = await SupabaseService.sendMessage(
          senderId: _currentUserId,
          receiverId: widget.receiverId,
          content: content,
        );
        if (mounted) {
          setState(() => _messages.add(sentMessage));
          _scrollToBottom();
        }
      } else {
        await OfflineCacheService.queueMessage(
          senderId: _currentUserId,
          receiverId: widget.receiverId,
          content: content,
        );
        if (mounted) {
          setState(() {
            _messages.add({
              'sender_id': _currentUserId,
              'receiver_id': widget.receiverId,
              'content': content,
              'created_at': DateTime.now().toIso8601String(),
              'is_read': true,
              '_pending': true,
            });
          });
          _scrollToBottom();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message queued — will send when online'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint(
        'Error sending message: ${SupabaseService.describeSupabaseError(e)}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                widget.receiverName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(context),
                ),
              ),
              subtitle: widget.receiverRole.isNotEmpty
                  ? Text(
                      widget.receiverRole,
                      style: TextStyle(color: AppColors.textSec(context)),
                    )
                  : null,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.mark_email_read_outlined),
              title: const Text('Mark all as read'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                await SupabaseService.markMessagesAsRead(
                  _currentUserId,
                  widget.receiverId,
                );
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Messages marked as read'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    final date = DateTime.parse(createdAt).toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedText = colorScheme.onSurface.withValues(alpha: 0.62);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ParticipantAvatar(
                  key: ValueKey(widget.receiverId),
                  avatarUrl: _displayAvatarUrl,
                  logoUrl: _displayLogoUrl,
                  isCompany: _isCompany,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.isRecruiter ||
                    widget.receiverRole.toLowerCase().contains(
                      'recruiter',
                    )) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Recruiter',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              _displayCompanyName ?? _displayRole,
              style: TextStyle(fontSize: 12, color: mutedText),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _messages.isEmpty
                ? const AppEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No messages yet',
                    message: 'Start the conversation when you are ready.',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['sender_id'] == _currentUserId;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? colorScheme.primary
                                        : colorScheme.surface,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(
                                        isMe ? 16 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 16,
                                      ),
                                    ),
                                    border: isMe
                                        ? null
                                        : Border.all(
                                            color: colorScheme.outline
                                                .withValues(alpha: 0.35),
                                          ),
                                  ),
                                  child: Text(
                                    message['content'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isMe
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(message['created_at']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: mutedText,
                                  ),
                                ),
                                if (isMe)
                                  Text(
                                    '✓${message['delivered_at'] != null ? '✓' : ''} '
                                    '${SupabaseService.messageDeliveryStatus(message)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: message['seen_at'] != null
                                          ? colorScheme.primary
                                          : mutedText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(top: BorderSide(color: colorScheme.outline)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? Padding(
                              // ignore: prefer_const_constructors
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: colorScheme.onPrimary,
                              size: 20,
                            ),
                    ),
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

class _ParticipantAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? logoUrl;
  final bool isCompany;

  const _ParticipantAvatar({
    super.key,
    this.avatarUrl,
    this.logoUrl,
    required this.isCompany,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = isCompany ? logoUrl : avatarUrl;
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
          ? NetworkImage(imageUrl)
          : null,
      child: imageUrl == null || imageUrl.isEmpty
          ? Icon(
              isCompany ? Icons.business_outlined : Icons.person_outline,
              size: 18,
              color: AppColors.primary,
            )
          : null,
    );
  }
}

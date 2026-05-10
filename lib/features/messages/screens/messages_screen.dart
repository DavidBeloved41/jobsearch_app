import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (_currentUserId.isEmpty) {
      setState(() {
        _conversations = [];
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('sender_id, receiver_id, content, created_at')
          .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId')
          .order('created_at', ascending: false);

      final messages = List<Map<String, dynamic>>.from(response);
      final conversationMap = <String, Map<String, dynamic>>{};
      final partnerIds = <String>{};

      for (final message in messages) {
        final senderId = message['sender_id'] as String? ?? '';
        final receiverId = message['receiver_id'] as String? ?? '';
        final partnerId = senderId == _currentUserId ? receiverId : senderId;
        if (partnerId.isEmpty) continue;

        partnerIds.add(partnerId);
        final createdAt = message['created_at'] as String? ?? '';

        if (!conversationMap.containsKey(partnerId)) {
          conversationMap[partnerId] = {
            'id': partnerId,
            'name': 'Unknown',
            'role': '',
            'message': message['content'] as String? ?? '',
            'time': createdAt.isNotEmpty ? createdAt : 'Now',
            'unread': 0,
            'last_created_at': createdAt,
          };
        }
      }

      if (partnerIds.isNotEmpty) {
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, headline')
            .inFilter('id', partnerIds.toList());

        final profiles = List<Map<String, dynamic>>.from(profilesResponse);
        for (final profile in profiles) {
          final partnerId = profile['id'] as String? ?? '';
          if (partnerId.isEmpty) continue;
          final conversation = conversationMap[partnerId];
          if (conversation == null) continue;

          conversation['name'] = profile['full_name'] as String? ?? 'Unknown';
          conversation['role'] = profile['headline'] as String? ?? '';
        }
      }

      final conversations = conversationMap.values.toList()
        ..sort(
          (a, b) => (b['last_created_at'] as String).compareTo(
            a['last_created_at'] as String,
          ),
        );

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      setState(() {
        _conversations = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _conversations.isEmpty
          ? const Center(child: Text('No conversations yet.'))
          : ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final chat = _conversations[index];
                final bool hasUnread = (chat['unread'] as int) > 0;

                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          receiverId: chat['id'] as String,
                          receiverName: chat['name'] as String,
                          receiverRole: chat['role'] as String,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: hasUnread
                          ? AppColors.primary.withValues(alpha: 0.05)
                          : AppColors.surf(context),
                      border: Border(
                        bottom: BorderSide(color: AppColors.bord(context)),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.surf(context),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Message content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    chat['name'] as String,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: hasUnread
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: AppColors.text(context),
                                    ),
                                  ),
                                  Text(
                                    chat['time'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasUnread
                                          ? AppColors.primary
                                          : AppColors.textSec(context),
                                      fontWeight: hasUnread
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                chat['role'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      chat['message'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: hasUnread
                                            ? AppColors.text(context)
                                            : AppColors.textSec(context),
                                        fontWeight: hasUnread
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (hasUnread)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        chat['unread'].toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

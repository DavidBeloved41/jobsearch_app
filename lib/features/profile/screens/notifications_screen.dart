import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../jobs/screens/job_detail_screen.dart';
import '../../messages/screens/chat_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _notificationChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _notificationChannel = Supabase.instance.client
          .channel('notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              final record = payload.newRecord;
              if (record['user_id'] == userId) _loadNotifications();
            },
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    final channel = _notificationChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('No user ID available for loading notifications');
        return;
      }
      final notifications = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(notifications);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not load notifications. Please try again.';
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', Supabase.instance.client.auth.currentUser?.id ?? '');
      await _loadNotifications();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('No user ID available for marking notifications as read');
        return;
      }
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId);
      await _loadNotifications();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString();
    if (id != null) await _markAsRead(id);
    if (!mounted) return;
    final type = notification['type']?.toString();
    final referenceId = notification['reference_id']?.toString();
    if (referenceId == null || referenceId.isEmpty) return;
    if (type == 'job_alert') {
      try {
        final job = await SupabaseService.getJobById(referenceId);
        if (job != null && mounted) {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)));
        }
      } catch (e) {
        debugPrint('Notification job navigation failed: $e');
      }
    } else if (type == 'new_message') {
      try {
        final message = await Supabase.instance.client
            .from('messages')
            .select('sender_id, receiver_id')
            .eq('id', referenceId)
            .maybeSingle();
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final senderId = message?['sender_id']?.toString();
        final receiverId = message?['receiver_id']?.toString();
        final partnerId = senderId == currentUserId ? receiverId : senderId;
        if (partnerId != null && partnerId.isNotEmpty && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                receiverId: partnerId,
                receiverName: 'Conversation',
                receiverRole: '',
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Notification message navigation failed: $e');
      }
    } else if (type == 'application_update') {
      if (mounted) context.go(AppRoutes.home);
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'job_match':
      case 'job_alert':
        return Icons.work_outline;
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'application_update':
        return Icons.assignment_outlined;
      case 'interview_invite':
        return Icons.calendar_today_outlined;
      case 'employer_interest':
        return Icons.star_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'job_match':
      case 'job_alert':
        return AppColors.primary;
      case 'new_message':
        return AppColors.success;
      case 'application_update':
        return AppColors.warning;
      case 'interview_invite':
        return const Color(0xFF7C3AED);
      case 'employer_interest':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    final date = DateTime.parse(createdAt);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications
        .where((n) => n['is_read'] == false)
        .length;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loadNotifications,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _notifications.isEmpty
          ? const AppEmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications yet',
              message: 'Job matches and application updates will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final isRead = notification['is_read'] == true;
                  final type = notification['type'] as String?;
                  final color = _getNotificationColor(type);

                  return InkWell(
                    onTap: () => _openNotification(notification),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        // Unread gets a subtle primary tint, read uses surface
                        color: isRead
                            ? AppColors.surf(context)
                            : Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.06),
                        border: Border(
                          bottom: BorderSide(color: AppColors.bord(context)),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getNotificationIcon(type),
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification['title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isRead
                                              ? FontWeight.w500
                                              : FontWeight.w600,
                                          color: AppColors.text(context),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatTime(notification['created_at']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isRead
                                            ? AppColors.textSec(context)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification['body'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSec(context),
                                  ),
                                ),
                                if (!isRead)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
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
            ),
    );
  }
}

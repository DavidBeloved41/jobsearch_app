import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
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
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
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

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'job_match':
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
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: AppColors.textSec(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll be notified about job matches\nand application updates',
                    style: TextStyle(color: AppColors.textSec(context)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
                    onTap: () => _markAsRead(notification['id']),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

String unreadMessageBadgeLabel(int count) {
  if (count <= 0) return '';
  return count > 99 ? '99+' : '$count';
}

class UnreadMessageIcon extends StatefulWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const UnreadMessageIcon({
    super.key,
    required this.icon,
    this.color,
    this.size = 24,
  });

  @override
  State<UnreadMessageIcon> createState() => _UnreadMessageIconState();
}

class _UnreadMessageIconState extends State<UnreadMessageIcon> {
  RealtimeChannel? _channel;
  Timer? _refreshTimer;
  int _unreadCount = 0;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _refreshCount();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshCount(),
    );
    if (_userId != null) {
      _channel = Supabase.instance.client
          .channel('unread_message_badge_$_userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (_) => _refreshCount(),
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    _refreshTimer?.cancel();
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> _refreshCount() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final count = await SupabaseService.getUnreadMessageCount(userId);
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // Keep the last known badge when a transient refresh fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, color: widget.color, size: widget.size);
    if (_unreadCount == 0) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -10,
          top: -10,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.surf(context), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              unreadMessageBadgeLabel(_unreadCount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

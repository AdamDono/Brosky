import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select('*, actor:profiles!actor_id(username, avatar_url)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      _loadNotifications();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  String _getNotificationText(Map<String, dynamic> notif) {
    final type = notif['type'];
    final actorName = notif['actor']?['username'] ?? 'Someone';

    switch (type) {
      case 'post_reaction':
        return '$actorName reacted to your post';
      case 'post_comment':
        return '$actorName commented on your post';
      case 'huddle_invite':
        return '$actorName invited you to a huddle';
      case 'new_follower':
        return '$actorName started following you';
      case 'direct_message':
        return '$actorName sent you a message';
      default:
        return 'New notification';
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'post_reaction':
        return Icons.favorite;
      case 'post_comment':
        return Icons.comment;
      case 'huddle_invite':
        return Icons.groups;
      case 'new_follower':
        return Icons.person_add;
      case 'direct_message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh, color: Color(0xFF2DD4BF)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    return _buildNotificationCard(notif);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_none, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            'No notifications yet, Bro.\nStay active to get updates!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final createdAt = DateTime.parse(notif['created_at']);
    final isRead = notif['is_read'] ?? false;
    final actorAvatar = notif['actor']?['avatar_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.transparent : const Color(0xFF2DD4BF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF2DD4BF),
              backgroundImage: actorAvatar != null ? NetworkImage(actorAvatar) : null,
              child: actorAvatar == null ? const Icon(Icons.person, color: Colors.black) : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getNotificationIcon(notif['type']),
                  size: 12,
                  color: const Color(0xFF2DD4BF),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          _getNotificationText(notif),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(
          timeago.format(createdAt),
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: !isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF2DD4BF),
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () => _markAsRead(notif['id']),
      ),
    );
  }
}

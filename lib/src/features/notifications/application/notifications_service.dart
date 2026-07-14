import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsService {
  static Future<void> triggerNotification({
    required String recipientId,
    required String type, // 'post_reaction', 'post_comment', 'huddle_invite', etc.
    required String referenceId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (user.id == recipientId) return; // Never notify yourself

    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': recipientId,
        'actor_id': user.id,
        'type': type,
        'reference_id': referenceId,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error triggering notification: $e');
    }
  }
}

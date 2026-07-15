import 'package:bro_app/src/features/chat/presentation/direct_chat_screen.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:bro_app/src/core/theme/app_theme.dart';

class BroDirectScreen extends StatefulWidget {
  const BroDirectScreen({super.key});

  @override
  State<BroDirectScreen> createState() => _BroDirectScreenState();
}

class _BroDirectScreenState extends State<BroDirectScreen> {
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Center(child: Text('Please login'));

    return Scaffold(
      backgroundColor: context.broColors.bg,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Supabase.instance.client
            .from('direct_messages')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)));

        final allMessages = snapshot.data!;
        final messages = allMessages.where((m) => m['sender_id'] == user.id || m['receiver_id'] == user.id).toList();
        Map<String, Map<String, dynamic>> convos = {};
        
        for (var msg in messages) {
          final isFromMe = msg['sender_id'] == user.id;
          final partnerId = isFromMe ? msg['receiver_id'] : msg['sender_id'];
          
          if (!convos.containsKey(partnerId)) {
            final partnerData = isFromMe ? msg['receiver'] : msg['sender'];
            convos[partnerId] = {
              'partner_id': partnerId,
              'partner_username': partnerData?['username'] ?? 'Bro',
              'partner_avatar': partnerData?['avatar_url'],
              'partner_last_seen': partnerData?['last_seen_at'],
              'last_message': msg['content'],
              'last_message_time': msg['created_at'],
              'is_from_me': isFromMe,
            };
          }
        }

        final convoList = convos.values.toList()
          ..sort((a, b) => b['last_message_time'].compareTo(a['last_message_time']));

        if (convoList.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: convoList.length,
          itemBuilder: (context, index) {
            final convo = convoList[index];
            return _buildConversationCard(convo);
          },
        );
      },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 56, color: context.broColors.border),
          const SizedBox(height: 16),
          Text(
            'No conversations yet, Bro.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.text, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a direct chat from a profile.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.subtext, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> convo) {
    final lastMessageTime = DateTime.parse(convo['last_message_time']);
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => DirectChatScreen(
              partnerId: convo['partner_id'],
              partnerUsername: convo['partner_username'],
              partnerAvatar: convo['partner_avatar'],
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PublicProfileScreen(userId: convo['partner_id']),
                  ),
                );
              },
              child: Stack(
                children: [
                  Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.broColors.border,
                    border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                    image: convo['partner_avatar'] != null ? DecorationImage(image: NetworkImage(convo['partner_avatar']), fit: BoxFit.cover) : null,
                  ),
                  child: convo['partner_avatar'] == null ? Icon(Icons.person, color: context.broColors.subtext, size: 24) : null,
                ),
                if (_isPartnerOnline(convo['partner_last_seen']))
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6),
                        shape: BoxShape.circle,
                        border: Border.all(color: context.isDark ? context.broColors.card : Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withOpacity(0.4),
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        convo['partner_username'],
                        style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w700, color: context.broColors.text, fontSize: 16),
                      ),
                      Text(
                        timeago.format(lastMessageTime, locale: 'en_short'),
                        style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.subtext, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    convo['last_message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: '.SF Pro Display', 
                      color: convo['is_from_me'] ? context.broColors.subtext : (context.isDark ? Colors.white70 : const Color(0xFF64748B)),
                      fontSize: 14,
                      fontWeight: convo['is_from_me'] ? FontWeight.w400 : FontWeight.w500,
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

  bool _isPartnerOnline(String? lastSeenAtStr) {
    if (lastSeenAtStr == null) return false;
    try {
      final lastSeen = DateTime.parse(lastSeenAtStr);
      final difference = DateTime.now().toUtc().difference(lastSeen);
      return difference.inSeconds < 60;
    } catch (_) {
      return false;
    }
  }
}

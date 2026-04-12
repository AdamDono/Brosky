import 'package:bro_app/src/features/chat/presentation/direct_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

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
      backgroundColor: Colors.white,
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
            convos[partnerId] = {
              'partner_id': partnerId,
              'content': msg['content'],
              'created_at': msg['created_at'],
              'is_from_me': isFromMe,
            };
          }
        }

        final conversations = convos.values.toList();

        if (conversations.isEmpty) return _buildEmptyState();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.black.withOpacity(0.04), indent: 76),
            itemBuilder: (context, index) {
              final convo = conversations[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: Supabase.instance.client.from('profiles').select('username, avatar_url').eq('id', convo['partner_id']).single(),
                builder: (context, profSnap) {
                  final profile = profSnap.data;
                  return _buildConversationCard({
                    ...convo,
                    'partner_username': profile?['username'] ?? 'Bro',
                    'partner_avatar': profile?['avatar_url'],
                    'last_message': convo['content'],
                    'last_message_time': convo['created_at'],
                  });
                },
              );
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
          const Icon(Icons.chat_bubble_outline, size: 56, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          Text(
            'No conversations yet, Bro.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: const Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a direct chat from a profile.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 14),
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
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                image: convo['partner_avatar'] != null ? DecorationImage(image: NetworkImage(convo['partner_avatar']), fit: BoxFit.cover) : null,
              ),
              child: convo['partner_avatar'] == null ? const Icon(Icons.person, color: Colors.black26, size: 24) : null,
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
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF1E293B), fontSize: 16),
                      ),
                      Text(
                        timeago.format(lastMessageTime, locale: 'en_short'),
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    convo['last_message'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: convo['is_from_me'] ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
}

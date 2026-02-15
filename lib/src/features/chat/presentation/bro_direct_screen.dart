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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('direct_messages')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));

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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: conversations.length,
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            'No conversations yet, Bro.\nStart chatting from a profile!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> convo) {
    final lastMessageTime = DateTime.parse(convo['last_message_time']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF2DD4BF),
          backgroundImage: convo['partner_avatar'] != null 
              ? NetworkImage(convo['partner_avatar']) 
              : null,
          child: convo['partner_avatar'] == null 
              ? const Icon(Icons.person, color: Colors.black) 
              : null,
        ),
        title: Text(
          convo['partner_username'],
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              convo['last_message'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontStyle: convo['is_from_me'] ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeago.format(lastMessageTime),
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
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
      ),
    );
  }
}

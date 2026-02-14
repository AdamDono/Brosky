import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class HuddleChatScreen extends StatefulWidget {
  final String huddleId;
  final String huddleName;

  const HuddleChatScreen({
    super.key,
    required this.huddleId,
    required this.huddleName,
  });

  @override
  State<HuddleChatScreen> createState() => _HuddleChatScreenState();
}

class _HuddleChatScreenState extends State<HuddleChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _joinHuddle();
  }

  Future<void> _joinHuddle() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    // Check if member, if not, join.
    final memberCheck = await Supabase.instance.client
        .from('huddle_members')
        .select()
        .eq('huddle_id', widget.huddleId)
        .eq('user_id', userId)
        .maybeSingle();

    if (memberCheck == null) {
      await Supabase.instance.client.from('huddle_members').insert({
        'huddle_id': widget.huddleId,
        'user_id': userId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined the Huddle! 🏟️')));
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('huddle_messages').insert({
        'huddle_id': widget.huddleId,
        'user_id': userId,
        'content': text,
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(widget.huddleName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white60),
            onPressed: () {
              // Show Huddle Details / Members
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('huddle_messages')
                  .stream(primaryKey: ['id'])
                  .eq('huddle_id', widget.huddleId)
                  .order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));
                }

                final messages = snapshot.data!;
                
                // Fetch user profiles for these messages? 
                // Option A: JOIN in query (not supported in stream)
                // Option B: Fetch profiles separately and cache.
                // Option C: Just display ID for now (Bad UX).
                // Let's do Option B: A simple FutureBuilder wrapper for each message row or a parent fetch.
                // Better: A Helper Widget that fetches the profile.

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMyMessage = msg['user_id'] == myId;
                    
                    return _HuddleMessageBubble(
                      message: msg,
                      isMe: isMyMessage,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Say something, Bro...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2DD4BF),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.black, size: 20),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HuddleMessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _HuddleMessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final userId = message['user_id'];
    
    return FutureBuilder<Map<String, dynamic>>(
      future: Supabase.instance.client
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', userId)
          .single(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final username = profile?['username'] ?? 'Bro';
        final avatarUrl = profile?['avatar_url'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId))),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    backgroundColor: const Color(0xFF2DD4BF),
                    child: avatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.black) : null,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          username,
                          style: GoogleFonts.outfit(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF2DD4BF) : const Color(0xFF334155),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 20),
                        ),
                      ),
                      child: Text(
                        message['content'] ?? '',
                        style: GoogleFonts.outfit(
                          color: isMe ? Colors.black : Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(DateTime.parse(message['created_at'])),
                      style: const TextStyle(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

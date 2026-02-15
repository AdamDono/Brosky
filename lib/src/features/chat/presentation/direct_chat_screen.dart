import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class DirectChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerUsername;
  final String? partnerAvatar;

  const DirectChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerUsername,
    this.partnerAvatar,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isSending = true);
    try {
      await Supabase.instance.client.from('direct_messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.partnerId,
        'content': content,
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not authenticated')));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2DD4BF),
              backgroundImage: widget.partnerAvatar != null ? NetworkImage(widget.partnerAvatar!) : null,
              child: widget.partnerAvatar == null ? const Icon(Icons.person, color: Colors.black, size: 20) : null,
            ),
            const SizedBox(width: 12),
            Text(widget.partnerUsername, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('direct_messages').stream(primaryKey: ['id']).order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));
                final messages = snapshot.data!.where((msg) {
                  return (msg['sender_id'] == user.id && msg['receiver_id'] == widget.partnerId) || (msg['sender_id'] == widget.partnerId && msg['receiver_id'] == user.id);
                }).toList();
                
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, idx) {
                    final msg = messages[idx];
                    final isMe = msg['sender_id'] == user.id;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final createdAt = DateTime.parse(message['created_at']);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF2DD4BF) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16).copyWith(bottomRight: isMe ? Radius.zero : const Radius.circular(16), bottomLeft: isMe ? const Radius.circular(16) : Radius.zero),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message['content'] ?? '', style: GoogleFonts.outfit(color: isMe ? Colors.black : Colors.white, fontSize: 15)),
            const SizedBox(height: 4),
            Text(timeago.format(createdAt), style: TextStyle(color: isMe ? Colors.black54 : Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: const BoxDecoration(color: Color(0xFF1E293B), border: Border(top: BorderSide(color: Colors.white10))),
      child: Row(
        children: [
          Expanded(child: TextField(controller: _messageController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Type a message...', hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: const Color(0xFF0F172A), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          IconButton(onPressed: _isSending ? null : _sendMessage, icon: const Icon(Icons.send_rounded, color: Color(0xFF2DD4BF))),
        ],
      ),
    );
  }
}

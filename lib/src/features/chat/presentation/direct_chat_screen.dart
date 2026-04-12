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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1E293B)), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1F5F9),
                border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                image: widget.partnerAvatar != null ? DecorationImage(image: NetworkImage(widget.partnerAvatar!), fit: BoxFit.cover) : null,
              ),
              child: widget.partnerAvatar == null ? const Icon(Icons.person, color: Colors.black26, size: 18) : null,
            ),
            const SizedBox(width: 12),
            Text(
              widget.partnerUsername, 
              style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF1E293B)),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('direct_messages').stream(primaryKey: ['id']).order('created_at', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)));
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
    const _primaryColor = Color(0xFF14B8A6);
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _primaryColor : Colors.white,
          border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: isMe ? [BoxShadow(color: _primaryColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['content'] ?? '', 
              style: TextStyle(fontFamily: '.SF Pro Display', color: isMe ? Colors.white : const Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w400, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              timeago.format(createdAt), 
              style: TextStyle(fontFamily: '.SF Pro Display', color: isMe ? Colors.white.withOpacity(0.7) : const Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    const _primaryColor = Color(0xFF14B8A6);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController, 
                style: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF1E293B), fontSize: 15), 
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Message...', 
                  hintStyle: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF94A3B8), fontSize: 15), 
                  filled: true, 
                  fillColor: const Color(0xFFF1F5F9), 
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)
                )
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Center(
                  child: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

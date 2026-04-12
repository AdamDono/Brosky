import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
  XFile? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _joinHuddle();
  }

  Future<void> _joinHuddle() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final memberCheck = await Supabase.instance.client.from('huddle_members').select().eq('huddle_id', widget.huddleId).eq('user_id', userId).maybeSingle();
    if (memberCheck == null) {
      await Supabase.instance.client.from('huddle_members').insert({'huddle_id': widget.huddleId, 'user_id': userId});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined the Huddle! 🏟️')));
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _imageFile = image);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _imageFile == null) return;

    setState(() => _isSending = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      String? imageUrl;

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final fileExt = kIsWeb ? 'jpg' : _imageFile!.path.split('.').last;
        final fileName = 'huddle_${widget.huddleId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await Supabase.instance.client.storage.from('post_images').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: _imageFile!.mimeType, upsert: true),
        );

        imageUrl = Supabase.instance.client.storage.from('post_images').getPublicUrl(fileName);
      }

      await Supabase.instance.client.from('huddle_messages').insert({
        'huddle_id': widget.huddleId,
        'user_id': userId,
        'content': text.isEmpty ? "" : text, // Send empty string instead of null to be safe
        'image_url': imageUrl,
      });
      
      _messageController.clear();
      setState(() => _imageFile = null);
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

  Future<void> _showHuddleInfoModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: Future.wait([
            Supabase.instance.client.from('huddles').select().eq('id', widget.huddleId).maybeSingle(),
            Supabase.instance.client.from('huddle_members').select('id').eq('huddle_id', widget.huddleId)
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Container(
                height: 300,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
              );
            }

            final huddleData = snapshot.data![0];
            final membersList = snapshot.data![1] as List;
            final memberCount = membersList.length;

            final description = huddleData != null ? huddleData['description'] as String? : null;
            final manifesto = huddleData != null ? huddleData['manifesto'] as String? : null;
            final vibe = huddleData != null ? huddleData['vibe'] as String? : null;

            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.huddleName.toUpperCase(),
                        style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.people_alt, size: 16, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Text('$memberCount Bros Enlisted', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          if (vibe != null) ...[
                            const SizedBox(width: 12),
                            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle)),
                            const SizedBox(width: 12),
                            Text(vibe.toUpperCase(), style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 12, color: const Color(0xFF14B8A6), fontWeight: FontWeight.w700)),
                          ]
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      if (description != null && description.isNotEmpty) ...[
                        Text('MISSION', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 15, color: const Color(0xFF334155), height: 1.5),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (manifesto != null && manifesto.isNotEmpty) ...[
                        Text('MANIFESTO / RULES', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            manifesto,
                            style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, color: const Color(0xFF1E293B), height: 1.6, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    const _primaryColor = Color(0xFF14B8A6);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.huddleName.toUpperCase(), 
          style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), fontSize: 16, letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF94A3B8)),
            onPressed: _showHuddleInfoModal,
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
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _primaryColor));
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
          if (_imageFile != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Stack(
                    children: [
                       ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_imageFile!.path),
                          height: 80,
                          width: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _imageFile = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF94A3B8), size: 28),
                    onPressed: _pickImage,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF1E293B), fontSize: 15),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Say something...',
                        hintStyle: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF94A3B8), fontSize: 15),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
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
    const _primaryColor = Color(0xFF14B8A6);
    
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
          margin: const EdgeInsets.only(bottom: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: userId))),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                    image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                  ),
                  child: avatarUrl == null ? const Icon(Icons.person, size: 18, color: Colors.black26) : null,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            username,
                            style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 13, color: const Color(0xFF1E293B), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(DateTime.parse(message['created_at'])),
                            style: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // X-style soft grey
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message['image_url'] != null)
                             Padding(
                               padding: const EdgeInsets.all(2),
                               child: ClipRRect(
                                 borderRadius: const BorderRadius.only(
                                   topLeft: Radius.circular(2),
                                   topRight: Radius.circular(16),
                                   bottomLeft: Radius.circular(16),
                                   bottomRight: Radius.circular(16),
                                 ),
                                 child: Image.network(
                                   message['image_url'],
                                   fit: BoxFit.cover,
                                   loadingBuilder: (context, child, loadingProgress) {
                                     if (loadingProgress == null) return child;
                                     return Container(
                                       width: 200, height: 200,
                                       color: const Color(0xFFE2E8F0),
                                       child: const Center(child: CircularProgressIndicator(color: _primaryColor)),
                                     );
                                   },
                                 ),
                               ),
                             ),
                          if (message['content'] != null && message['content'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(
                                message['content'],
                                style: TextStyle(fontFamily: '.SF Pro Display', 
                                  color: const Color(0xFF1E293B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      ),
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

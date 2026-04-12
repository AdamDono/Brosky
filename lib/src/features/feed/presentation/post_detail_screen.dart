import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:hugeicons/hugeicons.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  final Color _teal = const Color(0xFF14B8A6);

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('post_comments').insert({
        'post_id': widget.post['id'],
        'user_id': user.id,
        'content': text,
      });
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      debugPrint('Comment failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.post['user_id'];
    final createdAt = DateTime.parse(widget.post['created_at']);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: Colors.black, size: 24),
            ),
            title: Text('CONVERSATION', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 13, color: Colors.black)),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- THE HERO POST SECTION ---
                  _buildHeroPost(userId, createdAt),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  ),

                  // --- COMMENTS SECTION ---
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('post_comments')
                        .stream(primaryKey: ['id'])
                        .eq('post_id', widget.post['id'])
                        .order('created_at', ascending: true),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                      final comments = snapshot.data!;
                      
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        separatorBuilder: (ctx, idx) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) => _buildCommentTile(comments[index]),
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // --- BOUTIQUE REPLY HUB ---
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06), width: 1)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, -10))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 15, color: const Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        hintText: 'Share your perspective...',
                        hintStyle: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSubmitting ? null : _submitComment,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: _teal,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: _teal.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Text(
                      'POST', 
                      style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPost(String userId, DateTime createdAt) {
    return FutureBuilder<Map<String, dynamic>>(
      future: Supabase.instance.client.from('profiles').select('username, avatar_url').eq('id', userId).single(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final username = profile?['username'] ?? 'Bro';
        final avatarUrl = profile?['avatar_url'];
        
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: const Color(0xFFF1F5F9),
                      image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                    ),
                    child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Color(0xFFCBD5E1), size: 28) : null,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF1E293B))),
                      Text(timeago.format(createdAt).toUpperCase(), style: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                widget.post['content'] ?? '', 
                style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 22, height: 1.4, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500, letterSpacing: -0.2)
              ),
              if (widget.post['image_url'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(widget.post['image_url'], width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final userId = comment['user_id'];
    final createdAt = DateTime.parse(comment['created_at']);
    return FutureBuilder<Map<String, dynamic>>(
      future: Supabase.instance.client.from('profiles').select('username, avatar_url').eq('id', userId).single(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final username = profile?['username'] ?? 'Bro';
        final avatarUrl = profile?['avatar_url'];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: const Color(0xFFF1F5F9),
                  image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                ),
                child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Color(0xFFCBD5E1), size: 20) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(username, style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF1E293B))),
                        const SizedBox(width: 8),
                        Text('· ${timeago.format(createdAt, locale: 'en_short')}', style: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(comment['content'] ?? '', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 16, height: 1.5, color: const Color(0xFF334155))),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

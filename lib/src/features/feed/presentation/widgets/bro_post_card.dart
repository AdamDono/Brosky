import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class BroPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  const BroPostCard({super.key, required this.post});

  @override
  State<BroPostCard> createState() => _BroPostCardState();
}

class _BroPostCardState extends State<BroPostCard> {
  int _likesCount = 0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _fetchLikes();
  }

  Future<void> _fetchLikes() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final likesResponse = await Supabase.instance.client
          .from('post_likes')
          .select('id')
          .eq('post_id', widget.post['id']);
      
      final userLikeResponse = await Supabase.instance.client
          .from('post_likes')
          .select()
          .eq('post_id', widget.post['id'])
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _likesCount = likesResponse.length;
          _isLiked = userLikeResponse != null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching likes: $e');
    }
  }

  Future<void> _toggleLike() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final originalIsLiked = _isLiked;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1;
    });

    try {
      if (originalIsLiked) {
        await Supabase.instance.client.from('post_likes').delete().eq('post_id', widget.post['id']).eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('post_likes').insert({'post_id': widget.post['id'], 'user_id': user.id});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = originalIsLiked;
          _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1; // Revert
        });
      }
    }
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Post?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      )
    );

    if (confirm == true) {
      await Supabase.instance.client.from('bro_posts').delete().eq('id', widget.post['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.post['user_id'];
    final createdAt = DateTime.parse(widget.post['created_at']);
    final isMyPost = userId == Supabase.instance.client.auth.currentUser?.id;

    return FutureBuilder<Map<String, dynamic>>(
      future: Supabase.instance.client.from('profiles').select().eq('id', userId).single(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final username = profile?['username'] ?? 'Bro';
        final avatarUrl = profile?['avatar_url'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: userId))),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF2DD4BF),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? const Icon(Icons.person, color: Colors.black) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: userId))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(username, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          Text('${timeago.format(createdAt)} • 1.2km away', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  if (widget.post['vibe'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF2DD4BF).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(widget.post['vibe'], style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  if (isMyPost)
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                      color: const Color(0xFF0F172A),
                      itemBuilder: (ctx) => [const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent)))],
                      onSelected: (val) { if (val == 'delete') _deletePost(); },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(widget.post['content'] ?? '', style: GoogleFonts.outfit(fontSize: 16, height: 1.4)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.white60),
                  const SizedBox(width: 8),
                  const Text('0', style: TextStyle(color: Colors.white60)),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        Icon(_isLiked ? Icons.favorite : Icons.favorite_border, size: 20, color: _isLiked ? const Color(0xFF2DD4BF) : Colors.white60),
                        const SizedBox(width: 8),
                        Text('$_likesCount', style: TextStyle(color: _isLiked ? const Color(0xFF2DD4BF) : Colors.white60)),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

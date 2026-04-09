import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:hugeicons/hugeicons.dart';

class BroPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onUpdate;
  const BroPostCard({super.key, required this.post, this.onUpdate});

  @override
  State<BroPostCard> createState() => _BroPostCardState();
}

class _BroPostCardState extends State<BroPostCard> {
  int _commentCount = 0;
  String? _myReaction;
  int _totalReactions = 0;
  final Color _primaryColor = const Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final postId = widget.post['id'];
    final user = Supabase.instance.client.auth.currentUser;

    final commentRes = await Supabase.instance.client.from('post_comments').select('id').eq('post_id', postId);
    final reactionsRes = await Supabase.instance.client.from('post_likes').select('reaction_type, user_id').eq('post_id', postId);
    
    final reactions = List<Map<String, dynamic>>.from(reactionsRes);
    String? myReact;
    for (var r in reactions) {
      if (r['user_id'] == user?.id) myReact = r['reaction_type'];
    }

    if (mounted) {
      setState(() {
        _commentCount = commentRes.length;
        _totalReactions = reactions.length;
        _myReaction = myReact;
      });
    }
  }

  Future<void> _handleReaction() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final isRemoving = _myReaction != null;

    try {
      if (isRemoving) {
        await Supabase.instance.client.from('post_likes').delete().eq('post_id', widget.post['id']).eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('post_likes').upsert({
          'post_id': widget.post['id'],
          'user_id': user.id,
          'reaction_type': '❤️'
        }, onConflict: 'post_id,user_id');
      }
      _fetchStats();
    } catch (e) { debugPrint('Error: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.post['user_id'];
    final createdAt = DateTime.parse(widget.post['created_at']);
    final isMyPost = userId == Supabase.instance.client.auth.currentUser?.id;

    return FutureBuilder<Map<String, dynamic>>(
      future: Supabase.instance.client.from('profiles').select('username, avatar_url').eq('id', userId).single(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final username = profile?['username'] ?? 'Bro';
        final avatarUrl = profile?['avatar_url'];

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF2F4F7), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- TOP BAR ---
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: userId))),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFF2F4F7),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Colors.black26, size: 20) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1A1D21))),
                        Text(timeago.format(createdAt), style: GoogleFonts.inter(color: const Color(0xFF9BA3AF), fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreHorizontal, color: Color(0xFF9BA3AF), size: 20),
                    onSelected: (value) async {
                      if (value == 'delete' && isMyPost) {
                         await Supabase.instance.client.from('bro_posts').delete().eq('id', widget.post['id']);
                         if (widget.onUpdate != null) widget.onUpdate!();
                      }
                    },
                    itemBuilder: (context) => [
                      if (isMyPost) const PopupMenuItem(value: 'delete', child: Text('Delete Post', style: TextStyle(color: Colors.redAccent))),
                      const PopupMenuItem(value: 'report', child: Text('Report Post')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // --- CONTENT ---
              Text(
                widget.post['content'] ?? '', 
                style: GoogleFonts.inter(fontSize: 15, height: 1.5, color: const Color(0xFF374151), fontWeight: FontWeight.w400)
              ),
              const SizedBox(height: 16),

              // --- IMAGE ---
              if (widget.post['image_url'] != null)
                Container(
                  height: 240,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), 
                    image: DecorationImage(image: NetworkImage(widget.post['image_url']), fit: BoxFit.cover),
                  ),
                ),

              const Divider(height: 32, thickness: 1, color: Color(0xFFF2F4F7)),

              // --- ACTION BAR ---
              Row(
                children: [
                  // Like
                  GestureDetector(
                    onTap: _handleReaction,
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedFavourite, 
                          color: _myReaction != null ? Colors.redAccent : const Color(0xFF9BA3AF), 
                          size: 20
                        ),
                        const SizedBox(width: 6),
                        Text('$_totalReactions', style: GoogleFonts.inter(color: const Color(0xFF9BA3AF), fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Comment
                  Row(
                    children: [
                      const HugeIcon(icon: HugeIcons.strokeRoundedChat01, color: Color(0xFF9BA3AF), size: 20),
                      const SizedBox(width: 6),
                      Text('$_commentCount', style: GoogleFonts.inter(color: const Color(0xFF9BA3AF), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Spacer(),
                  // Share (Reference style)
                  const HugeIcon(icon: HugeIcons.strokeRoundedShare01, color: Color(0xFF9BA3AF), size: 20),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}

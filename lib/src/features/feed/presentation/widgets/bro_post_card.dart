import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

// Note: This is the Unified BroPostCard used across the app (Feed and Details)
class BroPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onUpdate; // Optional: Force parent to refresh if needed

  const BroPostCard({super.key, required this.post, this.onUpdate});

  @override
  State<BroPostCard> createState() => _BroPostCardState();
}

class _BroPostCardState extends State<BroPostCard> {
  Map<String, int> _reactionCounts = {'👊': 0, '👍': 0, '🔥': 0, '💯': 0, '❤️': 0};
  String? _myReaction;
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchReactions();
    _fetchCommentCount();
  }

  @override
  void didUpdateWidget(BroPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post['id'] != widget.post['id'] || 
        oldWidget.post['content'] != widget.post['content'] ||
        oldWidget.post['image_url'] != widget.post['image_url']) {
      _fetchReactions();
      _fetchCommentCount();
    }
  }

  Future<void> _fetchCommentCount() async {
    try {
      final response = await Supabase.instance.client.from('post_comments').select('id').eq('post_id', widget.post['id']);
      if (mounted) setState(() => _commentCount = (response as List).length);
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _fetchReactions() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final response = await Supabase.instance.client.from('post_likes').select('reaction_type, user_id').eq('post_id', widget.post['id']);
      final reactions = List<Map<String, dynamic>>.from(response);
      Map<String, int> counts = {'👊': 0, '👍': 0, '🔥': 0, '💯': 0, '❤️': 0};
      String? myReact;
      for (var r in reactions) {
        final type = r['reaction_type'] ?? '👍';
        if (counts.containsKey(type)) counts[type] = counts[type]! + 1;
        if (r['user_id'] == user.id) myReact = type;
      }
      if (mounted) setState(() { _reactionCounts = counts; _myReaction = myReact; });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _handleReaction(String emoji) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final previousReaction = _myReaction;
    setState(() {
      if (previousReaction != null) _reactionCounts[previousReaction] = (_reactionCounts[previousReaction] ?? 1) - 1;
      if (previousReaction == emoji) { _myReaction = null; } 
      else { _myReaction = emoji; _reactionCounts[emoji] = (_reactionCounts[emoji] ?? 0) + 1; }
    });
    try {
      if (previousReaction == emoji) {
        await Supabase.instance.client.from('post_likes').delete().eq('post_id', widget.post['id']).eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('post_likes').upsert({'post_id': widget.post['id'], 'user_id': user.id, 'reaction_type': emoji}, onConflict: 'post_id,user_id');
      }
    } catch (e) { _fetchReactions(); }
  }

  Color _getReactionColor(String emoji) {
    switch (emoji) {
      case '👊': return const Color(0xFFD2B48C);
      case '👍': return Colors.blueAccent;
      case '🔥': return Colors.redAccent;
      case '💯': return Colors.white;
      case '❤️': return Colors.red;
      default: return Colors.white60;
    }
  }

  void _showReactionPicker(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(button.localToGlobal(Offset.zero, ancestor: overlay), button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay)),
      Offset.zero & overlay.size,
    );
    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: ['👊', '👍', '🔥', '💯', '❤️'].map((e) => PopupMenuItem(value: e, child: Center(child: Text(e, style: const TextStyle(fontSize: 24))))).toList(),
    ).then((value) { if (value != null) _handleReaction(value); });
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.post['user_id'];
    final createdAt = DateTime.parse(widget.post['created_at']);
    final isMyPost = userId == Supabase.instance.client.auth.currentUser?.id;

    int totalReactions = 0;
    String topEmoji = '👍';
    int maxCount = -1;
    _reactionCounts.forEach((emoji, count) {
      totalReactions += count;
      if (count > maxCount) { maxCount = count; topEmoji = emoji; }
    });
    if (totalReactions == 0) topEmoji = '👍';

    return FutureBuilder<Map<String, dynamic>>(
      future: Supabase.instance.client.from('profiles').select('username, avatar_url').eq('id', userId).single(),
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
                      radius: 18,
                      backgroundColor: const Color(0xFF2DD4BF),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? const Icon(Icons.person, color: Colors.black, size: 20) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(username, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('${timeago.format(createdAt)} • Local', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (isMyPost) 
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white24, size: 20),
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            title: const Text('Delete Post?', style: TextStyle(color: Colors.white)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
                            ],
                          ));
                          if (confirm == true) {
                            await Supabase.instance.client.from('bro_posts').delete().eq('id', widget.post['id']);
                            if (widget.onUpdate != null) widget.onUpdate!();
                          }
                        } else if (value == 'edit') {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => CreatePostModal(initialPost: widget.post),
                          ).then((_) { if (widget.onUpdate != null) widget.onUpdate!(); });
                        }
                      },
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [const Icon(Icons.edit_outlined, size: 18), const SizedBox(width: 12), const Text('Edit Post')]),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), const SizedBox(width: 12), const Text('Delete Post', style: TextStyle(color: Colors.redAccent))]),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.post['image_url'] != null)
                Container(
                  height: 250,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), image: DecorationImage(image: NetworkImage(widget.post['image_url']), fit: BoxFit.cover)),
                ),
              Text(widget.post['content'] ?? '', style: GoogleFonts.outfit(fontSize: 15, height: 1.5, color: Colors.white.withOpacity(0.9))),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white38),
                  const SizedBox(width: 8),
                  Text('$_commentCount', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () { if (_myReaction != null) _handleReaction(_myReaction!); else _showReactionPicker(context); },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(topEmoji, style: TextStyle(fontSize: 18, color: _myReaction != null ? _getReactionColor(topEmoji) : Colors.white24)),
                        const SizedBox(width: 6),
                        Text('$totalReactions', style: TextStyle(color: _myReaction != null ? _getReactionColor(topEmoji) : Colors.white24, fontSize: 13, fontWeight: _myReaction != null ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_myReaction == null) GestureDetector(onTap: () => _showReactionPicker(context), child: const Icon(Icons.add_reaction_outlined, size: 18, color: Colors.white24)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

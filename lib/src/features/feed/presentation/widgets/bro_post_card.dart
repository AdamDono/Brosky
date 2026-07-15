import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:bro_app/src/features/feed/presentation/post_detail_screen.dart';
import 'package:bro_app/src/features/notifications/application/notifications_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:hugeicons/hugeicons.dart';
import 'package:bro_app/src/core/theme/app_theme.dart';

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
  Map<String, dynamic>? _profileData;
  final Color _teal = const Color(0xFF14B8A6);

  // Animation states
  bool _showHeartOverlay = false;
  double _heartScale = 0.0;
  double _heartOpacity = 0.0;
  double _likeIconScale = 1.0;
  IconData _heartOverlayIcon = Icons.favorite_rounded;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final userId = widget.post['user_id'];
    try {
      final profile = await Supabase.instance.client.from('profiles').select('username, avatar_url').eq('id', userId).single();
      if (mounted) setState(() => _profileData = profile);
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    final postId = widget.post['id'];
    final user = Supabase.instance.client.auth.currentUser;

    try {
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
    } catch (e) { debugPrint('Error fetching stats: $e'); }
  }

  Future<void> _handleReaction() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final isRemoving = _myReaction != null;

    setState(() {
      _likeIconScale = 1.4;
      if (isRemoving) {
        _totalReactions--;
        _myReaction = null;
      } else {
        _totalReactions++;
        _myReaction = '❤️';
      }
    });

    // Reset button scale micro-animation
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _likeIconScale = 1.0;
        });
      }
    });

    try {
      if (isRemoving) {
        await Supabase.instance.client.from('post_likes').delete().eq('post_id', widget.post['id']).eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('post_likes').upsert({
          'post_id': widget.post['id'],
          'user_id': user.id,
          'reaction_type': '❤️'
        }, onConflict: 'post_id,user_id');

        NotificationsService.triggerNotification(
          recipientId: widget.post['user_id'],
          type: 'post_reaction',
          referenceId: widget.post['id'],
        );
      }
    } catch (e) { 
      debugPrint('Error reacting: $e');
      _fetchStats();
    }
  }

  void _triggerDoubleTapLike() {
    final wasLiked = _myReaction != null;

    // Show overlay scale-up
    setState(() {
      _showHeartOverlay = true;
      _heartScale = 1.0;
      _heartOpacity = 1.0;
      _heartOverlayIcon = wasLiked ? Icons.favorite_border_rounded : Icons.favorite_rounded;
    });

    // Always toggle
    _handleReaction();

    // Fade out and scale up slightly (pop effect)
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _heartScale = 1.4;
          _heartOpacity = 0.0;
        });
      }
    });

    // Reset state completely
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showHeartOverlay = false;
          _heartScale = 0.0;
        });
      }
    });
  }

  void _navigateToDetail() {
     Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostDetailScreen(post: widget.post)));
  }

  void _handleEdit() {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (ctx) => CreatePostModal(existingPost: widget.post)
    ).then((_) => widget.onUpdate?.call());
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('DELETE POST?', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, fontSize: 16)),
        content: const Text('This action is permanent. Ready to drop it?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('KEEP IT', style: TextStyle(color: Colors.black26))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('bro_posts').delete().eq('id', widget.post['id']);
        if (widget.onUpdate != null) widget.onUpdate!();
      } catch (e) { debugPrint('Error deleting: $e'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.post['user_id'];
    final createdAt = DateTime.parse(widget.post['created_at']);
    final isMyPost = userId == Supabase.instance.client.auth.currentUser?.id;

    final profile = _profileData;
    final username = profile?['username'] ?? 'Bro';
    final avatarUrl = profile?['avatar_url'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- LATERAL LEFT: PROFILE IMAGE ---
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: userId))),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.broColors.border,
                    image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                  ),
                  child: avatarUrl == null ? HugeIcon(icon: HugeIcons.strokeRoundedUser, color: context.broColors.subtext, size: 24) : null,
                ),
              ),
              const SizedBox(width: 12),
              
              // --- LATERAL RIGHT: CONTENT COLUMN ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Name + Handle/Time + More
                    Row(
                      children: [
                        GestureDetector(
                           onTap: _navigateToDetail,
                            child: Text(username, style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w800, fontSize: 15, color: context.broColors.text))
                        ),
                        const SizedBox(width: 6),
                        Text('· ${timeago.format(createdAt, locale: 'en_short')}', style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.subtext, fontSize: 14, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => Container(
                                decoration: BoxDecoration(color: context.broColors.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isMyPost) ...[
                                      ListTile(
                                        leading: HugeIcon(icon: HugeIcons.strokeRoundedEdit01, color: context.broColors.text),
                                        title: Text('Edit Post', style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.text, fontWeight: FontWeight.w600)),
                                        onTap: () { Navigator.pop(ctx); _handleEdit(); },
                                      ),
                                      ListTile(
                                        leading: const HugeIcon(icon: HugeIcons.strokeRoundedDelete01, color: Colors.redAccent),
                                        title: const Text('Delete Post', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.redAccent, fontWeight: FontWeight.w600)),
                                        onTap: () { Navigator.pop(ctx); _handleDelete(); },
                                      ),
                                    ],
                                    ListTile(
                                      leading: HugeIcon(icon: HugeIcons.strokeRoundedAlertCircle, color: context.broColors.text),
                                      title: Text('Report Post', style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.text, fontWeight: FontWeight.w600)),
                                      onTap: () => Navigator.pop(ctx),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreHorizontal, color: Color(0xFF94A3B8), size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Content Text + Image (Wrapped in Nav Bridge + Double-tap support)
                    GestureDetector(
                      onTap: _navigateToDetail,
                      onDoubleTap: _triggerDoubleTapLike,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.post['content'] ?? '', 
                                style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 15, height: 1.5, color: context.broColors.text, fontWeight: FontWeight.w400)
                              ),
                              if (widget.post['location_label'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, size: 13, color: Color(0xFF14B8A6)),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.post['location_label'],
                                      style: TextStyle(
                                        fontFamily: '.SF Pro Display',
                                        fontSize: 12,
                                        color: context.broColors.subtext,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (widget.post['image_url'] != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 400),
                                  width: double.infinity,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9, 
                                      child: Image.network(
                                        widget.post['image_url'],
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            color: context.broColors.border,
                                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_showHeartOverlay)
                            IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: _heartOpacity,
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 250),
                                  scale: _heartScale,
                                  curve: Curves.elasticOut,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.redAccent.withOpacity(0.4),
                                          blurRadius: 30,
                                          spreadRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _heartOverlayIcon,
                                      color: Colors.redAccent,
                                      size: 80,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Comment (Wired to Nav)
                        GestureDetector(
                          onTap: _navigateToDetail,
                          child: Row(
                            children: [
                              const HugeIcon(icon: HugeIcons.strokeRoundedBubbleChat, color: Color(0xFF64748B), size: 18),
                              const SizedBox(width: 8),
                              Text('$_commentCount', style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.subtext, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Like
                        GestureDetector(
                          onTap: _handleReaction,
                          child: Row(
                            children: [
                              AnimatedScale(
                                duration: const Duration(milliseconds: 150),
                                scale: _likeIconScale,
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedFavourite, 
                                  color: _myReaction != null ? Colors.redAccent : const Color(0xFF64748B), 
                                  size: 18
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$_totalReactions', style: TextStyle(fontFamily: '.SF Pro Display', color: _myReaction != null ? Colors.redAccent : context.broColors.subtext, fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: context.broColors.border), 
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:hugeicons/hugeicons.dart';
import 'package:bro_app/src/features/notifications/application/notifications_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmitting = false;
  final Color _teal = const Color(0xFF14B8A6);

  // Stats / Action states
  int _commentCount = 0;
  int _totalReactions = 0;
  String? _myReaction;
  double _likeIconScale = 1.0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
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
    } catch (_) {}
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

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _likeIconScale = 1.0);
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

      NotificationsService.triggerNotification(
        recipientId: widget.post['user_id'],
        type: 'post_comment',
        referenceId: widget.post['id'],
      );

      _commentController.clear();
      FocusScope.of(context).unfocus();
      _fetchStats();
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
                  
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1.5, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

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
                        separatorBuilder: (ctx, idx) => const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                        itemBuilder: (context, index) => _CommentTile(comment: comments[index]),
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
                      focusNode: _commentFocusNode,
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

  String _formatActualTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final timeStr = '$displayHour:$minute $period';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(localTime.year, localTime.month, localTime.day);
    
    if (messageDate == today) {
      return timeStr;
    } else if (today.difference(messageDate).inDays == 1) {
      return 'Yesterday, $timeStr';
    } else {
      return '${localTime.day}/${localTime.month}/${localTime.year}, $timeStr';
    }
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
                      Text(username, style: const TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E293B))),
                      Text(_formatActualTime(createdAt).toUpperCase(), style: const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                widget.post['content'] ?? '', 
                style: const TextStyle(fontFamily: '.SF Pro Display', fontSize: 22, height: 1.4, color: Color(0xFF0F172A), fontWeight: FontWeight.w500, letterSpacing: -0.2)
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
              const Divider(color: Color(0xFFF1F5F9), thickness: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Comment Button
                  GestureDetector(
                    onTap: () => _commentFocusNode.requestFocus(),
                    child: Row(
                      children: [
                        const HugeIcon(icon: HugeIcons.strokeRoundedBubbleChat, color: Color(0xFF64748B), size: 20),
                        const SizedBox(width: 8),
                        Text('$_commentCount', style: const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  // Like Button
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
                            size: 20
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$_totalReactions', style: TextStyle(fontFamily: '.SF Pro Display', color: _myReaction != null ? Colors.redAccent : const Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  const SizedBox(width: 20),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}

// --- STATEFUL MODULAR COMMENT TILE WITH COMMENT LIKES ---
class _CommentTile extends StatefulWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({super.key, required this.comment});

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  int _likesCount = 0;
  bool _isLiked = false;
  double _iconScale = 1.0;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchLikes();
  }

  Future<void> _fetchProfile() async {
    final userId = widget.comment['user_id'];
    try {
      final profile = await Supabase.instance.client.from('profiles').select('username, avatar_url').eq('id', userId).single();
      if (mounted) setState(() => _profileData = profile);
    } catch (_) {}
  }

  Future<void> _fetchLikes() async {
    final commentId = widget.comment['id'];
    final user = Supabase.instance.client.auth.currentUser;
    try {
      final likesRes = await Supabase.instance.client.from('comment_likes').select('user_id').eq('comment_id', commentId);
      final likesList = List<Map<String, dynamic>>.from(likesRes);
      bool liked = false;
      if (user != null) {
        liked = likesList.any((l) => l['user_id'] == user.id);
      }
      if (mounted) {
        setState(() {
          _likesCount = likesList.length;
          _isLiked = liked;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final commentId = widget.comment['id'];
    final wasLiked = _isLiked;

    setState(() {
      _iconScale = 1.4;
      if (wasLiked) {
        _likesCount--;
        _isLiked = false;
      } else {
        _likesCount++;
        _isLiked = true;
      }
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _iconScale = 1.0);
    });

    try {
      if (wasLiked) {
        await Supabase.instance.client.from('comment_likes').delete().eq('comment_id', commentId).eq('user_id', user.id);
      } else {
        await Supabase.instance.client.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': user.id,
        });
      }
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      _fetchLikes();
    }
  }

  String _formatActualTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final timeStr = '$displayHour:$minute $period';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(localTime.year, localTime.month, localTime.day);
    
    if (messageDate == today) {
      return timeStr;
    } else if (today.difference(messageDate).inDays == 1) {
      return 'Yesterday, $timeStr';
    } else {
      return '${localTime.day}/${localTime.month}/${localTime.year}, $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profileData;
    final username = profile?['username'] ?? 'Bro';
    final avatarUrl = profile?['avatar_url'];
    final createdAt = DateTime.parse(widget.comment['created_at']);

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
                    Text(username, style: const TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B))),
                    const SizedBox(width: 8),
                    Text('· ${_formatActualTime(createdAt)}', style: const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(widget.comment['content'] ?? '', style: const TextStyle(fontFamily: '.SF Pro Display', fontSize: 16, height: 1.5, color: Color(0xFF334155))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleLike,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 150),
                  scale: _iconScale,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedFavourite, 
                    color: _isLiked ? Colors.redAccent : const Color(0xFFCBD5E1),
                    size: 18,
                  ),
                ),
                if (_likesCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$_likesCount',
                    style: TextStyle(
                      fontFamily: '.SF Pro Display',
                      color: _isLiked ? Colors.redAccent : const Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

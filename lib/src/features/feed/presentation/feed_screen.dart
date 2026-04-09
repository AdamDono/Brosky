import 'package:bro_app/src/core/services/location_service.dart';
import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:bro_app/src/features/feed/presentation/widgets/bro_post_card.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:hugeicons/hugeicons.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late Stream<List<Map<String, dynamic>>> _postsStream;
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Color _tealColor = const Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initStream();
  }

  void _initStream() {
    _postsStream = Supabase.instance.client
        .from('bro_posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          var list = List<Map<String, dynamic>>.from(data);
          if (_searchQuery.isNotEmpty) {
            list = list.where((post) {
              final content = (post['content'] ?? '').toString().toLowerCase();
              return content.contains(_searchQuery.toLowerCase());
            }).toList();
          }
          return list;
        });
  }

  Future<void> _handleRefresh() async {
    _initStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- REFERENCE HEADER ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    'Community',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1D21),
                    ),
                  ),
                  IconButton(
                    onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const CreatePostModal()),
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: Color(0xFF1A1D21), size: 28),
                  ),
                ],
              ),
            ),

            // --- REFERENCE SEARCH BAR ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: TextField(
                controller: _searchController,
                onChanged: (val) { setState(() { _searchQuery = val; _initStream(); }); },
                style: GoogleFonts.inter(color: Colors.black, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search for vibes, or tags',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF9BA3AF), fontSize: 14),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, color: Color(0xFF1A1D21), size: 20),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

            // --- REFERENCE TABS ---
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.03), width: 1)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF1A1D21),
                indicatorWeight: 2,
                labelColor: const Color(0xFF1A1D21),
                unselectedLabelColor: const Color(0xFF9BA3AF),
                labelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Feed'),
                  Tab(text: 'Group'),
                  Tab(text: 'Friends'),
                ],
              ),
            ),

            // --- THE FEED ---
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFeedList(),
                  const Center(child: Text('Coming Soon, Bro.')),
                  const Center(child: Text('Coming Soon, Bro.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedList() {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _tealColor,
      backgroundColor: Colors.white,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _tealColor));
          final posts = snapshot.data!;
          if (posts.isEmpty) return const Center(child: Text('Feed is quiet, Bro.'));
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final userId = post['user_id'];
              return GestureDetector(
                onTap: () async {
                  final profile = await Supabase.instance.client.from('profiles').select('username, avatar_url').eq('id', userId).single();
                  if (mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => PostDetailScreen(
                      post: post,
                      username: profile['username'] ?? 'Bro',
                      avatarUrl: profile['avatar_url'],
                      onUpdate: () => _handleRefresh(),
                    )));
                  }
                },
                child: BroPostCard(
                  key: ValueKey(post['id']),
                  post: post,
                  onUpdate: () => _handleRefresh(),
                ),
              );
            }
          );
        },
      ),
    );
  }
}

// Reuse the PostDetailScreen logic but update imports to use HugeIcons...
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String username;
  final String? avatarUrl;
  final VoidCallback onUpdate;
  const PostDetailScreen({super.key, required this.post, required this.username, this.avatarUrl, required this.onUpdate});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;
  Map<String, int> _counts = {'👊': 0, '👍': 0, '🔥': 0, '💯': 0, '❤️': 0};
  String? _myReaction;
  final Color _tealColor = const Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _fetchReactions();
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
      if (mounted) setState(() { _counts = counts; _myReaction = myReact; });
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _handleReaction(String emoji) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final isRemoving = _myReaction == emoji;
    setState(() {
      if (isRemoving) { _counts[emoji] = (_counts[emoji] ?? 1) - 1; _myReaction = null; } 
      else { if (_myReaction != null) _counts[_myReaction!] = (_counts[_myReaction!] ?? 1) - 1; _counts[emoji] = (_counts[emoji] ?? 0) + 1; _myReaction = emoji; }
    });
    try {
      if (isRemoving) await Supabase.instance.client.from('post_likes').delete().eq('post_id', widget.post['id']).eq('user_id', user.id);
      else await Supabase.instance.client.from('post_likes').upsert({'post_id': widget.post['id'], 'user_id': user.id, 'reaction_type': emoji}, onConflict: 'post_id,user_id');
      widget.onUpdate();
    } catch (e) { debugPrint('Error: $e'); }
  }

  void _showReactionPicker(BuildContext context) {
    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 400, 100, 400),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.black12)),
      items: ['👊', '👍', '🔥', '💯', '❤️'].map((e) => PopupMenuItem(value: e, child: Center(child: Text(e, style: const TextStyle(fontSize: 24))))).toList(),
    ).then((value) { if (value != null) _handleReaction(value); });
  }

  Widget _buildDetailReactionBadge(String emoji, int count) {
    final isMine = _myReaction == emoji;
    return GestureDetector(onTap: () => _handleReaction(emoji), child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMine ? _tealColor.withOpacity(0.1) : Colors.black.withOpacity(0.03), 
          borderRadius: BorderRadius.circular(12),
          border: isMine ? Border.all(color: _tealColor.withOpacity(0.3), width: 1) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)), 
          const SizedBox(width: 8), 
          Text('$count', style: GoogleFonts.inter(color: isMine ? _tealColor : Colors.black26, fontSize: 13, fontWeight: FontWeight.w900))
        ]),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(widget.post['created_at']);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0, 
        centerTitle: true,
        title: Text('POST INFO', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14, color: Colors.black)), 
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.all(24), children: [
                Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: Colors.black.withOpacity(0.04), backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null, child: widget.avatarUrl == null ? const Icon(Icons.person, color: Colors.black26) : null),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.username, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black)), 
                      Text(timeago.format(createdAt).toUpperCase(), style: GoogleFonts.inter(color: Colors.black12, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5))
                    ]),
                  ]),
                const SizedBox(height: 24),
                if (widget.post['image_url'] != null)
                  Container(
                    height: 380, 
                    width: double.infinity, 
                    margin: const EdgeInsets.only(bottom: 24), 
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24), 
                      image: DecorationImage(image: NetworkImage(widget.post['image_url']), fit: BoxFit.cover),
                      border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                    )
                  ),
                Text(widget.post['content'] ?? '', style: GoogleFonts.inter(fontSize: 16, height: 1.6, color: Colors.black87, fontWeight: FontWeight.w500)),
                const SizedBox(height: 32),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                      ..._counts.entries.where((e) => e.value > 0).map((e) => _buildDetailReactionBadge(e.key, e.value)),
                      if (_myReaction == null) IconButton(icon: const Icon(Icons.add_reaction_outlined, size: 20, color: Colors.black12), onPressed: () => _showReactionPicker(context)),
                    ])),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 24),
                Text('COMMENTS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: _tealColor, letterSpacing: 1.5)),
                const SizedBox(height: 24),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Supabase.instance.client.from('post_comments').stream(primaryKey: ['id']).eq('post_id', widget.post['id']).order('created_at', ascending: true),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _tealColor));
                    final comments = snapshot.data!;
                    if (comments.isEmpty) return Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('Be the first to comment, Bro.', style: GoogleFonts.inter(color: Colors.black12, fontSize: 14, fontWeight: FontWeight.w600))));
                    return Column(children: comments.map((c) => _buildCommentItem(c)).toList());
                  },
                ),
              ])),
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24), 
            decoration: BoxDecoration(
              color: Colors.white, 
              border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05)))
            ), 
            child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _commentController, 
                    style: GoogleFonts.inter(color: Colors.black, fontSize: 14), 
                    decoration: InputDecoration(
                      hintText: 'Add a comment...', 
                      hintStyle: GoogleFonts.inter(color: Colors.black26, fontSize: 14), 
                      filled: true, 
                      fillColor: Colors.black.withOpacity(0.04), 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                    )
                  )
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _isPosting ? null : _submitComment, 
                  icon: Icon(Icons.send_rounded, color: _isPosting ? Colors.black26 : _tealColor)
                ),
              ])),
        ]),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final userId = comment['user_id'];
    final createdAt = DateTime.parse(comment['created_at']);
    return FutureBuilder<Map<String, dynamic>>(future: Supabase.instance.client.from('profiles').select('username, avatar_url').eq('id', userId).single(), builder: (context, snapshot) {
        final profile = snapshot.data;
        final username = profile?['username'] ?? 'Bro';
        final avatarUrl = profile?['avatar_url'];
        return Padding(padding: const EdgeInsets.only(bottom: 24), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 14, backgroundColor: Colors.black.withOpacity(0.04), backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, size: 14, color: Colors.black12) : null),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(username, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black)), 
                  const SizedBox(width: 8), 
                  Text(timeago.format(createdAt, locale: 'en_short').toUpperCase(), style: GoogleFonts.inter(color: Colors.black12, fontSize: 10, fontWeight: FontWeight.w900))
                ]), 
                const SizedBox(height: 6), 
                Text(comment['content'], style: GoogleFonts.inter(color: Colors.black54, fontSize: 14, height: 1.4))
              ])),
            ]));
      });
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isPosting = true);
    try {
      await Supabase.instance.client.from('post_comments').insert({'post_id': widget.post['id'], 'user_id': user.id, 'content': content});
      _commentController.clear();
      widget.onUpdate();
    } catch (e) { debugPrint('Error: $e'); } finally { if (mounted) setState(() => _isPosting = false); }
  }
}

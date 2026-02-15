import 'package:bro_app/src/core/services/location_service.dart';
import 'package:bro_app/src/features/chat/presentation/requests_screen.dart';
import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:bro_app/src/features/feed/presentation/widgets/bro_post_card.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Stream<List<Map<String, dynamic>>> _postsStream;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  Position? _currentPosition;
  double _selectedRadius = 50.0; 
  final List<double> _radii = [5.0, 10.0, 25.0, 50.0, 100.0, 500.0];

  final List<String> _filters = [
    'All',
    'General',
    'Sports & Fitness',
    'Gaming & Culture',
    'Life & Real Talk',
    'Business & Hustle',
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocationThenStream();
  }

  Future<void> _fetchLocationThenStream() async {
    final pos = await LocationService.updateLocation();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
        _initStream();
      });
    }
  }

  void _initStream() {
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    _postsStream = Supabase.instance.client
        .from('bro_posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          var list = List<Map<String, dynamic>>.from(data);
          list = list.where((post) {
            final createdAt = DateTime.parse(post['created_at']);
            return createdAt.isAfter(twentyFourHoursAgo);
          }).toList();

          if (_currentPosition != null) {
            list = list.where((post) {
              if (post['location_lat'] == null || post['location_lng'] == null) return true;
              final distance = LocationService.calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                post['location_lat'],
                post['location_lng'],
              );
              post['distance_val'] = distance;
              return distance <= _selectedRadius;
            }).toList();
          }

          if (_selectedFilter != 'All') {
            list = list.where((post) => post['vibe'] == _selectedFilter).toList();
          }

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
    await _fetchLocationThenStream();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _initStream();
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search keywords, vibes, bros...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF2DD4BF)),
              suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white38),
                    onPressed: () {
                      _searchController.clear();
                      setState(() { _searchQuery = ''; _initStream(); });
                    },
                  )
                : null,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        _buildRadiusSelector(),
        _buildFilterBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: const Color(0xFF2DD4BF),
            backgroundColor: const Color(0xFF0F172A),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _postsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Stream Error: ${snapshot.error}', style: const TextStyle(color: Colors.white60)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));
                final posts = snapshot.data!;
                if (posts.isEmpty) {
                  return ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                      const Icon(Icons.search_off, size: 64, color: Colors.white10),
                      const SizedBox(height: 16),
                      Text(_searchQuery.isNotEmpty ? 'No posts matching \"$_searchQuery\"' : 'The feed is quiet, Bro.', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16)),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
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
          ),
        ),
      ],
    );
  }

  Widget _buildRadiusSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SEARCH RADIUS',
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.5),
              ),
              Text(
                '${_selectedRadius.round()} km',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2DD4BF)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF2DD4BF),
              inactiveTrackColor: Colors.white10,
              thumbColor: const Color(0xFF2DD4BF),
              trackHeight: 2,
            ),
            child: Slider(
              value: _selectedRadius,
              min: 5,
              max: 500,
              onChanged: (val) {
                setState(() {
                  _selectedRadius = val;
                  _initStream();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(filter, style: GoogleFonts.outfit(color: isSelected ? Colors.black : Colors.white60, fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              backgroundColor: const Color(0xFF1E293B),
              selectedColor: const Color(0xFF2DD4BF),
              checkmarkColor: Colors.black,
              onSelected: (selected) { setState(() { _selectedFilter = filter; _initStream(); }); },
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }
}

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
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: ['👊', '👍', '🔥', '💯', '❤️'].map((e) => PopupMenuItem(value: e, child: Center(child: Text(e, style: const TextStyle(fontSize: 24))))).toList(),
    ).then((value) { if (value != null) _handleReaction(value); });
  }

  Widget _buildDetailReactionBadge(String emoji, int count) {
    final isMine = _myReaction == emoji;
    Color color = Colors.white60;
    if (isMine) {
      switch (emoji) {
        case '👊': color = const Color(0xFFD2B48C); break;
        case '👍': color = Colors.blueAccent; break;
        case '🔥': color = Colors.redAccent; break;
        case '💯': color = Colors.white; break;
        case '❤️': color = Colors.red; break;
      }
    }
    return GestureDetector(onTap: () => _handleReaction(emoji), child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: isMine ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text(emoji, style: const TextStyle(fontSize: 16)), const SizedBox(width: 6), Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: isMine ? FontWeight.bold : FontWeight.normal))]),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(widget.post['created_at']);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        title: Text('Post Info', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), 
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [
          if (widget.post['user_id'] == Supabase.instance.client.auth.currentUser?.id)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white60, size: 22),
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
                    widget.onUpdate();
                    if (mounted) Navigator.pop(context);
                  }
                } else if (value == 'edit') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => CreatePostModal(initialPost: widget.post),
                  ).then((_) { 
                    widget.onUpdate();
                    _fetchReactions();
                  });
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
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.all(20), children: [
                Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: const Color(0xFF2DD4BF), backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null, child: widget.avatarUrl == null ? const Icon(Icons.person, color: Colors.black) : null),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(timeago.format(createdAt), style: const TextStyle(color: Colors.white38, fontSize: 12))]),
                  ]),
                const SizedBox(height: 16),
                if (widget.post['image_url'] != null)
                  Container(height: 300, width: double.infinity, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), image: DecorationImage(image: NetworkImage(widget.post['image_url']), fit: BoxFit.cover))),
                Text(widget.post['content'] ?? '', style: GoogleFonts.outfit(fontSize: 18, height: 1.4, color: Colors.white)),
                const SizedBox(height: 24),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                      ..._counts.entries.where((e) => e.value > 0).map((e) => _buildDetailReactionBadge(e.key, e.value)),
                      if (_myReaction == null) IconButton(icon: const Icon(Icons.add_reaction_outlined, size: 20, color: Colors.white24), onPressed: () => _showReactionPicker(context)),
                    ])),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Text('Comments', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2DD4BF))),
                const SizedBox(height: 16),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: Supabase.instance.client.from('post_comments').stream(primaryKey: ['id']).eq('post_id', widget.post['id']).order('created_at', ascending: true),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));
                    final comments = snapshot.data!;
                    if (comments.isEmpty) return Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text('No comments yet.', style: const TextStyle(color: Colors.white24))));
                    return Column(children: comments.map((c) => _buildCommentItem(c)).toList());
                  },
                ),
              ])),
          Container(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 12), decoration: const BoxDecoration(color: Color(0xFF1E293B), border: Border(top: BorderSide(color: Colors.white10))), child: Row(children: [
                Expanded(child: TextField(controller: _commentController, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: 'Add a comment...', hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: const Color(0xFF0F172A), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                IconButton(onPressed: _isPosting ? null : _submitComment, icon: Icon(Icons.send_rounded, color: _isPosting ? Colors.white24 : const Color(0xFF2DD4BF))),
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
        return Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 14, backgroundColor: const Color(0xFF2DD4BF), backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, size: 14, color: Colors.black) : null),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 8), Text(timeago.format(createdAt, locale: 'en_short'), style: const TextStyle(color: Colors.white38, fontSize: 10))]), const SizedBox(height: 4), Text(comment['content'], style: const TextStyle(color: Colors.white70, fontSize: 14))])),
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

import 'package:bro_app/src/features/chat/presentation/requests_screen.dart';
import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
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
    _initStream();
  }

  void _initStream() {
    _postsStream = Supabase.instance.client
        .from('bro_posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          var list = List<Map<String, dynamic>>.from(data);
          
          // 1. Filter by Vibe
          if (_selectedFilter != 'All') {
            list = list.where((post) => post['vibe'] == _selectedFilter).toList();
          }

          // 2. Filter by Keyword (Search)
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
    setState(() {
      _initStream();
    });
  }

  void _showCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreatePostModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Brotherhood Feed', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RequestsScreen())),
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh, color: Color(0xFF2DD4BF)),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Search Bar ---
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
                        setState(() {
                          _searchQuery = '';
                          _initStream();
                        });
                      },
                    )
                  : null,
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          _buildFilterBar(),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: const Color(0xFF2DD4BF),
              backgroundColor: const Color(0xFF0F172A),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _postsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text('Stream Error: ${snapshot.error}', 
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60)),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));
                  }

                  final posts = snapshot.data!;

                  if (posts.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        const Icon(Icons.search_off, size: 64, color: Colors.white10),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty 
                            ? 'No posts matching "$_searchQuery"'
                            : 'The feed is quiet, Bro.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      return BroPostCard(post: posts[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePost,
        backgroundColor: const Color(0xFF2DD4BF),
        child: const Icon(Icons.add, color: Colors.black, size: 30),
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
              label: Text(filter, style: GoogleFonts.outfit(
                color: isSelected ? Colors.black : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              )),
              backgroundColor: const Color(0xFF1E293B),
              selectedColor: const Color(0xFF2DD4BF),
              checkmarkColor: Colors.black,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                  _initStream();
                });
              },
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }
}

class BroPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  const BroPostCard({super.key, required this.post});

  @override
  State<BroPostCard> createState() => _BroPostCardState();
}

class _BroPostCardState extends State<BroPostCard> {
  int _likesCount = 0;
  bool _isLiked = false;
  bool _isLoadingLikes = true;

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
          _isLoadingLikes = false;
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
    final originalLikesCount = _likesCount;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1;
    });

    try {
      if (originalIsLiked) {
        await Supabase.instance.client
            .from('post_likes')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('user_id', user.id);
      } else {
        await Supabase.instance.client
            .from('post_likes')
            .insert({
          'post_id': widget.post['id'],
          'user_id': user.id,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = originalIsLiked;
          _likesCount = originalLikesCount;
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
        content: const Text('This will remove it from the Brotherhood feed.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      )
    );

    if (confirm == true) {
      await Supabase.instance.client.from('bro_posts').delete().eq('id', widget.post['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.post['user_id'];
    final createdAt = DateTime.parse(widget.post['created_at']);
    final isMyPost = userId == Supabase.instance.client.auth.currentUser?.id;

    return FutureBuilder<Map<String, dynamic>>(
      future: Supabase.instance.client
          .from('profiles')
          .select('username, avatar_url, bio, vibes')
          .eq('id', userId)
          .single(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final username = profile?['username'] ?? 'Bro';
        final avatarUrl = profile?['avatar_url'];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: userId))
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF2DD4BF),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? const Icon(Icons.person, color: Colors.black) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: userId))
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(username, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          Text(
                            '${timeago.format(createdAt)} • 1.2km away',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.post['vibe'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4BF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.post['vibe'],
                        style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (isMyPost)
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                      color: const Color(0xFF0F172A),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                      ],
                      onSelected: (val) {
                        if (val == 'delete') _deletePost();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.post['content'] ?? '',
                style: GoogleFonts.outfit(fontSize: 16, height: 1.4),
              ),
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
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: _isLiked ? const Color(0xFF2DD4BF) : Colors.white60,
                        ),
                        const SizedBox(width: 8),
                        Text('$_likesCount', style: TextStyle(color: _isLiked ? const Color(0xFF2DD4BF) : Colors.white60)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: userId))
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DD4BF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

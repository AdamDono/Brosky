import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
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
        .map((data) => List<Map<String, dynamic>>.from(data));
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
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh, color: Color(0xFF2DD4BF)),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune, color: Color(0xFF2DD4BF)),
          ),
        ],
      ),
      body: RefreshIndicator(
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
                  child: Text('Stream Error: ${snapshot.error}\n\nMake sure Realtime is enabled in Supabase!', 
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
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  const Icon(Icons.forum_outlined, size: 64, color: Colors.white10),
                  const SizedBox(height: 16),
                  Text(
                    'The feed is quiet, Bro.\nBe the first to say something.',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePost,
        backgroundColor: const Color(0xFF2DD4BF),
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
    );
  }
}

class BroPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const BroPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final userId = post['user_id'];
    final createdAt = DateTime.parse(post['created_at']);

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
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2DD4BF),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? const Icon(Icons.person, color: Colors.black) : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      Text(
                        '${timeago.format(createdAt)} • 1.2km away',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (post['vibe'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4BF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        post['vibe'],
                        style: const TextStyle(
                          color: Color(0xFF2DD4BF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                post['content'] ?? '',
                style: GoogleFonts.outfit(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.white60),
                  const SizedBox(width: 8),
                  const Text('0', style: TextStyle(color: Colors.white60)),
                  const SizedBox(width: 24),
                  const Icon(Icons.favorite_border, size: 20, color: Colors.white60),
                  const SizedBox(width: 8),
                  const Text('0', style: TextStyle(color: Colors.white60)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {},
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

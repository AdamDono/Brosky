import 'package:bro_app/src/features/feed/presentation/widgets/bro_post_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicProfileScreen extends StatelessWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isMe = userId == Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .single(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("Bro not found."));
          }

          final profile = snapshot.data!;
          final username = profile['username'] ?? 'Bro';
          final avatarUrl = profile['avatar_url'];
          final bio = profile['bio'] ?? 'This bro is a man of few words.';
          final vibes = List<String>.from(profile['vibes'] ?? []);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: const Color(0xFF2DD4BF),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? const Icon(Icons.person, size: 60, color: Colors.black) : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        username,
                        style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      // --- Dynamic Stats Row ---
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: Supabase.instance.client
                            .from('bro_posts')
                            .select('id')
                            .eq('user_id', userId),
                        builder: (ctx, postSnap) {
                          final postCount = postSnap.data?.length ?? 0;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatColumn('142', 'Bros'), // Mock for now
                              const SizedBox(width: 40),
                              _buildStatColumn('28', 'Huddles'), // Mock for now
                              const SizedBox(width: 40),
                              _buildStatColumn(postCount.toString(), 'Posts'),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // --- Connect Button Section ---
                      if (!isMe)
                        SizedBox(
                          width: 200,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Sending connection request... stay tuned! ⚡️")),
                              );
                            },
                            icon: const Icon(Icons.handshake_outlined, size: 18),
                            label: Text('CONNECT', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2DD4BF),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (vibes.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: vibes.map((vibe) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2DD4BF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.3), width: 1),
                            ),
                            child: Text(
                              vibe,
                              style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          )).toList(),
                        ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ABOUT BRO',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2DD4BF),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              bio,
                              style: GoogleFonts.outfit(fontSize: 15, color: Colors.white.withOpacity(0.85), height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          const Icon(Icons.history, color: Color(0xFF2DD4BF), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'RECENT POSTS',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // --- Real Stream of Posts ---
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: Supabase.instance.client
                            .from('bro_posts')
                            .stream(primaryKey: ['id'])
                            .eq('user_id', userId)
                            .order('created_at', ascending: false),
                        builder: (ctx, postSnap) {
                          if (!postSnap.hasData) return const SizedBox();
                          final posts = postSnap.data!;
                          if (posts.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text("No posts yet. Silent but steady.", style: TextStyle(color: Colors.white24)),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: posts.length,
                            itemBuilder: (c, idx) {
                              return BroPostCard(post: posts[idx]);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white38)),
      ],
    );
  }
}

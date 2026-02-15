import 'package:bro_app/src/features/chat/presentation/direct_chat_screen.dart';

import 'package:bro_app/src/features/feed/presentation/widgets/bro_post_card.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  // We can keep _handleConnection here or specific button logic. 
  // Let's copy _handleConnection inside.

  Future<void> _handleConnection(BuildContext context, Map<String, dynamic> userProfile) async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final otherId = userProfile['id'];

    if (myId == otherId) return;

    // Simply open the direct chat screen
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DirectChatScreen(
          partnerId: otherId,
          partnerUsername: userProfile['username'] ?? 'Bro',
          partnerAvatar: userProfile['avatar_url'],
        ),
      ),
    );
  }


  late Future<List<dynamic>> _profileFuture;
  Map<String, dynamic>? _optimisticConversation;
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileData();
    _subscribeToChanges();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    if (_subscription != null) Supabase.instance.client.removeChannel(_subscription!);
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) return;
      try {
        final newData = await _loadProfileData();
        if (mounted) {
          setState(() {
            _profileFuture = Future.value(newData);
            // If data shows accepted, clear optimistic state
            final conversation = newData[4] as Map<String, dynamic>?;
            if (conversation != null && conversation['status'] == 'accepted') {
              _optimisticConversation = null; 
            }
          });
        }
      } catch (e) {
        // silent
      }
    });
  }

  void _subscribeToChanges() {
    try {
      _subscription = Supabase.instance.client
          .channel('public:conversations:${widget.userId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            callback: (payload) {
              if (mounted) _refreshData();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("Realtime subscription error: $e");
    }
  }

  // ... (maintain _loadProfileData as is or if needed copy it, but since I'm only targeting the class start and build, I'll assume usage of existing method)
  Future<List<dynamic>> _loadProfileData() async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    return Future.wait([
      Supabase.instance.client.from('profiles').select().eq('id', widget.userId).single(),
      // Use count() which returns int
      Supabase.instance.client
          .from('conversations')
          .count(CountOption.exact)
          .or('user1_id.eq.${widget.userId},user2_id.eq.${widget.userId}')
          .eq('status', 'accepted'),
      Supabase.instance.client.from('huddle_members').select('id').eq('user_id', widget.userId),
      Supabase.instance.client.from('bro_posts').select('id').eq('user_id', widget.userId),
      if (myId != widget.userId)
        Supabase.instance.client.from('conversations').select().or('and(user1_id.eq.$myId,user2_id.eq.${widget.userId}),and(user1_id.eq.${widget.userId},user2_id.eq.$myId)').maybeSingle()
      else
        Future.value(null),
    ]);
  }

  void _refreshData() {
    setState(() {
      _profileFuture = _loadProfileData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == Supabase.instance.client.auth.currentUser?.id;

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
      body: FutureBuilder<List<dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _optimisticConversation == null) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));
          }

          if (snapshot.hasError || (!snapshot.hasData && _optimisticConversation == null)) {
            return const Center(child: Text("Bro not found."));
          }

          // Use snapshot data if available, else usage of optimistic conversation implies we might be waiting for refresh
          // But actually FutureBuilder keeps the last data if we don't return inside 'waiting'.
          // However, we want to show the new status EVEN IF the snapshot is old or waiting.
          
          final data = snapshot.hasData ? snapshot.data! : [];
          if (data.isEmpty && _optimisticConversation == null) return const SizedBox();

          final profile = data.isNotEmpty ? data[0] as Map<String, dynamic> : <String, dynamic>{};
          // If we are refreshing, we might want to increment the connection count optimistically too?
          // Let's rely on the server validation for the count, but immediate UI for buttons.
          // Connections count is now an int directly (from count())
          final connections = data.isNotEmpty ? (data[1] is int ? data[1] as int : (data[1] as List).length) : 0;
          final huddles = (data.isNotEmpty ? (data[2] as List?)?.length : 0) ?? 0;
          final posts = (data.isNotEmpty ? (data[3] as List?)?.length : 0) ?? 0;
          
          final fetchedConversation = data.isNotEmpty ? data[4] as Map<String, dynamic>? : null;
          final conversation = _optimisticConversation ?? fetchedConversation;

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
                      
                      // --- Dynamic Stats ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatColumn(connections.toString(), 'Bros'),
                          const SizedBox(width: 40),
                          _buildStatColumn(huddles.toString(), 'Huddles'),
                          const SizedBox(width: 40),
                          _buildStatColumn(posts.toString(), 'Posts'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // --- Smart Action Buttons ---
                      if (!isMe) ...[
                        if (conversation == null)
                          _buildActionButton(
                            context, 
                            'CONNECT', 
                            Icons.handshake_outlined, 
                            const Color(0xFF2DD4BF), 
                            Colors.black,
                            () => _handleConnection(context, profile)
                          )
                        else if (conversation['status'] == 'accepted')
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2DD4BF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF2DD4BF), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF2DD4BF), size: 14),
                                    const SizedBox(width: 6),
                                    Text('WE BROS', style: GoogleFonts.outfit(color: const Color(0xFF2DD4BF), fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildActionButton(
                                context, 
                                'MESSAGE', 
                                Icons.chat_bubble_outline, 
                                Colors.white, 
                                Colors.black,
                                () => _handleConnection(context, profile)
                              ),
                            ],
                          )
                        else if (conversation['status'] == 'pending')
                          if (conversation['initiator_id'] == Supabase.instance.client.auth.currentUser!.id)
                            _buildActionButton(
                              context, 
                              'REQUEST SENT', 
                              Icons.check, 
                              Colors.white10, 
                              Colors.white54,
                              null // Disabled
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                  context, 
                                  'DECLINE', 
                                  Icons.close, 
                                  Colors.redAccent.withOpacity(0.2), 
                                  Colors.redAccent,
                                  () async {
                                    await Supabase.instance.client.from('conversations').delete().eq('id', conversation['id']);
                                    setState(() {
                                       _optimisticConversation = null; // Removed
                                    });
                                    _refreshData();
                                  },
                                  width: 140
                                ),
                                const SizedBox(width: 16),
                                _buildActionButton(
                                  context, 
                                  'ACCEPT', 
                                  Icons.check, 
                                  const Color(0xFF2DD4BF), 
                                  Colors.black,
                                  () async {
                                    try {
                                      final currentConv = conversation;
                                      setState(() {
                                        _optimisticConversation = {
                                          ...currentConv,
                                          'status': 'accepted',
                                        };
                                      });
                                      
                                      final response = await Supabase.instance.client
                                          .from('conversations')
                                          .update({'status': 'accepted'})
                                          .eq('id', conversation['id'])
                                          .select();
                                      
                                      debugPrint('Accept response: $response');
                                      if (response.isEmpty) {
                                        throw 'Update failed. You might not have permission to update this conversation.';
                                      }
                                            
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are now Bros! 👊')));
                                        _refreshData();
                                      }
                                    } catch (e) {
                                       debugPrint("Accept connection error: $e");
                                       if (mounted) {
                                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                         setState(() => _optimisticConversation = null);
                                         _refreshData();
                                       }
                                    }
                                  },
                                  width: 140
                                ),
                              ],
                            ),
                      ],
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
                            .eq('user_id', widget.userId)
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

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color bgColor, Color fgColor, VoidCallback? onPressed, {double width = 200}) {
    return SizedBox(
      width: width,
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: Colors.white12,
          disabledForegroundColor: Colors.white38,
        ),
      ),
    );
  }
}

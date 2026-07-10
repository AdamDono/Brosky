import 'package:bro_app/src/features/chat/presentation/direct_chat_screen.dart';
import 'package:bro_app/src/features/chat/presentation/voice_call_screen.dart';

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
  Future<void> _handleConnection(BuildContext context, Map<String, dynamic> userProfile, Map<String, dynamic>? currentConversation) async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final otherId = userProfile['id'];

    if (myId == otherId) return;

    final status = currentConversation?['status'] ?? _optimisticConversation?['status'];
    if (status == 'accepted') {
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
      return;
    }

    try {
      final newConversation = {
        'user1_id': myId,
        'user2_id': otherId,
        'status': 'pending',
        'initiator_id': myId,
      };

      setState(() {
        _optimisticConversation = newConversation;
      });

      await Supabase.instance.client.from('conversations').insert(newConversation);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection request sent! 👊')));
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _optimisticConversation = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }


  late Future<List<dynamic>> _profileFuture;
  Map<String, dynamic>? _optimisticConversation;
  RealtimeChannel? _subscription;
  late Stream<List<Map<String, dynamic>>> _postStream; // Persistent post stream

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileData();
    _initPostStream();
    _subscribeToChanges();
  }

  void _initPostStream() {
    _postStream = Supabase.instance.client
        .from('bro_posts')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false);
  }

  @override
  void dispose() {
    if (_subscription != null) Supabase.instance.client.removeChannel(_subscription!);
    super.dispose();
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

  Future<List<dynamic>> _loadProfileData() async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    return Future.wait([
      Supabase.instance.client.from('profiles').select().eq('id', widget.userId).single(),
      Supabase.instance.client
          .from('conversations')
          .count(CountOption.exact)
          .or('user1_id.eq.${widget.userId},user2_id.eq.${widget.userId}')
          .eq('status', 'accepted'),
      Supabase.instance.client.from('huddle_members').select('id').eq('user_id', widget.userId),
      Supabase.instance.client.from('bro_posts').select('id').eq('user_id', widget.userId),
      if (myId != widget.userId)
        Supabase.instance.client.from('conversations').select().or('and(user1_id.eq.$myId,and(user1_id.eq.$myId,user2_id.eq.${widget.userId})),and(user1_id.eq.${widget.userId},user2_id.eq.$myId)').maybeSingle()
      else
        Future.value(null),
    ]);
  }

  void _refreshData() {
    setState(() {
      _profileFuture = _loadProfileData();
    });
  }

  Future<void> _reportUser() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Report User', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you reporting this user?', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 16),
              ...['Inappropriate behavior', 'Spam or fake account', 'Harassment', 'Other'].map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r, style: const TextStyle(fontFamily: '.SF Pro Display', color: Colors.white, fontSize: 14)),
                leading: const Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 20),
                onTap: () => Navigator.pop(ctx, r),
              )),
            ],
          ),
        );
      },
    );

    if (reason != null && mounted) {
      try {
        final myId = Supabase.instance.client.auth.currentUser!.id;
        await Supabase.instance.client.from('user_reports').insert({
          'reporter_id': myId,
          'reported_user_id': widget.userId,
          'reason': reason,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Report submitted. We will review this promptly.', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w600, color: Colors.white)),
              backgroundColor: const Color(0xFF14B8A6),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(20),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting report: $e')));
        }
      }
    }
  }

  Future<void> _blockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Block User', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('This user will no longer be able to see your profile, posts, or message you. Are you sure?', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.white60, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.redAccent, fontWeight: FontWeight.w700))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final myId = Supabase.instance.client.auth.currentUser!.id;
        await Supabase.instance.client.from('user_blocks').insert({
          'blocker_id': myId,
          'blocked_user_id': widget.userId,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User blocked successfully.', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w600, color: Colors.white)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(20),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error blocking user: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.userId == Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: isMe ? [] : [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1E293B), size: 22),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'report') _reportUser();
              if (value == 'block') _blockUser();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, color: Color(0xFF64748B), size: 18), SizedBox(width: 10), Text('Report User', style: TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w600))])),
              const PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block_rounded, color: Colors.redAccent, size: 18), SizedBox(width: 10), Text('Block User', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600))])),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null && _optimisticConversation == null) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)));
          }

          if (snapshot.hasError || (!snapshot.hasData && _optimisticConversation == null)) {
            return const Center(child: Text("Bro not found."));
          }

          final data = snapshot.hasData ? snapshot.data! : [];
          if (data.isEmpty && _optimisticConversation == null) return const SizedBox();

          final profile = data.isNotEmpty ? data[0] as Map<String, dynamic> : <String, dynamic>{};
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
                          backgroundColor: const Color(0xFFE2E8F0),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? const Icon(Icons.person_rounded, size: 60, color: Color(0xFF94A3B8)) : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        username,
                        style: const TextStyle(fontFamily: '.SF Pro Display', fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 16),
                      
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
                      
                      if (!isMe) ...[
                        if (conversation == null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildActionButton(
                                context, 
                                'CONNECT', 
                                Icons.handshake_rounded, 
                                const Color(0xFF14B8A6), 
                                Colors.white,
                                () => _handleConnection(context, profile, conversation),
                                width: 140,
                              ),
                              const SizedBox(width: 12),
                              _buildActionButton(
                                context,
                                'CALL (TEST)',
                                Icons.mic_rounded,
                                const Color(0xFF1E293B),
                                Colors.white,
                                () {
                                  final myId = Supabase.instance.client.auth.currentUser!.id;
                                  final otherId = profile['id'].toString();
                                  final ids = [myId, otherId]..sort();
                                  final roomId = 'bro_call_${ids[0]}_${ids[1]}';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VoiceCallScreen(
                                        callId: roomId,
                                        myUserId: myId,
                                        myUserName: Supabase.instance.client.auth.currentUser!.email ?? myId,
                                        otherUserName: profile['username'] ?? 'Bro',
                                        isCaller: true,
                                        partnerId: otherId,
                                      ),
                                    ),
                                  );
                                },
                                width: 140,
                              ),
                            ],
                          )
                        else if (conversation['status'] == 'accepted')
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, color: Color(0xFF14B8A6), size: 14),
                                    SizedBox(width: 6),
                                    Text('CONNECTED BROS', style: TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF14B8A6), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildActionButton(
                                    context,
                                    'MESSAGE',
                                    Icons.chat_bubble_outline,
                                    const Color(0xFF1E293B),
                                    Colors.white,
                                    () => _handleConnection(context, profile, conversation),
                                    width: 140,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildActionButton(
                                    context,
                                    'CALL',
                                    Icons.mic_rounded,
                                    const Color(0xFF14B8A6),
                                    Colors.white,
                                    () {
                                      final myId = Supabase.instance.client.auth.currentUser!.id;
                                      final otherId = profile['id'].toString();
                                      // Deterministic room: smaller ID always goes first
                                      final ids = [myId, otherId]..sort();
                                      final roomId = 'bro_call_${ids[0]}_${ids[1]}';
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VoiceCallScreen(
                                            callId: roomId,
                                            myUserId: myId,
                                            myUserName: Supabase.instance.client.auth.currentUser!.email ?? myId,
                                            otherUserName: profile['username'] ?? 'Bro',
                                            isCaller: true,
                                            partnerId: otherId,
                                          ),
                                        ),
                                      );
                                    },
                                    width: 140,
                                  ),
                                ],
                              ),
                            ],
                          )
                        else if (conversation['status'] == 'pending')
                          if (conversation['initiator_id'] == Supabase.instance.client.auth.currentUser!.id)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                  context, 
                                  'REQUEST SENT', 
                                  Icons.check, 
                                  const Color(0xFFF1F5F9), 
                                  const Color(0xFF94A3B8),
                                  null,
                                  width: 140,
                                ),
                                const SizedBox(width: 12),
                                _buildActionButton(
                                  context,
                                  'CALL (TEST)',
                                  Icons.mic_rounded,
                                  const Color(0xFF1E293B),
                                  Colors.white,
                                  () {
                                    final myId = Supabase.instance.client.auth.currentUser!.id;
                                    final otherId = profile['id'].toString();
                                    final ids = [myId, otherId]..sort();
                                    final roomId = 'bro_call_${ids[0]}_${ids[1]}';
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VoiceCallScreen(
                                          callId: roomId,
                                          myUserId: myId,
                                          myUserName: Supabase.instance.client.auth.currentUser!.email ?? myId,
                                          otherUserName: profile['username'] ?? 'Bro',
                                          isCaller: true,
                                          partnerId: otherId,
                                        ),
                                      ),
                                    );
                                  },
                                  width: 140,
                                ),
                              ],
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                  context, 
                                  'DECLINE', 
                                  Icons.close, 
                                  const Color(0xFFFEE2E2), 
                                  Colors.redAccent,
                                  () async {
                                    await Supabase.instance.client.from('conversations').delete().eq('id', conversation['id']);
                                    setState(() {
                                       _optimisticConversation = null; 
                                    });
                                    _refreshData();
                                  },
                                  width: 140
                                ),
                                const SizedBox(width: 16),
                                _buildActionButton(
                                  context, 
                                  'ACCEPT', 
                                  Icons.check_rounded, 
                                  const Color(0xFF14B8A6), 
                                  Colors.white,
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
                                      
                                      if (response.isEmpty) {
                                        throw 'Update failed.';
                                      }
                                            
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are now Bros! 👊')));
                                        _refreshData();
                                      }
                                    } catch (e) {
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
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                              ),
                              child: Text(
                                vibe.toUpperCase(),
                                style: const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            )).toList(),
                        ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ABOUT BRO',
                              style: TextStyle(fontFamily: '.SF Pro Display', 
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              bio,
                              style: const TextStyle(fontFamily: '.SF Pro Display', fontSize: 15, color: Color(0xFF334155), height: 1.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Row(
                        children: [
                          Icon(Icons.history_rounded, color: Color(0xFF94A3B8), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'RECENT POSTS',
                            style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _postStream, // Use persistent stream
                        builder: (ctx, postSnap) {
                          if (!postSnap.hasData) return const SizedBox();
                          final posts = postSnap.data!;
                          if (posts.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text("No posts yet. Silent but steady.", style: TextStyle(color: Colors.black26)),
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
        Text(value, style: const TextStyle(fontFamily: '.SF Pro Display', fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontFamily: '.SF Pro Display', fontSize: 12, color: Color(0xFF64748B))),
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
        label: Text(label, style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.bold, fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          disabledBackgroundColor: const Color(0xFFF1F5F9),
          disabledForegroundColor: const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

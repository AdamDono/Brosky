import 'dart:async';
import 'package:bro_app/src/features/chat/presentation/bro_direct_screen.dart';
import 'package:bro_app/src/features/chat/presentation/voice_call_screen.dart';
import 'package:bro_app/src/features/feed/presentation/feed_screen.dart';
import 'package:bro_app/src/features/huddles/presentation/huddles_screen.dart';
import 'package:bro_app/src/features/huddles/presentation/squad_requests_screen.dart';
import 'package:bro_app/src/features/match/presentation/match_screen.dart';
import 'package:bro_app/src/features/notifications/presentation/notifications_screen.dart';
import 'package:bro_app/src/features/profile/presentation/profile_screen.dart';
import 'package:bro_app/src/features/feed/presentation/post_detail_screen.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:bro_app/src/features/notifications/presentation/widgets/bro_toast.dart';
import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
import 'package:bro_app/src/features/huddles/presentation/create_huddle_modal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens; // Store screens persistently
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Color _primaryColor = const Color(0xFF14B8A6);
  int _pendingRequestCount = 0;
  int _pendingNotificationCount = 0;
  int _unreadMessagesCount = 0;
  Map<String, dynamic>? _myProfile;
  int _broCount = 0;
  int _huddleCount = 0;

  // Call Signaling State Variables
  StreamSubscription<List<Map<String, dynamic>>>? _callSubscription;
  Timer? _incomingCallPollingTimer;
  bool _isShowingCallDialog = false;
  String? _activeCallId;

  // Presence Update Timer
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    _screens = [
      const FeedScreen(key: PageStorageKey('feed')),
      const MatchScreen(key: PageStorageKey('match')),
      const HuddlesScreen(key: PageStorageKey('huddles')),
      const BroDirectScreen(key: PageStorageKey('messages')),
    ];
    _loadPendingRequests();
    _setupBadgeListeners();
    _setupCallListener();
    _startIncomingCallPolling();
    _loadProfile();
    _startPresenceHeartbeat();
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _incomingCallPollingTimer?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  void _startPresenceHeartbeat() {
    _updatePresence();
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updatePresence();
    });
  }

  Future<void> _updatePresence() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', user.id);
      } catch (e) {
        debugPrint('Error updating presence heartbeat: $e');
      }
    }
  }

  void _setupBadgeListeners() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Listen for DM changes
    Supabase.instance.client
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', user.id)
        .listen((data) {
          final unreadDMs = data.where((m) => m['is_read'] == false).length;
          if (mounted) {
            setState(() {
              _unreadMessagesCount = unreadDMs;
            });
          }
        });

    DateTime? lastNotifTime;

    // Listen for notification changes
    Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((data) {
          final unreadNotifs = data.where((n) => n['is_read'] == false).length;
          
          if (lastNotifTime == null) {
            if (data.isNotEmpty) {
              lastNotifTime = data.map((n) => DateTime.parse(n['created_at'])).reduce((a, b) => a.isAfter(b) ? a : b);
            } else {
              lastNotifTime = DateTime.now().toUtc();
            }
          } else {
            for (var notif in data) {
              final created = DateTime.parse(notif['created_at']);
              if (created.isAfter(lastNotifTime!)) {
                lastNotifTime = created;
                if (notif['actor_id'] != user.id && notif['type'] != 'direct_message') {
                  _showNotificationToast(notif);
                }
              }
            }
          }

          if (mounted) {
            setState(() {
              _pendingNotificationCount = unreadNotifs;
            });
          }
        });
  }

  Future<void> _showNotificationToast(Map<String, dynamic> notif) async {
    final actorId = notif['actor_id'];
    if (actorId == null) return;

    try {
      final actorProfile = await Supabase.instance.client
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', actorId)
          .single();

      final username = actorProfile['username'] ?? 'Someone';
      final avatarUrl = actorProfile['avatar_url'];
      final type = notif['type'];
      
      String title = 'BRO CONTACT';
      String message = 'Vibing with you';

      if (type == 'post_reaction') {
        title = '👊 POST REACTED';
        message = '@$username liked your post';
      } else if (type == 'post_comment') {
        title = '💬 COMMENT POSTED';
        message = '@$username commented on your post';
      } else if (type == 'new_follower') {
        title = '🤝 CONNECT REQUEST';
        message = '@$username wants to connect with you';
      }

      if (mounted) {
        BroToast.show(
          context,
          title: title,
          message: message,
          avatarUrl: avatarUrl,
          onTap: () async {
            Supabase.instance.client.from('notifications').update({'is_read': true}).eq('id', notif['id']);
            
            if (type == 'post_reaction' || type == 'post_comment') {
              try {
                final refId = notif['reference_id'];
                Map<String, dynamic>? post;

                try {
                  post = await Supabase.instance.client
                      .from('bro_posts')
                      .select()
                      .eq('id', refId)
                      .single();
                } catch (_) {
                  if (type == 'post_comment') {
                    final comment = await Supabase.instance.client
                        .from('post_comments')
                        .select('post_id')
                        .eq('id', refId)
                        .single();
                    post = await Supabase.instance.client
                        .from('bro_posts')
                        .select()
                        .eq('id', comment['post_id'])
                        .single();
                  } else if (type == 'post_reaction') {
                    final reaction = await Supabase.instance.client
                        .from('post_likes')
                        .select('post_id')
                        .eq('id', refId)
                        .single();
                    post = await Supabase.instance.client
                        .from('bro_posts')
                        .select()
                        .eq('id', reaction['post_id'])
                        .single();
                  }
                }

                if (post != null && mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post!)));
                }
              } catch (e) {
                debugPrint('Error routing from toast: $e');
              }
            } else if (type == 'new_follower') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: actorId)));
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error showing toast: $e');
    }
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles').select().eq('id', user.id).single();
      final cons = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}')
          .eq('status', 'accepted');
      final huddles = await Supabase.instance.client
          .from('huddle_members').select('id').eq('user_id', user.id);
      if (mounted) setState(() {
        _myProfile = Map<String, dynamic>.from(profile);
        _broCount = (cons as List).length;
        _huddleCount = (huddles as List).length;
      });
    } catch (_) {}
  }

  Future<void> _loadPendingRequests() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      // Fetch squads this user created
      final mySquadsRes = await Supabase.instance.client
          .from('huddles')
          .select('id')
          .eq('creator_id', user.id);
      final mySquadIds = (mySquadsRes as List).map((s) => s['id'].toString()).toList();
      if (mySquadIds.isEmpty) return;

      // Count pending requests for those squads
      final requestsRes = await Supabase.instance.client
          .from('huddle_join_requests')
          .select('id')
          .inFilter('huddle_id', mySquadIds)
          .eq('status', 'pending');

      if (mounted) setState(() => _pendingRequestCount = (requestsRes as List).length);
    } catch (_) {
      // Table may not exist yet — silently skip
    }
  }

  void _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Sign Out?', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.bold, color: Colors.black)),
        content: Text('Leave the Brotherhood for now?', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black26, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('SIGN OUT', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white, // --- FLAT BOUTIQUE PURE WHITE ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
          ),
          child: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leadingWidth: 60,
            leading: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedMenu01, color: Color(0xFF1A1D21), size: 22),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                if (_pendingNotificationCount > 0)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            title: Text(
              'BROSKY',
              style: TextStyle(fontFamily: '.SF Pro Display', 
                fontWeight: FontWeight.w800, 
                letterSpacing: 2.0, 
                fontSize: 16, 
                color: const Color(0xFF1A1D21)
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ProfileScreen()));
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: Supabase.instance.client.from('profiles').select('avatar_url').eq('id', Supabase.instance.client.auth.currentUser?.id ?? '').single(),
                    builder: (context, snapshot) {
                      final avatarUrl = snapshot.data?['avatar_url'];
                      return Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
                          image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                        ),
                        child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Colors.black26, size: 18) : null,
                      );
                    }
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: _currentIndex == 1 // No add on Radar
          ? null 
          : FloatingActionButton(
              onPressed: () {
                if (_currentIndex == 2) {
                  // BROHOOD: Start Huddle
                  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const CreateHuddleModal());
                } else {
                  // DEFAULT/FEED: Create Post
                  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const CreatePostModal());
                }
              },
              backgroundColor: _primaryColor,
              elevation: 4,
              key: const ValueKey('floating_action_button'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const HugeIcon(icon: HugeIcons.strokeRoundedPlusSign, color: Colors.white, size: 24),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.white,
          selectedItemColor: _primaryColor,
          unselectedItemColor: const Color(0xFF94A3B8),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontFamily: '.SF Pro Display', fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          unselectedLabelStyle: TextStyle(fontFamily: '.SF Pro Display', fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
          items: [
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: HugeIcon(icon: HugeIcons.strokeRoundedHome01, color: _currentIndex == 0 ? _primaryColor : const Color(0xFF94A3B8), size: 22)),
              label: 'FEED',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: HugeIcon(icon: HugeIcons.strokeRoundedRadar01, color: _currentIndex == 1 ? _primaryColor : const Color(0xFF94A3B8), size: 22)),
              label: 'RADAR',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, color: _currentIndex == 2 ? _primaryColor : const Color(0xFF94A3B8), size: 22)),
              label: 'BROHOOD',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: _unreadMessagesCount > 0 && _currentIndex != 3,
                label: Text('$_unreadMessagesCount', style: const TextStyle(fontFamily: '.SF Pro Display', fontSize: 10, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.redAccent,
                offset: const Offset(5, -5),
                child: Padding(padding: const EdgeInsets.only(bottom: 4), child: HugeIcon(icon: HugeIcons.strokeRoundedBubbleChat, color: _currentIndex == 3 ? _primaryColor : const Color(0xFF94A3B8), size: 22)),
              ),
              label: 'MESSAGES',
            ),
          ],
        ),
      ),
    ),  // closes Container
    );
  }

  Widget _buildDrawer() {
    final username = _myProfile?['username'] ?? 'Bro';
    final bio = _myProfile?['bio']?.toString().trim();
    final avatarUrl = _myProfile?['avatar_url'];
    final navItems = [
      {'icon': HugeIcons.strokeRoundedHome01,     'label': 'Feed',     'index': 0},
      {'icon': HugeIcons.strokeRoundedRadar01,    'label': 'Radar',    'index': 1},
      {'icon': HugeIcons.strokeRoundedUserGroup,  'label': 'Brohood',  'index': 2},
      {'icon': HugeIcons.strokeRoundedBubbleChat, 'label': 'Messages', 'index': 3},
    ];

    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.78,
      elevation: 0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── PROFILE ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); },
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF1F5F9),
                        border: Border.all(color: _primaryColor.withOpacity(0.25), width: 1.5),
                        image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                      ),
                      child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Colors.black26, size: 22) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        if (bio != null && bio.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(bio, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 13, color: Colors.black38, fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.black26, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Inline stats
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Text(
                '$_broCount Bros  ·  $_huddleCount Squads',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 13, color: Colors.black38, fontWeight: FontWeight.w500),
              ),
            ),

            Container(height: 1, color: Colors.black.withOpacity(0.05)),

            // ── NAVIGATION ─────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  ...navItems.map((item) {
                    final idx = item['index'] as int;
                    return _buildNavRow(
                      icon: item['icon'] as dynamic,
                      label: item['label'] as String,
                      isSelected: _currentIndex == idx,
                      onTap: () { setState(() => _currentIndex = idx); Navigator.pop(context); },
                    );
                  }),

                  const SizedBox(height: 4),

                  _buildNotificationRow(),

                  _buildNavRow(
                    icon: HugeIcons.strokeRoundedUser,
                    label: 'My Profile',
                    isSelected: false,
                    onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); },
                  ),
                ],
              ),
            ),

            // ── FOOTER ─────────────────────────────────────────────
            Container(height: 1, color: Colors.black.withOpacity(0.05)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: GestureDetector(
                onTap: _signOut,
                child: Row(
                  children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedLogout01, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Text('Sign out', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildNavRow({required dynamic icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: isSelected ? _primaryColor : const Color(0xFF94A3B8),
              size: 19,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(fontFamily: '.SF Pro Display', 
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _primaryColor : const Color(0xFF334155),
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 5, height: 5,
                decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationRow() {
    final hasNotifications = _pendingNotificationCount > 0;
    
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: hasNotifications ? _primaryColor.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedNotification01, 
              color: hasNotifications ? _primaryColor : const Color(0xFF94A3B8), 
              size: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Notifications', 
                style: TextStyle(fontFamily: '.SF Pro Display', 
                  fontSize: 15, 
                  fontWeight: hasNotifications ? FontWeight.w700 : FontWeight.w500, 
                  color: hasNotifications ? _primaryColor : const Color(0xFF334155),
                ),
              ),
            ),
            if (hasNotifications)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _primaryColor, 
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Text('$_pendingNotificationCount', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  void _setupCallListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Stream the calls table and do all filtering in Dart to bypass Postgres Realtime UUID replication bugs
    _callSubscription = Supabase.instance.client
        .from('calls')
        .stream(primaryKey: ['id'])
        .listen((data) async {
          if (_isShowingCallDialog || data.isEmpty) return;

          // Find the first 'connecting' call where we are the receiver
          final activeCall = data.firstWhere(
            (c) => c['receiver_id'] == user.id && c['status'] == 'connecting',
            orElse: () => <String, dynamic>{},
          );

          if (activeCall.isEmpty) return;

          final callId = activeCall['id'] as String;
          final callerId = activeCall['caller_id'] as String;
          final roomId = activeCall['room_id'] as String;

          _isShowingCallDialog = true;
          _activeCallId = callId;

          // 1. Immediately update status to 'ringing' so caller knows we are online
          try {
            await Supabase.instance.client
                .from('calls')
                .update({'status': 'ringing'})
                .eq('id', callId);
          } catch (e) {
            debugPrint('Error updating status to ringing: $e');
          }

          // 2. Fetch the caller's username
          String callerUsername = 'Bro';
          String? callerAvatar;
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('username, avatar_url')
                .eq('id', callerId)
                .single();
            callerUsername = profile['username'] ?? 'Bro';
            callerAvatar = profile['avatar_url'];
          } catch (_) {}

          if (!mounted) return;

          // 3. Show incoming call dialog
          _showIncomingCallDialog(callId, callerId, callerUsername, callerAvatar, roomId);
        });
  }

  void _startIncomingCallPolling() {
    _incomingCallPollingTimer?.cancel();
    _incomingCallPollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || _isShowingCallDialog) return;

      try {
        final List<dynamic> data = await Supabase.instance.client
            .from('calls')
            .select()
            .eq('receiver_id', user.id)
            .eq('status', 'connecting');

        if (data.isNotEmpty && !_isShowingCallDialog && mounted) {
          final activeCall = data.first;
          final callId = activeCall['id'] as String;
          final callerId = activeCall['caller_id'] as String;
          final roomId = activeCall['room_id'] as String;

          _isShowingCallDialog = true;
          _activeCallId = callId;

          // 1. Immediately update status to 'ringing' so caller knows we are online
          try {
            await Supabase.instance.client
                .from('calls')
                .update({'status': 'ringing'})
                .eq('id', callId);
          } catch (e) {
            debugPrint('Error updating status to ringing: $e');
          }

          // 2. Fetch the caller's username
          String callerUsername = 'Bro';
          String? callerAvatar;
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('username, avatar_url')
                .eq('id', callerId)
                .single();
            callerUsername = profile['username'] ?? 'Bro';
            callerAvatar = profile['avatar_url'];
          } catch (_) {}

          if (!mounted) return;

          // 3. Show incoming call dialog
          _showIncomingCallDialog(callId, callerId, callerUsername, callerAvatar, roomId);
        }
      } catch (e) {
        debugPrint('Error polling incoming calls: $e');
      }
    });
  }

  void _showIncomingCallDialog(
    String callId,
    String callerId,
    String callerUsername,
    String? callerAvatar,
    String roomId,
  ) {
    StreamSubscription<List<Map<String, dynamic>>>? specificCallSub;
    Timer? dialogPollTimer;

    void cleanupDialog() {
      specificCallSub?.cancel();
      dialogPollTimer?.cancel();
    }
    
    specificCallSub = Supabase.instance.client
        .from('calls')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (data.isNotEmpty) {
            final activeCall = data.firstWhere(
              (c) => c['id'] == callId,
              orElse: () => <String, dynamic>{},
            );
            if (activeCall.isNotEmpty) {
              final status = activeCall['status'];
              if (status == 'ended' || status == 'rejected') {
                cleanupDialog();
                if (_isShowingCallDialog && mounted) {
                  Navigator.of(context, rootNavigator: true).pop(false);
                  _isShowingCallDialog = false;
                  _activeCallId = null;
                }
              }
            }
          }
        });

    // Dialog status polling fallback
    dialogPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final data = await Supabase.instance.client
            .from('calls')
            .select('status')
            .eq('id', callId)
            .maybeSingle();

        if (data != null && mounted) {
          final status = data['status'];
          if (status == 'ended' || status == 'rejected') {
            cleanupDialog();
            if (_isShowingCallDialog && mounted) {
              Navigator.of(context, rootNavigator: true).pop(false);
              _isShowingCallDialog = false;
              _activeCallId = null;
            }
          }
        }
      } catch (_) {}
    });

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final primaryTeal = const Color(0xFF14B8A6);
        return WillPopScope(
          onWillPop: () async => false, // Prevent physical back button dismissal
          child: Dialog(
            backgroundColor: const Color(0xFF0F172A), // Premium Dark Slate
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 24,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: primaryTeal, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'INCOMING BRO CALL',
                        style: TextStyle(
                          fontFamily: '.SF Pro Display',
                          color: Color(0xFF14B8A6),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E293B),
                      border: Border.all(color: primaryTeal.withOpacity(0.3), width: 2),
                      image: callerAvatar != null 
                          ? DecorationImage(image: NetworkImage(callerAvatar), fit: BoxFit.cover) 
                          : null,
                    ),
                    child: callerAvatar == null 
                        ? const Icon(Icons.person, color: Colors.white24, size: 48) 
                        : null,
                  ),
                  const SizedBox(height: 20),
                  
                  Text(
                    callerUsername,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: '.SF Pro Display',
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  const Text(
                    'wants to voice chat',
                    style: TextStyle(
                      fontFamily: '.SF Pro Display',
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 36),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          cleanupDialog();
                          Navigator.of(ctx).pop(false);
                          _isShowingCallDialog = false;
                          _activeCallId = null;
                          try {
                            await Supabase.instance.client
                                .from('calls')
                                .update({'status': 'rejected'})
                                .eq('id', callId);
                          } catch (e) {
                            debugPrint('Error updating status to rejected: $e');
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent,
                              ),
                              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Decline',
                              style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      
                      GestureDetector(
                        onTap: () async {
                          cleanupDialog();
                          Navigator.of(ctx).pop(true);
                          _isShowingCallDialog = false;
                          _activeCallId = null;
                          try {
                            await Supabase.instance.client
                                .from('calls')
                                .update({'status': 'answered'})
                                .eq('id', callId);
                          } catch (e) {
                            debugPrint('Error updating status to answered: $e');
                          }
                          
                          if (mounted) {
                            final user = Supabase.instance.client.auth.currentUser!;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VoiceCallScreen(
                                  callId: roomId,
                                  myUserId: user.id,
                                  myUserName: user.email ?? user.id,
                                  otherUserName: callerUsername,
                                  isCaller: false,
                                  dbCallId: callId,
                                ),
                              ),
                            );
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                              child: const Icon(Icons.phone_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Answer',
                              style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

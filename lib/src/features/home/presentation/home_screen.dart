import 'package:bro_app/src/features/chat/presentation/bro_direct_screen.dart';
import 'package:bro_app/src/features/feed/presentation/feed_screen.dart';
import 'package:bro_app/src/features/huddles/presentation/huddles_screen.dart';
import 'package:bro_app/src/features/huddles/presentation/squad_requests_screen.dart';
import 'package:bro_app/src/features/match/presentation/match_screen.dart';
import 'package:bro_app/src/features/profile/presentation/profile_screen.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Color _primaryColor = const Color(0xFF14B8A6);
  int _pendingRequestCount = 0;
  int _unreadMessagesCount = 0;
  Map<String, dynamic>? _myProfile;
  int _broCount = 0;
  int _huddleCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
    _loadUnreadBadges();
    _loadProfile();
  }

  Future<void> _loadUnreadBadges() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
      
      final unreadDMs = await Supabase.instance.client
          .from('direct_messages')
          .select('id')
          .eq('receiver_id', user.id)
          .eq('is_read', false)
          .gt('created_at', threeDaysAgo);
          
      final unreadRequests = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .eq('status', 'pending')
          .neq('initiator_id', user.id)
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}');

      if (mounted) {
        setState(() {
          _unreadMessagesCount = (unreadDMs as List).length + (unreadRequests as List).length;
        });
      }
    } catch (_) {}
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
    final List<Widget> screens = [
      const FeedScreen(),
      const MatchScreen(), // Radar
      const HuddlesScreen(), // Community
      const BroDirectScreen(), // Messages
    ];

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
                if (_pendingRequestCount > 0)
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
        children: screens,
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
        height: 85,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            _loadUnreadBadges();
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
    );
  }  Widget _buildDrawer() {
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
    final hasNotifications = _pendingRequestCount > 0;
    
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const SquadRequestsScreen()));
        _loadPendingRequests();
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
                child: Text('$_pendingRequestCount', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}

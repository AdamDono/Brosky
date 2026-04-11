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
  Map<String, dynamic>? _myProfile;
  int _broCount = 0;
  int _huddleCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
    _loadProfile();
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
        title: Text('Sign Out?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black)),
        content: Text('Leave the Brotherhood for now?', style: GoogleFonts.inter(color: Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.black26, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('SIGN OUT', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold))),
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
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w900, 
                letterSpacing: 4.0, 
                fontSize: 18, 
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
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: _primaryColor,
          unselectedItemColor: const Color(0xFF94A3B8),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
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
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: HugeIcon(icon: HugeIcons.strokeRoundedBubbleChat, color: _currentIndex == 3 ? _primaryColor : const Color(0xFF94A3B8), size: 22)),
              label: 'MESSAGES',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final username = _myProfile?['username'] ?? 'BRO';
    final bio = _myProfile?['bio'] ?? 'Ready to build.';
    final avatarUrl = _myProfile?['avatar_url'];
    final navItems = [
      {'icon': HugeIcons.strokeRoundedHome01,     'label': 'Feed',      'index': 0},
      {'icon': HugeIcons.strokeRoundedRadar01,    'label': 'Radar',     'index': 1},
      {'icon': HugeIcons.strokeRoundedUserGroup,  'label': 'Brohood',   'index': 2},
      {'icon': HugeIcons.strokeRoundedBubbleChat, 'label': 'Messages',  'index': 3},
    ];

    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          children: [
            // ── PROFILE HEADER ──────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: _primaryColor.withOpacity(0.3), width: 2),
                          image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                        ),
                        child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Colors.black26, size: 28) : null,
                      ),
                      const Spacer(),
                      // Close
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF1F5F9), width: 1)),
                          child: const Center(child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.black26, size: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(username.toUpperCase(), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(bio, style: GoogleFonts.inter(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 20),
                  // Stats row
                  Row(
                    children: [
                      _buildStatChip('$_broCount', 'BROS'),
                      const SizedBox(width: 12),
                      _buildStatChip('$_huddleCount', 'SQUADS'),
                    ],
                  ),
                ],
              ),
            ),

            // ── NAVIGATION ──────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                children: [
                  // Section label
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 10),
                    child: Text('NAVIGATE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                  ),
                  ...navItems.map((item) {
                    final idx = item['index'] as int;
                    final isSelected = _currentIndex == idx;
                    return _buildPremiumNavItem(
                      icon: item['icon'] as dynamic,
                      label: item['label'] as String,
                      isSelected: isSelected,
                      onTap: () { setState(() => _currentIndex = idx); Navigator.pop(context); },
                    );
                  }),

                  const SizedBox(height: 24),

                  // Squad Requests Notification
                  if (_pendingRequestCount > 0) ..._buildRequestsDrawerItem(),

                  const SizedBox(height: 24),

                  // Profile shortcut
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 10),
                    child: Text('ACCOUNT', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                  ),
                  _buildPremiumNavItem(
                    icon: HugeIcons.strokeRoundedUser,
                    label: 'My Profile',
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    },
                  ),
                ],
              ),
            ),

            // ── FOOTER ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.black.withOpacity(0.04), width: 1))),
              child: GestureDetector(
                onTap: _signOut,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.12), width: 1),
                  ),
                  child: Row(
                    children: [
                      const HugeIcon(icon: HugeIcons.strokeRoundedLogout01, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 14),
                      Text('SIGN OUT', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildPremiumNavItem({required dynamic icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryColor.withOpacity(0.2) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: HugeIcon(icon: icon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 18)),
            ),
            const SizedBox(width: 16),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                color: isSelected ? _primaryColor : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle)),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns a list so it can be spread into the drawer ListView with `...`
  List<Widget> _buildRequestsDrawerItem() {
    return [
      const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Divider(height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: GestureDetector(
          onTap: () async {
            Navigator.pop(context);
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SquadRequestsScreen()));
            // Refresh badge count after returning from requests screen
            _loadPendingRequests();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryColor.withOpacity(0.15), width: 1),
            ),
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedNotification01, color: _primaryColor, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SQUAD REQUESTS', style: GoogleFonts.inter(color: _primaryColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
                      const SizedBox(height: 2),
                      Text('$_pendingRequestCount pending enlistment${_pendingRequestCount == 1 ? '' : 's'}', style: GoogleFonts.inter(color: _primaryColor.withOpacity(0.7), fontWeight: FontWeight.w600, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle),
                  child: Center(child: Text('$_pendingRequestCount', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

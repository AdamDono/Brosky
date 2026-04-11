import 'package:bro_app/src/features/chat/presentation/bro_direct_screen.dart';
import 'package:bro_app/src/features/feed/presentation/feed_screen.dart';
import 'package:bro_app/src/features/huddles/presentation/huddles_screen.dart';
import 'package:bro_app/src/features/match/presentation/match_screen.dart';
import 'package:bro_app/src/features/profile/presentation/profile_screen.dart';
import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
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
  final Color _primaryColor = const Color(0xFF14B8A6); // Urban Teal

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
            leading: IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedMenu01, color: Color(0xFF1A1D21), size: 22),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const CreatePostModal()),
        backgroundColor: _primaryColor,
        elevation: 4,
        key: const ValueKey('floating_post_button'),
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
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              child: Row(
                children: [
                  Text('BROSKY', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 3)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.black12, size: 24)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                children: [
                   _buildDrawerItem(icon: HugeIcons.strokeRoundedHome01, title: 'Feed', isSelected: _currentIndex == 0, onTap: () { setState(() => _currentIndex = 0); Navigator.pop(context); }),
                  _buildDrawerItem(icon: HugeIcons.strokeRoundedRadar01, title: 'Radar', isSelected: _currentIndex == 1, onTap: () { setState(() => _currentIndex = 1); Navigator.pop(context); }),
                  _buildDrawerItem(icon: HugeIcons.strokeRoundedUserGroup, title: 'Community', isSelected: _currentIndex == 2, onTap: () { setState(() => _currentIndex = 2); Navigator.pop(context); }),
                  _buildDrawerItem(icon: HugeIcons.strokeRoundedBubbleChat, title: 'Messages', isSelected: _currentIndex == 3, onTap: () { setState(() => _currentIndex = 3); Navigator.pop(context); }),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24), child: Divider(height: 1)),
                  _buildDrawerItem(icon: HugeIcons.strokeRoundedLogout01, title: 'Sign Out', onTap: _signOut, textColor: Colors.redAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({required List<List<dynamic>> icon, required String title, required VoidCallback onTap, bool isSelected = false, Color? textColor}) {
    return ListTile(
      leading: HugeIcon(icon: icon, color: isSelected ? _primaryColor : const Color(0xFF94A3B8), size: 24),
      title: Text(
        title.toUpperCase(), 
        style: GoogleFonts.inter(
          color: textColor ?? (isSelected ? _primaryColor : const Color(0xFF475569)),
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
        )
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      tileColor: isSelected ? _primaryColor.withOpacity(0.08) : null,
    );
  }
}

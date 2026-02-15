import 'package:bro_app/src/features/chat/presentation/bro_direct_screen.dart';
import 'package:bro_app/src/features/feed/presentation/feed_screen.dart';
import 'package:bro_app/src/features/huddles/presentation/huddles_screen.dart';
import 'package:bro_app/src/features/match/presentation/match_screen.dart';
import 'package:bro_app/src/features/notifications/presentation/notifications_screen.dart';
import 'package:bro_app/src/features/profile/presentation/profile_screen.dart';
import 'package:bro_app/src/features/feed/presentation/create_post_modal.dart';
import 'package:bro_app/src/features/huddles/presentation/create_huddle_modal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _refreshCount = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateToScreen(int index) {
    setState(() => _currentIndex = index);
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _navigateToRadar() => _navigateToScreen(2);

  void _navigateToNotifications() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => const NotificationsScreen()));
  }

  void _handleRefresh() {
    setState(() {
      _refreshCount++;
    });
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent))),
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
    // Re-create screens with keys on every build to allow for the refresh trick
    final List<Widget> screens = [
      FeedScreen(key: ValueKey('feed_$_refreshCount')),
      BroDirectScreen(key: ValueKey('direct_$_refreshCount')),
      MatchScreen(key: ValueKey('match_$_refreshCount')),
      HuddlesScreen(key: ValueKey('huddles_$_refreshCount')),
      const ProfileScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF2DD4BF)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _currentIndex == 0 ? 'Brotherhood Feed' :
          _currentIndex == 1 ? 'Bro-Direct' :
          _currentIndex == 2 ? 'Bro Radar' :
          _currentIndex == 3 ? 'Huddles' : 'My Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_currentIndex < 4)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF2DD4BF)),
              onPressed: _handleRefresh,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      drawer: _buildDrawer(),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const CreatePostModal()),
        backgroundColor: const Color(0xFF2DD4BF),
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ) : _currentIndex == 3 ? FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const CreateHuddleModal()),
        backgroundColor: const Color(0xFF2DD4BF),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('START HUDDLE', style: TextStyle(fontWeight: FontWeight.bold)),
      ) : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF2DD4BF),
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Direct'),
          BottomNavigationBarItem(icon: Icon(Icons.radar_outlined), label: 'Radar'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_outlined), label: 'Huddles'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final user = Supabase.instance.client.auth.currentUser;
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text('BROSKY', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF2DD4BF))),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white38)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  _buildDrawerItem(icon: Icons.forum, title: 'Feed', isSelected: _currentIndex == 0, onTap: () => _navigateToScreen(0)),
                  _buildDrawerItem(icon: Icons.chat_bubble, title: 'Bro-Direct', isSelected: _currentIndex == 1, onTap: () => _navigateToScreen(1)),
                  _buildDrawerItem(icon: Icons.radar, title: 'Bro Radar', isSelected: _currentIndex == 2, onTap: () => _navigateToRadar()),
                  _buildDrawerItem(icon: Icons.groups, title: 'Huddles', isSelected: _currentIndex == 3, onTap: () => _navigateToScreen(3)),
                  _buildDrawerItem(icon: Icons.notifications, title: 'Notifications', onTap: _navigateToNotifications),
                  _buildDrawerItem(icon: Icons.person, title: 'Profile', isSelected: _currentIndex == 4, onTap: () => _navigateToScreen(4)),
                  _buildDrawerItem(icon: Icons.logout, title: 'Sign Out', onTap: _signOut, textColor: Colors.redAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({required IconData icon, required String title, required VoidCallback onTap, bool isSelected = false, Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF2DD4BF) : Colors.white60),
      title: Text(title, style: GoogleFonts.outfit(color: textColor ?? (isSelected ? const Color(0xFF2DD4BF) : Colors.white))),
      onTap: onTap,
    );
  }
}

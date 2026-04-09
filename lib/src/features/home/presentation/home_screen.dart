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
      const MatchScreen(), // Radar/Favorites
      const HuddlesScreen(), // Community/Groups
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0, // We'll build the header inside the screens
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        height: 85,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          selectedItemColor: _primaryColor,
          unselectedItemColor: const Color(0xFF7E858E),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.2),
          items: [
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: HugeIcon(icon: HugeIcons.strokeRoundedHome01, color: _currentIndex == 0 ? _primaryColor : const Color(0xFF7E858E), size: 24)),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: HugeIcon(icon: HugeIcons.strokeRoundedFavourite, color: _currentIndex == 1 ? _primaryColor : const Color(0xFF7E858E), size: 24)),
              label: 'Favorites',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, color: _currentIndex == 2 ? _primaryColor : const Color(0xFF7E858E), size: 24)),
              label: 'Community',
            ),
            BottomNavigationBarItem(
              icon: Padding(padding: const EdgeInsets.only(bottom: 4), child: HugeIcon(icon: HugeIcons.strokeRoundedUser, color: _currentIndex == 3 ? _primaryColor : const Color(0xFF7E858E), size: 24)),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

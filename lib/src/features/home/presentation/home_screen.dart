import 'package:bro_app/src/features/feed/presentation/feed_screen.dart';
import 'package:bro_app/src/features/huddles/presentation/huddles_screen.dart';
import 'package:bro_app/src/features/match/presentation/match_screen.dart';
import 'package:bro_app/src/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FeedScreen(),
    const MatchScreen(),
    const HuddlesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF0F172A),
          selectedItemColor: const Color(0xFF2DD4BF),
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.outfit(),
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          showUnselectedLabels: true,
          elevation: 0,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Feed'),
            BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Match'),
            BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Huddles'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

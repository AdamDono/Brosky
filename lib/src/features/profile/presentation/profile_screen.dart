import 'package:bro_app/src/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            // Profile Header
            const Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Color(0xFF2DD4BF),
                child: Icon(Icons.person, size: 60, color: Colors.black),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Damian_89',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Building the future of connection 🚀\nStartup Founder | Tech | Fitness',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white60,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            // Edit Profile Button
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                'Edit Profile',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ),
            
            const SizedBox(height: 32),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat('Bros', '142'),
                _buildStat('Huddles', '28'),
                _buildStat('Vibe', '98%'),
              ],
            ),
            
            const SizedBox(height: 32),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // Settings / Menu Items
            _buildMenuItem(Icons.workspace_premium, 'Bro Premium', badge: true),
            _buildMenuItem(Icons.history, 'Huddle History'),
            _buildMenuItem(Icons.share, 'Invite Friends'),
            _buildMenuItem(Icons.help_outline, 'Help & Support'),
            
            const SizedBox(height: 24),
            TextButton(
              onPressed: _signOut,
              child: Text(
                'Sign Out',
                style: GoogleFonts.outfit(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2DD4BF),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {bool badge = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: badge 
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
            )
          : const Icon(Icons.chevron_right, color: Colors.white24),
    );
  }
}

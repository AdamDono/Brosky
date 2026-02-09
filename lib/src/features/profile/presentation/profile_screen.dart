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
  String? _username;
  String? _email;
  String? _bio;
  List<String> _vibes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Get email from auth
      _email = user.email;

      // Fetch profile data from profiles table
      final response = await Supabase.instance.client
          .from('profiles')
          .select('username, bio, vibes')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _username = response['username'] ?? 'Anonymous';
          _bio = response['bio'] ?? '';
          _vibes = List<String>.from(response['vibes'] ?? []);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

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

  Future<void> _editBio() async {
    final controller = TextEditingController(text: _bio ?? '');
    
    final newBio = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Edit Bio', style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 150,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tell people about yourself...',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF2DD4BF)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2DD4BF),
              foregroundColor: Colors.black,
            ),
            child: Text('Save', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newBio != null && newBio != _bio) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;

        await Supabase.instance.client
            .from('profiles')
            .update({'bio': newBio})
            .eq('id', user.id);

        setState(() => _bio = newBio);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bio updated!'),
              backgroundColor: Color(0xFF2DD4BF),
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating bio: $error'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
    
    controller.dispose();
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
          : SingleChildScrollView(
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
                    _username ?? 'Anonymous',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email ?? '',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_bio == null || _bio!.isEmpty) ? 'No bio yet' : _bio!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white60,
                      height: 1.5,
                    ),
                  ),
                  if (_vibes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _vibes.map((vibe) => Chip(
                        label: Text(vibe, style: const TextStyle(fontSize: 12)),
                        backgroundColor: const Color(0xFF2DD4BF).withOpacity(0.2),
                        labelStyle: const TextStyle(color: Color(0xFF2DD4BF)),
                        side: BorderSide.none,
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
            
            // Edit Profile Button
            OutlinedButton(
              onPressed: _editBio,
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

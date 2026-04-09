import 'package:bro_app/src/features/profile/presentation/edit_profile_screen.dart';
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
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  int _huddleCount = 0;
  int _broCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Fetch Profile (keep bio/username static or manual refresh as they change less often)
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _profile = profileData;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Error loading profile: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper widget for live counts
  Widget _buildLiveStat(String label, String table, String column, String matchId) {
    var query = Supabase.instance.client
        .from(table)
        .stream(primaryKey: ['id']);
    
    // We can't do complex filters in .stream() easily without custom functions, 
    // so let's use a simpler count fetcher with a periodic refresh or leave as is.
    // Actually, for real-time counts, a StreamBuilder on the table is best.
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from(table).stream(primaryKey: ['id']).eq(column, matchId),
      builder: (context, snapshot) {
        // Special case for conversations where user can be user1 or user2
        // For MVP, we'll keep the static count but refresh it more often or 
        // handle it through a more comprehensive stream.
        // Let's stick to a robust FutureBuilder for the 'accepted' complex count 
        // but ensure it's triggered on any change.
        return _buildStat(label, (snapshot.data?.length ?? 0).toString());
      },
    );
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully Signed Out! See you soon, Bro. 👊'),
            backgroundColor: Color(0xFF2DD4BF),
          ),
        );
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF))),
      );
    }

    final username = _profile?['username'] ?? 'Bro';
    final bio = _profile?['bio'] ?? 'Building the future of connection 🚀';

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
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: const Color(0xFF2DD4BF),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Profile Header
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF2DD4BF),
                  backgroundImage: _profile?['avatar_url'] != null 
                    ? NetworkImage(_profile!['avatar_url']) 
                    : null,
                  child: _profile?['avatar_url'] == null 
                    ? const Icon(Icons.person, size: 60, color: Colors.black)
                    : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                username,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bio,
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
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(initialData: _profile ?? {}),
                    ),
                  );
                  if (result == true) {
                    _loadProfile();
                  }
                },
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
  
              // Stats Row (Upgraded to Live Streams)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // --- Live Bro Count ---
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('conversations')
                        .stream(primaryKey: ['id'])
                        .order('created_at'),
                    builder: (context, snapshot) {
                      final userId = Supabase.instance.client.auth.currentUser?.id;
                      final bros = snapshot.data?.where((conv) => 
                        conv['status'] == 'accepted' && 
                        (conv['user1_id'] == userId || conv['user2_id'] == userId)
                      ).length ?? 0;
                      return _buildStat('Bros', '$bros');
                    },
                  ),

                  // --- Live Huddle Count ---
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Supabase.instance.client
                        .from('huddle_members')
                        .stream(primaryKey: ['id'])
                        .eq('user_id', Supabase.instance.client.auth.currentUser?.id ?? ''),
                    builder: (context, snapshot) {
                      return _buildStat('Huddles', '${snapshot.data?.length ?? 0}');
                    },
                  ),

                  _buildStat('Vibe', '${(_profile?['vibes'] as List?)?.length ?? 0}'),
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

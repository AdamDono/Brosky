import 'package:bro_app/src/features/profile/presentation/edit_profile_screen.dart';
import 'package:bro_app/src/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
            backgroundColor: Color(0xFFFFFFFF),
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

  void _showPremiumSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: const Color(0xFF14B8A6).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.workspace_premium, color: Color(0xFF14B8A6), size: 32),
            ),
            const SizedBox(height: 20),
            const Text('Bro Premium', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
            const SizedBox(height: 12),
            const Text(
              'Unlock exclusive features, priority matching, and unlimited Huddle access. Coming soon.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B), height: 1.6),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                child: const Text('Notify Me', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _inviteFriends() {
    const inviteText = 'Join me on Brosky — the app for real ones. Build your squad, find your tribe. Download now! 🔥👊';
    Clipboard.setData(const ClipboardData(text: inviteText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invite link copied! Share it with your Bros. 🔥', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color(0xFF14B8A6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  Future<void> _openSupport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@brosky.app',
      queryParameters: {'subject': 'Help & Support - Brosky App'},
    );
    try {
      await launchUrl(emailUri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email support@brosky.app for help.', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w600, color: Colors.white)),
            backgroundColor: const Color(0xFF14B8A6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
      );
    }

    final username = _profile?['username'] ?? 'Bro';
    final bio = _profile?['bio'] ?? 'Building the future of connection 🚀';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF1E293B)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: const Color(0xFF14B8A6),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Profile Header
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFE2E8F0),
                  backgroundImage: _profile?['avatar_url'] != null 
                    ? NetworkImage(_profile!['avatar_url']) 
                    : null,
                  child: _profile?['avatar_url'] == null 
                    ? const Icon(Icons.person, size: 60, color: Colors.white)
                    : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                username,
                style: TextStyle(fontFamily: '.SF Pro Display', 
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bio,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: '.SF Pro Display', 
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
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
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Edit Profile',
                  style: TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 13),
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
              const Divider(color: Color(0xFFF1F5F9), thickness: 1),
              const SizedBox(height: 16),
  
              // Settings / Menu Items
              _buildMenuItem(Icons.workspace_premium, 'Bro Premium', badge: true, onTap: () => _showPremiumSheet()),
              _buildMenuItem(Icons.share, 'Invite Friends', onTap: () => _inviteFriends()),
              _buildMenuItem(Icons.help_outline, 'Help & Support', onTap: () => _openSupport()),
              
              const SizedBox(height: 24),
              TextButton(
                onPressed: _signOut,
                child: Text(
                  'Sign Out',
                  style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14),
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
          style: TextStyle(fontFamily: '.SF Pro Display', 
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontFamily: '.SF Pro Display', 
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {bool badge = false, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF64748B), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontFamily: '.SF Pro Display', 
          fontSize: 15,
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: badge 
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('PRO', style: TextStyle(color: Colors.white, fontFamily: '.SF Pro Display', fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
            )
          : const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
    );
  }
}

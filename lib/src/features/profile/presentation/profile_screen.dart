import 'package:bro_app/src/features/profile/presentation/edit_profile_screen.dart';
import 'package:bro_app/src/features/profile/presentation/blocked_users_screen.dart';
import 'package:bro_app/src/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bro_app/src/core/theme/theme_provider.dart';
import 'package:bro_app/src/core/theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

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

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully Signed Out! See you soon, Bro. 👊',
              style: TextStyle(
                fontFamily: '.SF Pro Display',
                fontWeight: FontWeight.w600,
                color: context.isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            backgroundColor: context.broColors.card,
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
      backgroundColor: context.broColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.broColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: const Color(0xFF14B8A6).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.workspace_premium, color: Color(0xFF14B8A6), size: 32),
            ),
            const SizedBox(height: 20),
            Text('Bro Premium', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 22, fontWeight: FontWeight.w800, color: context.broColors.text)),
            const SizedBox(height: 12),
            Text(
              'Unlock exclusive features, priority matching, and unlimited Huddle access. Coming soon.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, fontWeight: FontWeight.w500, color: context.broColors.subtext, height: 1.6),
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
      return Scaffold(
        backgroundColor: context.broColors.bg,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
      );
    }

    final username = _profile?['username'] ?? 'Bro';
    final bio = _profile?['bio'] ?? 'Building the future of connection 🚀';

    return Scaffold(
      backgroundColor: context.broColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.broColors.text),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.settings_outlined, color: context.broColors.text),
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
                  backgroundColor: context.broColors.border,
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
                  color: context.broColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bio,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: '.SF Pro Display', 
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.broColors.subtext,
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
                  side: BorderSide(color: context.broColors.border, width: 1.5),
                  backgroundColor: context.broColors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'Edit Profile',
                  style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.text, fontWeight: FontWeight.w600, fontSize: 13),
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
              Divider(color: context.broColors.border, thickness: 1),
              const SizedBox(height: 16),
  
              // Settings / Menu Items
              _buildMenuItem(Icons.workspace_premium, 'Bro Premium', badge: true, onTap: () => _showPremiumSheet()),
              _buildMenuItem(Icons.share, 'Invite Friends', onTap: () => _inviteFriends()),
              _buildMenuItem(Icons.help_outline, 'Help & Support', onTap: () => _openSupport()),
              _buildMenuItem(Icons.block_rounded, 'Blocked Users', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => const BlockedUsersScreen()));
              }),
              _buildThemeToggle(),
              
              const SizedBox(height: 24),
              TextButton(
                onPressed: _signOut,
                child: const Text(
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
            color: context.broColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontFamily: '.SF Pro Display', 
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.broColors.subtext,
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
          color: context.broColors.card,
          border: Border.all(color: context.broColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: context.broColors.subtext, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontFamily: '.SF Pro Display', 
          fontSize: 15,
          color: context.broColors.text,
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
          : Icon(Icons.chevron_right, color: context.broColors.border),
    );
  }

  Widget _buildThemeToggle() {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.broColors.card,
          border: Border.all(color: context.broColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          color: const Color(0xFF14B8A6),
          size: 20,
        ),
      ),
      title: Text(
        'Dark Mode',
        style: TextStyle(
          fontFamily: '.SF Pro Display',
          fontSize: 15,
          color: context.broColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Switch(
        value: isDark,
        onChanged: (value) {
          ref.read(themeProvider.notifier).toggle();
        },
      ),
    );
  }
}

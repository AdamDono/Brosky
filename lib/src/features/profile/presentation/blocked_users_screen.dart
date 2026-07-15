import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:bro_app/src/core/theme/app_theme.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) return;

      final res = await Supabase.instance.client
          .from('user_blocks')
          .select('id, blocked_user_id, profiles!blocked_user_id(username, avatar_url, bio)')
          .eq('blocker_id', myId);

      if (mounted) {
        setState(() {
          _blockedUsers = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading blocked list: $e')),
        );
      }
    }
  }

  Future<void> _unblockUser(String blockId, String username) async {
    try {
      await Supabase.instance.client
          .from('user_blocks')
          .delete()
          .eq('id', blockId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$username unblocked successfully.', style: const TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w600, color: Colors.white)),
            backgroundColor: const Color(0xFF14B8A6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
        _loadBlockedUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unblocking user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.broColors.bg,
      appBar: AppBar(
        title: Text(
          'Blocked Users',
          style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: context.broColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, index) {
                    final item = _blockedUsers[index];
                    final blockId = item['id'].toString();
                    final profile = item['profiles'] as Map<String, dynamic>?;
                    final username = profile?['username'] ?? 'Bro';
                    final avatarUrl = profile?['avatar_url'] as String?;
                    final bio = profile?['bio'] ?? 'Active Bro.';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: context.broColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.broColors.border, width: 1.5),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: context.broColors.border,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? Icon(Icons.person, color: context.broColors.subtext) : null,
                        ),
                        title: Text(
                          username,
                          style: TextStyle(
                            fontFamily: '.SF Pro Display',
                            color: context.broColors.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: '.SF Pro Display',
                            color: context.broColors.subtext,
                            fontSize: 12,
                          ),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () => _unblockUser(blockId, username),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: context.broColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text(
                            'UNBLOCK',
                            style: TextStyle(
                              fontFamily: '.SF Pro Display',
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block_rounded, size: 64, color: context.broColors.border),
          const SizedBox(height: 16),
          Text(
            'No blocked users.',
            style: TextStyle(
              fontFamily: '.SF Pro Display',
              color: context.broColors.subtext,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

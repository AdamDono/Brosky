import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

class SquadRequestsScreen extends StatefulWidget {
  const SquadRequestsScreen({super.key});

  @override
  State<SquadRequestsScreen> createState() => _SquadRequestsScreenState();
}

class _SquadRequestsScreenState extends State<SquadRequestsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  final Color _teal = const Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Step 1: Get pending requests for squads this user CREATED
      // Join with huddles only (that FK exists)
      final res = await Supabase.instance.client
          .from('huddle_join_requests')
          .select('*, huddles(name, creator_id)')
          .eq('status', 'pending');

      // Filter to only squads the current user created
      final filtered = (res as List).where((r) {
        final huddle = r['huddles'];
        return huddle != null && huddle['creator_id'].toString() == user.id;
      }).toList();

      if (filtered.isEmpty) {
        if (mounted) setState(() { _requests = []; _isLoading = false; });
        return;
      }

      // Step 2: Manually fetch profiles for each requester
      final requesterIds = filtered.map((r) => r['user_id'].toString()).toList();
      final profilesRes = await Supabase.instance.client
          .from('profiles')
          .select('id, username, avatar_url')
          .inFilter('id', requesterIds);

      // Build a lookup map: userId -> profile
      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in (profilesRes as List)) {
        profileMap[p['id'].toString()] = Map<String, dynamic>.from(p);
      }

      // Merge profile data into each request
      final enriched = filtered.map((r) {
        final copy = Map<String, dynamic>.from(r);
        copy['profile'] = profileMap[r['user_id'].toString()] ?? {};
        return copy;
      }).toList();

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(enriched);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load squad requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      final huddleId = request['huddle_id'].toString();
      final requestUserId = request['user_id'].toString();
      final requestId = request['id'].toString();

      // 1. Add user to huddle_members
      await Supabase.instance.client.from('huddle_members').insert({
        'huddle_id': huddleId,
        'user_id': requestUserId,
      });

      // 2. Update request status to accepted
      await Supabase.instance.client
          .from('huddle_join_requests')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SQUAD MEMBER ENLISTED. ⚡️')),
        );
        _loadRequests();
      }
    } catch (e) {
      debugPrint('❌ Accept failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    try {
      final requestId = request['id'].toString();

      // Delete the request row entirely
      await Supabase.instance.client
          .from('huddle_join_requests')
          .delete()
          .eq('id', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected.')),
        );
        _loadRequests();
      }
    } catch (e) {
      debugPrint('❌ Reject failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: Color(0xFF1E293B), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text('SQUAD REQUESTS', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B), letterSpacing: 2)),
            Text('Pending Enlistments', style: GoogleFonts.inter(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.w600)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.black.withOpacity(0.04)),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2))
          : _requests.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) => _buildRequestCard(_requests[idx]),
                ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final profile = request['profile'] as Map<String, dynamic>? ?? {};
    final huddle = request['huddles'] as Map<String, dynamic>? ?? {};
    final username = profile?['username'] ?? 'Unknown Bro';
    final avatarUrl = profile?['avatar_url'];
    final squadName = huddle?['name'] ?? 'Unknown Squad';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Squad label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _teal.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, color: Color(0xFF14B8A6), size: 12),
              const SizedBox(width: 6),
              Text(squadName.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _teal, letterSpacing: 1)),
            ]),
          ),
          const SizedBox(height: 16),
          // Requester
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9),
                  image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                ),
                child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Color(0xFFCBD5E1), size: 24) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(username, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                  const SizedBox(height: 2),
                  Text('Wants to join your squad', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _rejectRequest(request),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5)),
                    child: Center(child: Text('REJECT', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black38, letterSpacing: 1.5))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _acceptRequest(request),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text('ACCEPT', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, size: 64, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Text('All Clear.', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Text('No pending squad requests.', style: GoogleFonts.inter(fontSize: 14, color: Colors.black26, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

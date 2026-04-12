import 'package:bro_app/src/core/services/location_service.dart';
import 'package:bro_app/src/features/huddles/presentation/huddle_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

class HuddlesScreen extends StatefulWidget {
  const HuddlesScreen({super.key});

  @override
  State<HuddlesScreen> createState() => _HuddlesScreenState();
}

class _HuddlesScreenState extends State<HuddlesScreen> {
  bool _isLoading = true;
  bool _showJoined = true;
  List<Map<String, dynamic>> _huddles = [];
  String _selectedVibe = 'ALL';
  final Color _teal = const Color(0xFF14B8A6);

  List<String> _myConnections = [];
  List<String> _joinedHuddleIds = [];
  List<String> _pendingRequestHuddleIds = []; // Squads where user sent a join request

  final List<String> _vibes = ['ALL', 'STRATEGY', 'GAINS', 'LIFESTYLE', 'HUSTLE', 'VIBES'];

  @override
  void initState() {
    super.initState();
    _refreshHuddles();
  }

  Future<void> _refreshHuddles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch Social Intel
      final myConsRes = await Supabase.instance.client.from('conversations').select('user1_id, user2_id').or('user1_id.eq.${user.id},user2_id.eq.${user.id}').eq('status', 'accepted');
      _myConnections = (myConsRes as List).map((c) => c['user1_id'] == user.id ? c['user2_id'].toString() : c['user1_id'].toString()).toList();

      // 2. Fetch My Memberships
      final myHuddlesRes = await Supabase.instance.client.from('huddle_members').select('huddle_id').eq('user_id', user.id);
      _joinedHuddleIds = (myHuddlesRes as List).map((h) => h['huddle_id'].toString()).toList();

      // 3. Fetch My Pending Requests
      try {
        final myRequestsRes = await Supabase.instance.client
            .from('huddle_join_requests')
            .select('huddle_id')
            .eq('user_id', user.id)
            .eq('status', 'pending');
        _pendingRequestHuddleIds = (myRequestsRes as List).map((r) => r['huddle_id'].toString()).toList();
      } catch (_) {
        _pendingRequestHuddleIds = []; // Table may not exist yet
      }

      // 3. Fetch All Huddles
      var query = Supabase.instance.client.from('huddles').select('*, huddle_members(count)');
      if (_selectedVibe != 'ALL') { query = query.eq('vibe', _selectedVibe); }

      final response = await query;
      final allHuddles = List<Map<String, dynamic>>.from(response);

      if (mounted) { setState(() { _huddles = allHuddles; _isLoading = false; }); }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1))),
          child: Column(
            children: [
              _buildVibeSelector(),
              _buildTabSwitcher(),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(
          child: _isLoading && _huddles.isEmpty
              ? _buildLoadingState()
              : _huddles.isEmpty 
                  ? _buildEmptyState() 
                  : Builder(
                      builder: (ctx) {
                        final myHuddles = _huddles.where((h) => _joinedHuddleIds.contains(h['id'].toString())).toList();
                        final globalHuddles = _huddles.where((h) => !_joinedHuddleIds.contains(h['id'].toString())).toList();
                        final targetList = _showJoined ? myHuddles : globalHuddles;

                        if (targetList.isEmpty) {
                           return Center(child: Padding(
                             padding: const EdgeInsets.all(40.0),
                             child: Text(_showJoined ? 'You have not joined any squads yet.' : 'No new squads to discover.', textAlign: TextAlign.center, style: const TextStyle(fontFamily: '.SF Pro Display', color: Colors.black38, fontWeight: FontWeight.w500, fontSize: 13)),
                           ));
                        }

                        return ListView.builder(
                          padding: EdgeInsets.zero, 
                          physics: const BouncingScrollPhysics(), 
                          itemCount: targetList.length,
                          itemBuilder: (context, index) => _buildHuddleCard(targetList[index])
                        );
                      }
                    ),
        ),
      ],
    );
  }

  Widget _buildVibeSelector() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: _vibes.length,
        itemBuilder: (context, index) {
          final vibe = _vibes[index];
          final isSelected = _selectedVibe == vibe;
          return GestureDetector(
            onTap: () { setState(() => _selectedVibe = vibe); _refreshHuddles(); },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: isSelected ? _teal : Colors.transparent, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? _teal : const Color(0xFFF1F5F9), width: 1.5)),
              child: Text(vibe == 'ALL' ? 'ALL' : '#$vibe', style: TextStyle(fontFamily: '.SF Pro Display', color: isSelected ? Colors.white : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showJoined = true),
                child: Container(
                  decoration: BoxDecoration(
                    color: _showJoined ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _showJoined ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : [],
                  ),
                  alignment: Alignment.center,
                  child: Text('JOINED', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 12, fontWeight: _showJoined ? FontWeight.w800 : FontWeight.w600, color: _showJoined ? const Color(0xFF1E293B) : const Color(0xFF94A3B8))),
                )
              )
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showJoined = false),
                child: Container(
                  decoration: BoxDecoration(
                    color: !_showJoined ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: !_showJoined ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : [],
                  ),
                  alignment: Alignment.center,
                  child: Text('DISCOVER', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 12, fontWeight: !_showJoined ? FontWeight.w800 : FontWeight.w600, color: !_showJoined ? const Color(0xFF1E293B) : const Color(0xFF94A3B8))),
                )
              )
            ),
          ]
        )
      )
    );
  }

  Widget _buildHuddleCard(Map<String, dynamic> huddle) {
    final name = huddle['name'] ?? 'Squad';
    final bio = huddle['description'] ?? 'Building the next big thing. Strategy and Hustle only.';
    final isPublic = huddle['is_public'] ?? true;
    final huddleId = huddle['id'].toString();
    final isJoined = _joinedHuddleIds.contains(huddleId);
    final hasPendingRequest = _pendingRequestHuddleIds.contains(huddleId);
    
    int memberCount = 0;
    if (huddle['huddle_members'] != null && (huddle['huddle_members'] as List).isNotEmpty) { memberCount = huddle['huddle_members'][0]['count'] ?? 0; }

    return FutureBuilder<int>(
      future: _getMutualCount(huddleId),
      builder: (context, snapshot) {
        final mutualCount = snapshot.data ?? 0;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 56, height: 56, decoration: BoxDecoration(color: _teal.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: _teal.withOpacity(0.1), width: 1)), child: Center(child: Text(name.substring(0, 1).toUpperCase(), style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 22, fontWeight: FontWeight.w700, color: _teal)))),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(name, style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF1E293B))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: isPublic ? _teal.withOpacity(0.1) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                              child: Text(isPublic ? 'OPEN' : 'RESTRICTED', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 9, fontWeight: FontWeight.w700, color: isPublic ? _teal : Colors.black38, letterSpacing: 0.3)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (mutualCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _teal.withOpacity(0.06), borderRadius: BorderRadius.circular(6), border: Border.all(color: _teal.withOpacity(0.12), width: 1)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [const HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, color: Color(0xFF14B8A6), size: 10), const SizedBox(width: 4), Text('$mutualCount BROS IN SQUAD', style: TextStyle(fontFamily: '.SF Pro Display', color: _teal, fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 0.3))]),
                            ),
                          ),
                        Text(bio, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 13, color: const Color(0xFF64748B), height: 1.4)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(10)), child: Row(children: [const HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, color: Color(0xFF64748B), size: 14), const SizedBox(width: 6), Text('$memberCount TOTAL', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.3))])),
                            const Spacer(),
                            GestureDetector(
                                onTap: () {
                                  if (isPublic || isJoined) {
                                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => HuddleChatScreen(huddleId: huddle['id'], huddleName: huddle['name'])));
                                  } else if (!hasPendingRequest) {
                                    _requestAccess(huddleId, name);
                                  }
                                  // If hasPendingRequest: do nothing, button is disabled
                                }, 
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
                                  decoration: BoxDecoration(
                                    color: (isPublic || isJoined)
                                        ? Colors.white
                                        : hasPendingRequest
                                            ? const Color(0xFFF1F5F9) // grayed
                                            : _teal,
                                    borderRadius: BorderRadius.circular(16), 
                                    border: Border.all(
                                      color: (isPublic || isJoined)
                                          ? const Color(0xFFF1F5F9)
                                          : hasPendingRequest
                                              ? const Color(0xFFE2E8F0)
                                              : _teal,
                                      width: 1.5,
                                    ),
                                  ), 
                                  child: Row(
                                    children: [
                                      Text(
                                        (isPublic || isJoined)
                                            ? 'ENTER'
                                            : hasPendingRequest
                                                ? 'REQUESTED'
                                                : 'REQUEST', 
                                        style: TextStyle(fontFamily: '.SF Pro Display', 
                                          color: (isPublic || isJoined)
                                              ? const Color(0xFF1E293B)
                                              : hasPendingRequest
                                                  ? Colors.black26
                                                  : Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 1.5,
                                        ),
                                      ), 
                                      if (!hasPendingRequest) ...[
                                        const SizedBox(width: 8), 
                                        HugeIcon(
                                          icon: (isPublic || isJoined)
                                              ? HugeIcons.strokeRoundedArrowRight01
                                              : HugeIcons.strokeRoundedLockPassword, 
                                          color: (isPublic || isJoined)
                                              ? const Color(0xFF1E293B)
                                              : Colors.white, 
                                          size: 14,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          ],
        );
      }
    );
  }

  Future<void> _requestAccess(String huddleId, String name) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('huddle_join_requests').insert({
        'huddle_id': huddleId,
        'user_id': user.id,
        'status': 'pending',
      });
      // Immediately reflect pending state in UI
      setState(() => _pendingRequestHuddleIds.add(huddleId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Access requested for $name squad. 🛰️ The creator will be notified.')));
    } catch (e) {
      debugPrint('❌ Request failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request failed: $e')));
    }
  }

  Future<int> _getMutualCount(String huddleId) async {
    try {
      final membersRes = await Supabase.instance.client.from('huddle_members').select('user_id').eq('huddle_id', huddleId);
      final memberIds = (membersRes as List).map((m) => m['user_id'].toString()).toList();
      int mutualCount = 0;
      for (var id in memberIds) { if (_myConnections.contains(id)) mutualCount++; }
      return mutualCount;
    } catch (e) { return 0; }
  }

  Widget _buildLoadingState() { return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: _teal, strokeWidth: 2), const SizedBox(height: 24), Text('INITIALIZING BROHOOD...', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 11))])); }
  Widget _buildEmptyState() { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, size: 64, color: Color(0xFFF1F5F9)), const SizedBox(height: 16), Text('No Huddles found in this vibe.', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w600))])); }
}

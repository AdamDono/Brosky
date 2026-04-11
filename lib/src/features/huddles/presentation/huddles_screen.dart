import 'package:bro_app/src/core/services/location_service.dart';
import 'package:bro_app/src/features/huddles/presentation/create_huddle_modal.dart';
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
  List<Map<String, dynamic>> _huddles = [];
  String _selectedVibe = 'ALL';
  final Color _teal = const Color(0xFF14B8A6);

  // Social Cache for Intel
  List<String> _myConnections = [];

  final List<String> _vibes = [
    'ALL',
    'STRATEGY',
    'GAINS',
    'LIFESTYLE',
    'HUSTLE',
    'VIBES',
  ];

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
      // 1. Fetch My Connections for Mutual Intel
      final myConsRes = await Supabase.instance.client
          .from('conversations')
          .select('user1_id, user2_id')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}')
          .eq('status', 'accepted');
      
      _myConnections = (myConsRes as List).map((c) {
        return c['user1_id'] == user.id ? c['user2_id'].toString() : c['user1_id'].toString();
      }).toList();

      // 2. Fetch Huddles with filters
      var query = Supabase.instance.client.from('huddles').select('*, huddle_members(count)');
      
      if (_selectedVibe != 'ALL') {
        // Assuming huddles have a 'category' or tags field. 
        // If not, we'll just show all for now or filter by name match.
        // For now, let's assume 'category' exists or it's a future schema update.
      }

      final response = await query;
      final allHuddles = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _huddles = allHuddles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- ARCTIC HUB HEADER ---
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
          ),
          child: Column(
            children: [
              _buildVibeSelector(),
              _buildSortBar(),
            ],
          ),
        ),

        // --- HUDDLE STREAM ---
        Expanded(
          child: _isLoading && _huddles.isEmpty
              ? _buildLoadingState()
              : _huddles.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _huddles.length,
                      itemBuilder: (ctx, idx) => _buildHuddleCard(_huddles[idx]),
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
            onTap: () {
              setState(() => _selectedVibe = vibe);
              _refreshHuddles();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? _teal : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _teal : const Color(0xFFF1F5F9),
                  width: 1.5
                ),
              ),
              child: Text(
                vibe == 'ALL' ? 'ALL' : '#$vibe',
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.02), width: 1)),
      ),
      child: Row(
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedChampion, color: Colors.black26, size: 14),
          const SizedBox(width: 8),
          Text('COMMUNITY EXPLORER', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _teal, strokeWidth: 2),
          const SizedBox(height: 24),
          Text('INITIALIZING BROHOOD...', style: GoogleFonts.poppins(color: Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, size: 64, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Text('No Huddles found in this vibe.', style: GoogleFonts.inter(color: Colors.black26, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildHuddleCard(Map<String, dynamic> huddle) {
    final huddleId = huddle['id'].toString();
    final name = huddle['name'] ?? 'Squad';
    final bio = huddle['description'] ?? 'Building the next big thing. Strategy and Hustle only.';
    
    int memberCount = 0;
    if (huddle['huddle_members'] != null && (huddle['huddle_members'] as List).isNotEmpty) {
      memberCount = huddle['huddle_members'][0]['count'] ?? 0;
    }

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
                  // --- SQUAD SIGNATURE ---
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _teal.withOpacity(0.1), width: 1),
                    ),
                    child: Center(
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w900, color: _teal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // --- SQUAD INTEL ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 17, color: const Color(0xFF1E293B))),
                        const SizedBox(height: 6),
                        
                        // Mutual Intel Badge
                        if (mutualCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _teal.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _teal.withOpacity(0.12), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, color: Color(0xFF14B8A6), size: 10),
                                  const SizedBox(width: 4),
                                  Text('$mutualCount BROS IN SQUAD', style: GoogleFonts.inter(color: _teal, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                          ),

                        Text(
                          bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            // Member Count Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const HugeIcon(icon: HugeIcons.strokeRoundedUserGroup, color: Color(0xFF64748B), size: 14),
                                  const SizedBox(width: 6),
                                  Text('$memberCount TOTAL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Action Button
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (ctx) => HuddleChatScreen(huddleId: huddle['id'], huddleName: huddle['name'])));
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5)
                                ),
                                child: Row(
                                  children: [
                                    Text('ENTER', style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                                    const SizedBox(width: 8),
                                    const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Color(0xFF1E293B), size: 14),
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

  Future<int> _getMutualCount(String huddleId) async {
    try {
      final membersRes = await Supabase.instance.client
          .from('huddle_members')
          .select('user_id')
          .eq('huddle_id', huddleId);
      
      final memberIds = (membersRes as List).map((m) => m['user_id'].toString()).toList();
      
      int mutualCount = 0;
      for (var id in memberIds) {
        if (_myConnections.contains(id)) mutualCount++;
      }
      return mutualCount;
    } catch (e) {
      return 0;
    }
  }
}

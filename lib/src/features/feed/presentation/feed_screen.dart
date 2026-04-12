import 'dart:async';
import 'package:bro_app/src/features/feed/presentation/widgets/bro_post_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Timer _refreshTimer;
  String _selectedVibe = 'ALL';

  final List<String> _vibes = ['ALL', 'STRATEGY', 'GAINS', 'HUSTLE', 'LIFESTYLE', 'VIBES'];

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cutOff = DateTime.now().subtract(const Duration(hours: 24));

    return Column(
      children: [
        // --- TACTICAL COMMAND CENTER ---
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
          ),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (val) => setState(() {}),
                    style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w500, color: const Color(0xFF1A1D21), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search the Brohood',
                      hintStyle: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w400),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, color: Color(0xFF64748B), size: 18),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              
              // Tactical Vibe Selector
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _vibes.length,
                  itemBuilder: (context, index) {
                    final vibe = _vibes[index];
                    final isSelected = _selectedVibe == vibe;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedVibe = vibe),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF14B8A6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF14B8A6) : const Color(0xFFF1F5F9),
                            width: 1.5
                          ),
                        ),
                        child: Text(
                          vibe == 'ALL' ? 'ALL' : '#$vibe',
                          style: TextStyle(fontFamily: '.SF Pro Display', 
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),

        // --- EPHEMERAL STREAM ---
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client
                .from('bro_posts')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6), strokeWidth: 2));
              }
              
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('The barbershop is empty, Bro.', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black26)));
              }

              // --- SURGICAL FILTERING (24H + SEARCH + VIBE) ---
              final allPosts = snapshot.data!;
              final validPosts = allPosts.where((post) {
                final createdAt = DateTime.parse(post['created_at']);
                final content = (post['content'] ?? '').toString().toUpperCase();
                final searchQuery = _searchController.text.toUpperCase();
                
                final isWithin24h = createdAt.isAfter(cutOff);
                final matchesSearch = searchQuery.isEmpty || content.contains(searchQuery);
                final matchesVibe = _selectedVibe == 'ALL' || content.contains(_selectedVibe);

                return isWithin24h && matchesSearch && matchesVibe;
              }).toList();

              if (validPosts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text(
                      _selectedVibe == 'ALL' 
                        ? 'The stream has evaporated. Start a new one.' 
                        : 'No posts found in #$_selectedVibe', 
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black38, fontWeight: FontWeight.w500, fontSize: 13)
                    ),
                  )
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: validPosts.length,
                itemBuilder: (context, index) => BroPostCard(post: validPosts[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

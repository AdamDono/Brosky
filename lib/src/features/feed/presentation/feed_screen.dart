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

  @override
  void initState() {
    super.initState();
    // Refresh the UI every minute to ensure posts over 24h evaporate live
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
    // Current 24-hour cut-off
    final cutOff = DateTime.now().subtract(const Duration(hours: 24));

    return Column(
      children: [
        // --- FLAT INTEGRATED SEARCH ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
          ),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(22),
            ),
            child: TextField(
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: const Color(0xFF1A1D21), fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search the Brohood',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 15, fontWeight: FontWeight.w400),
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

        // --- EPHEMERAL STREAM (24H WINDOW) ---
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
                return Center(child: Text('The barbershop is empty, Bro.', style: GoogleFonts.inter(color: Colors.black26)));
              }

              // --- SURGICAL 24H FILTERING ---
              final allPosts = snapshot.data!;
              final validPosts = allPosts.where((post) {
                final createdAt = DateTime.parse(post['created_at']);
                return createdAt.isAfter(cutOff);
              }).toList();

              if (validPosts.isEmpty) {
                return Center(child: Text('Conversations have vanished. Start a new one.', style: GoogleFonts.inter(color: Colors.black26)));
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

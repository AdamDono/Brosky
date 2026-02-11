import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  double _searchRadius = 25.0; // km
  bool _isLoading = true;
  List<Map<String, dynamic>> _nearbyBros = [];

  @override
  void initState() {
    super.initState();
    _fetchNearbyBros();
  }

  Future<void> _fetchNearbyBros() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Fetch all profiles that aren't me
      // Note: In a real app, we'd use a PostGIS query in Supabase to only fetch within radius.
      // For now, we fetch and show how we'll sort them.
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .neq('id', user.id);

      setState(() {
        _nearbyBros = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching bros: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Bro Radar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchNearbyBros,
            icon: const Icon(Icons.radar, color: Color(0xFF2DD4BF)),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Distance Slider Section ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SEARCH RADIUS',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${_searchRadius.round()} km',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2DD4BF),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF2DD4BF),
                    inactiveTrackColor: Colors.white10,
                    thumbColor: const Color(0xFF2DD4BF),
                    overlayColor: const Color(0xFF2DD4BF).withOpacity(0.2),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _searchRadius,
                    min: 5,
                    max: 500,
                    onChanged: (val) {
                      setState(() => _searchRadius = val);
                    },
                    onChangeEnd: (val) {
                      _fetchNearbyBros();
                    },
                  ),
                ),
              ],
            ),
          ),

          // --- Bros List ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
                : _nearbyBros.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _nearbyBros.length,
                        itemBuilder: (context, index) {
                          final bro = _nearbyBros[index];
                          return _buildBroCard(bro);
                        },
                      ),
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
          const Icon(Icons.explore_outlined, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(
            'No bros found in this radius.\nExpand your search, Bro.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildBroCard(Map<String, dynamic> bro) {
    final avatarUrl = bro['avatar_url'];
    final username = bro['username'] ?? 'Bro';
    final vibes = List<String>.from(bro['vibes'] ?? []);
    // Mocked distance for UI demo
    final mockDistance = (bro['username']?.length ?? 5) * 1.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF2DD4BF),
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null ? const Icon(Icons.person, color: Colors.black) : null,
        ),
        title: Row(
          children: [
            Text(
              username,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Spacer(),
            Text(
              '${mockDistance.toStringAsFixed(1)}km',
              style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              bro['bio'] ?? 'No bio yet...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (vibes.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: vibes.take(3).map((vibe) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      vibe,
                      style: const TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  )).toList(),
                ),
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PublicProfileScreen(userId: bro['id'])),
          );
        },
      ),
    );
  }
}

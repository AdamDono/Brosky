import 'package:bro_app/src/core/services/location_service.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _refreshRadar();
  }

  Future<void> _refreshRadar() async {
    setState(() => _isLoading = true);
    
    // 1. Get my current real-world location
    _myPosition = await LocationService.updateLocation();
    
    // 2. Fetch all other bros from Supabase
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .neq('id', user.id);

      final allBros = List<Map<String, dynamic>>.from(response);
      
      // 3. Filter and calculate real distance
      List<Map<String, dynamic>> filteredBros = [];
      
      if (_myPosition != null) {
        for (var bro in allBros) {
          if (bro['last_lat'] != null && bro['last_long'] != null) {
            double distance = LocationService.calculateDistance(
              _myPosition!.latitude, 
              _myPosition!.longitude, 
              bro['last_lat'], 
              bro['last_long']
            );
            
            if (distance <= _searchRadius) {
              bro['real_distance'] = distance;
              filteredBros.add(bro);
            }
          }
        }
        // Sort by closest first
        filteredBros.sort((a, b) => (a['real_distance'] as double).compareTo(b['real_distance'] as double));
      }

      setState(() {
        _nearbyBros = filteredBros;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching bros: $e');
      setState(() => _nearbyBros = []);
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
            onPressed: _refreshRadar,
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
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _searchRadius,
                    min: 1,
                    max: 100,
                    onChanged: (val) {
                      setState(() => _searchRadius = val);
                    },
                    onChangeEnd: (val) {
                      _refreshRadar();
                    },
                  ),
                ),
                if (_myPosition == null && !_isLoading)
                   const Padding(
                     padding: EdgeInsets.only(top: 8.0),
                     child: Text(
                       '⚠️ Location disabled. Please enable GPS for radar.',
                       style: TextStyle(color: Colors.orangeAccent, fontSize: 10),
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
          Icon(
            _myPosition == null ? Icons.location_off_outlined : Icons.explore_outlined, 
            size: 64, 
            color: Colors.white10
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _myPosition == null 
                ? 'Bro, we need your GPS Signal. 🛰️\n1. Use http://localhost:8080\n2. Hit "Allow" on the popup.'
                : 'No huddles in this radius yet.\nExpand your search or start one!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14, height: 1.5),
            ),
          ),
          if (_myPosition == null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: TextButton.icon(
                onPressed: _refreshRadar,
                icon: const Icon(Icons.refresh, color: Color(0xFF2DD4BF)),
                label: const Text('RETRY RADAR', style: TextStyle(color: Color(0xFF2DD4BF))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBroCard(Map<String, dynamic> bro) {
    final avatarUrl = bro['avatar_url'];
    final username = bro['username'] ?? 'Bro';
    final vibes = List<String>.from(bro['vibes'] ?? []);
    final distance = bro['real_distance'] as double? ?? 0.0;

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
              distance < 1.0 
                ? '${(distance * 1000).round()}m' 
                : '${distance.toStringAsFixed(1)}km',
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

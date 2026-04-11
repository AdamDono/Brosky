import 'package:bro_app/src/core/services/location_service.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

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
  String _selectedVibe = 'ALL';
  final Color _teal = const Color(0xFF14B8A6);

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
    _refreshRadar();
  }

  Future<void> _refreshRadar() async {
    setState(() => _isLoading = true);
    _myPosition = await LocationService.updateLocation();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      var query = Supabase.instance.client.from('profiles').select().neq('id', user.id);
      
      // If filtering by vibe, we check if the vibes array contains the selected vibe
      if (_selectedVibe != 'ALL') {
        // Assuming 'vibes' is a list of strings in the profile table
        query = query.contains('vibes', [_selectedVibe]);
      }

      final response = await query;
      final allBros = List<Map<String, dynamic>>.from(response);
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
        filteredBros.sort((a, b) => (a['real_distance'] as double).compareTo(b['real_distance'] as double));
      }

      if (mounted) {
        setState(() {
          _nearbyBros = filteredBros;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching bros: $e');
      if (mounted) {
        setState(() {
          _nearbyBros = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- TACTICAL DISCOVERY COMMAND CENTER ---
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
          ),
          child: Column(
            children: [
              // Vibe Selector
              SizedBox(
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
                        _refreshRadar();
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
              ),
              
              // Search Radius Control
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DISCOVERY RADIUS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1.5)),
                        Text('${_searchRadius.round()} KM', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: _teal)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _teal,
                        inactiveTrackColor: const Color(0xFFF1F5F9),
                        thumbColor: Colors.white,
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
                        overlayColor: _teal.withOpacity(0.1),
                      ),
                      child: Slider(
                        value: _searchRadius,
                        min: 1, max: 100,
                        onChanged: (val) => setState(() => _searchRadius = val),
                        onChangeEnd: (val) => _refreshRadar(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- DISCOVERY STREAM ---
        Expanded(
          child: _isLoading
              ? _buildPulsingRadar()
              : _nearbyBros.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _nearbyBros.length,
                      itemBuilder: (context, index) => _buildDiscoveryCard(_nearbyBros[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildPulsingRadar() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingRing(color: _teal),
          const SizedBox(height: 32),
          Text(
            'PINGING THE BROHOOD...',
            style: GoogleFonts.poppins(
              color: Colors.black26,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              fontSize: 11
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
          HugeIcon(
            icon: _myPosition == null ? HugeIcons.strokeRoundedLocation01 : HugeIcons.strokeRoundedRadar01, 
            size: 64, 
            color: const Color(0xFFF1F5F9)
          ),
          const SizedBox(height: 24),
          Text(
            _myPosition == null ? 'GPS SIGNAL REQUIRED 🛰️' : 'THE RADIUS IS QUIET, BRO.',
            style: GoogleFonts.inter(color: Colors.black26, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            'Try expanding your discovery window.',
            style: GoogleFonts.inter(color: Colors.black12, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryCard(Map<String, dynamic> bro) {
    final avatarUrl = bro['avatar_url'];
    final username = bro['username'] ?? 'Bro';
    final distance = (bro['real_distance'] as double).toStringAsFixed(1);
    final vibes = List<String>.from(bro['vibes'] ?? []);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- LATERAL AVATAR ---
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: bro['id']))),
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF1F5F9),
                    image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                  ),
                  child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Color(0xFFCBD5E1), size: 32) : null,
                ),
              ),
              const SizedBox(width: 20),
              
              // --- DISCOVERY INTEL ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(username, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF1E293B))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                          child: Text('$distance KM', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: _teal, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bro['bio'] ?? 'This bro is silent but steady. Ready to build.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    
                    // Vibes Row
                    if (vibes.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: vibes.take(3).map((v) => Text('#$v', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _teal.withOpacity(0.6)))).toList(),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // Connect Action
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: bro['id']))),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('CONNECT', style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                            const SizedBox(width: 8),
                            const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: Color(0xFF1E293B), size: 14),
                          ],
                        ),
                      ),
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
}

class _PulsingRing extends StatefulWidget {
  final Color color;
  const _PulsingRing({required this.color});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120 * _controller.value,
              height: 120 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: widget.color.withOpacity(1 - _controller.value), width: 3),
              ),
            ),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)]),
            ),
          ],
        );
      },
    );
  }
}

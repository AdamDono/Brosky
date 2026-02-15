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
  String _selectedVibe = 'All';

  final List<String> _vibes = [
    'All',
    'Sports & Fitness',
    'Gaming & Culture',
    'Life & Real Talk',
    'Business & Hustle',
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
      if (_selectedVibe != 'All') {
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

      setState(() {
        _nearbyBros = filteredBros;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching bros: $e');
      setState(() {
        _nearbyBros = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _vibes.length,
            itemBuilder: (context, index) {
              final vibe = _vibes[index];
              final isSelected = _selectedVibe == vibe;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(vibe, style: GoogleFonts.outfit(
                    color: isSelected ? Colors.black : Colors.white60,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
                  backgroundColor: const Color(0xFF1E293B),
                  selectedColor: const Color(0xFF2DD4BF),
                  checkmarkColor: Colors.black,
                  onSelected: (selected) {
                    setState(() => _selectedVibe = vibe);
                    _refreshRadar();
                  },
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
        ),
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
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? _buildPulsingRadar()
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
    );
  }

  Widget _buildPulsingRadar() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingRing(color: Color(0xFF2DD4BF)),
          const SizedBox(height: 24),
          Text(
            'SCANNING FOR BROS...',
            style: GoogleFonts.outfit(
              color: const Color(0xFF2DD4BF),
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 12
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
          Text(
            _myPosition == null ? 'GPS Signal Required 🛰️' : 'No bros in range yet.',
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBroCard(Map<String, dynamic> bro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF2DD4BF),
          backgroundImage: bro['avatar_url'] != null ? NetworkImage(bro['avatar_url']) : null,
          child: bro['avatar_url'] == null ? const Icon(Icons.person, color: Colors.black) : null,
        ),
        title: Text(bro['username'] ?? 'Bro', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text('Distance: ${(bro['real_distance'] as double).toStringAsFixed(1)}km', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfileScreen(userId: bro['id'])));
        },
      ),
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
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 100 * _controller.value,
          height: 100 * _controller.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.color.withOpacity(1 - _controller.value), width: 2),
          ),
        );
      },
    );
  }
}

import 'package:bro_app/src/core/services/location_service.dart';
import 'package:bro_app/src/features/huddles/presentation/create_huddle_modal.dart';
import 'package:bro_app/src/features/huddles/presentation/huddle_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HuddlesScreen extends StatefulWidget {
  const HuddlesScreen({super.key});

  @override
  State<HuddlesScreen> createState() => _HuddlesScreenState();
}

class _HuddlesScreenState extends State<HuddlesScreen> {
  double _selectedRadius = 50.0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _nearbyHuddles = [];
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _refreshHuddles();
  }

  Future<void> _refreshHuddles() async {
    setState(() => _isLoading = true);
    _myPosition = await LocationService.updateLocation();
    try {
      final response = await Supabase.instance.client.from('huddles').select('*, huddle_members(count)');
      final allHuddles = List<Map<String, dynamic>>.from(response);
      List<Map<String, dynamic>> filtered = [];
      
      if (_myPosition != null) {
        for (var huddle in allHuddles) {
          double dist = LocationService.calculateDistance(_myPosition!.latitude, _myPosition!.longitude, huddle['lat'], huddle['long']);
          if (dist <= _selectedRadius) {
            huddle['distance'] = dist;
            filtered.add(huddle);
          }
        }
        filtered.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      } else {
        filtered = allHuddles;
      }

      setState(() { _nearbyHuddles = filtered; _isLoading = false; });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRadiusSelector(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          width: double.infinity,
          color: const Color(0xFF1E293B).withOpacity(0.5),
          child: Row(
            children: [
              const Icon(Icons.sort, color: Color(0xFF2DD4BF), size: 16),
              const SizedBox(width: 8),
              Text('SORTED BY PROXIMITY', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF2DD4BF), letterSpacing: 1.5)),
            ],
          ),
        ),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)))
            : _nearbyHuddles.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _nearbyHuddles.length,
                  itemBuilder: (ctx, idx) => _buildHuddleCard(_nearbyHuddles[idx]),
                ),
        ),
      ],
    );
  }

  Widget _buildRadiusSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SEARCH RADIUS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.5)),
              Text('${_selectedRadius.round()} km', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2DD4BF))),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: const Color(0xFF2DD4BF), inactiveTrackColor: Colors.white10, thumbColor: const Color(0xFF2DD4BF), trackHeight: 2),
            child: Slider(
              value: _selectedRadius,
              min: 5,
              max: 500,
              onChanged: (val) => setState(() => _selectedRadius = val),
              onChangeEnd: (val) => _refreshHuddles(),
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
          const Icon(Icons.groups_outlined, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text('No Huddles nearby yet.', style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildHuddleCard(Map<String, dynamic> huddle) {
    final distance = huddle['distance'] as double? ?? 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        title: Text(huddle['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text('${distance.toStringAsFixed(1)}km away', style: const TextStyle(color: Colors.white38)),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => HuddleChatScreen(huddleId: huddle['id'], huddleName: huddle['name'])));
        },
      ),
    );
  }
}

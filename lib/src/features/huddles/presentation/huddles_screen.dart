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
  double _radius = 25.0;
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
    
    // 1. Get my position
    _myPosition = await LocationService.updateLocation();
    
    try {
      // 2. Fetch all huddles
      final response = await Supabase.instance.client
          .from('huddles')
          .select('*, huddle_members(count)');

      final allHuddles = List<Map<String, dynamic>>.from(response);
      List<Map<String, dynamic>> filtered = [];

      // 3. Sort by Distance (Show all, closest first)
      if (_myPosition != null) {
        for (var huddle in allHuddles) {
          huddle['distance'] = LocationService.calculateDistance(
            _myPosition!.latitude, 
            _myPosition!.longitude, 
            huddle['lat'], 
            huddle['long']
          );
        }
        allHuddles.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      } else {
        // If no location, sort by newest
        allHuddles.sort((a, b) => b['created_at'].compareTo(a['created_at']));
      }

      setState(() {
        _nearbyHuddles = allHuddles;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CreateHuddleModal(),
    ).then((_) => _refreshHuddles());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Brotherhood Huddles', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshHuddles, 
            icon: Icon(Icons.refresh, color: _isLoading ? Colors.white38 : const Color(0xFF2DD4BF))
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Info Header (Replaces Slider) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            width: double.infinity,
            color: const Color(0xFF1E293B).withOpacity(0.5),
            child: Row(
              children: [
                const Icon(Icons.sort, color: Color(0xFF2DD4BF), size: 16),
                const SizedBox(width: 8),
                Text(
                  'SORTED BY PROXIMITY',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2DD4BF),
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                const Text(
                  'GLOBAL',
                  style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateModal,
        backgroundColor: const Color(0xFF2DD4BF),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('START HUDDLE', style: TextStyle(fontWeight: FontWeight.bold)),
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
          Text(
            'No Huddles in this radius yet.\nExpand your search or start one!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHuddleCard(Map<String, dynamic> huddle) {
    final memberCount = (huddle['huddle_members'] as List?)?.length ?? 1;
    final distance = huddle['distance'] as double? ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Row(
          children: [
            Text(huddle['name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF2DD4BF).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(huddle['vibe'], style: const TextStyle(color: Color(0xFF2DD4BF), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text('$memberCount Bros', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 16),
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text('${distance.toStringAsFixed(1)}km away', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => HuddleChatScreen(
                huddleId: huddle['id'],
                huddleName: huddle['name'],
              ),
            ),
          );
        },
      ),
    );
  }
}

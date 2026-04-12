import 'dart:async';
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

  // Social Intel Cache
  List<String> _myConnections = [];
  List<String> _myHuddles = [];

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    _myPosition = await LocationService.updateLocation();
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final myConsRes = await Supabase.instance.client
          .from('conversations')
          .select('user1_id, user2_id')
          .or('user1_id.eq.${user.id},user2_id.eq.${user.id}')
          .eq('status', 'accepted');
      _myConnections = (myConsRes as List).map((c) => c['user1_id'] == user.id ? c['user2_id'].toString() : c['user1_id'].toString()).toList();

      final myHuddlesRes = await Supabase.instance.client
          .from('huddle_members')
          .select('huddle_id')
          .eq('user_id', user.id);
      _myHuddles = (myHuddlesRes as List).map((h) => h['huddle_id'].toString()).toList();

      var query = Supabase.instance.client.from('profiles').select().neq('id', user.id);
      
      if (_selectedVibe != 'ALL') {
        query = query.contains('vibes', [_selectedVibe]);
      }

      final response = await query;
      final allBros = List<Map<String, dynamic>>.from(response);
      List<Map<String, dynamic>> filteredBros = [];
      
      for (var bro in allBros) {
        if (_myPosition != null && bro['last_lat'] != null && bro['last_long'] != null) {
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
        } else if (_myPosition == null) {
          bro['real_distance'] = 0.0;
          filteredBros.add(bro);
        }
      }
      
      filteredBros.sort((a, b) => (a['real_distance'] as double).compareTo(b['real_distance'] as double));

      if (mounted) {
        setState(() {
          _nearbyBros = filteredBros;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
          ),
          child: Column(
            children: [
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
                          border: Border.all(color: isSelected ? _teal : const Color(0xFFF1F5F9), width: 1.5),
                        ),
                        child: Text(
                          vibe == 'ALL' ? 'ALL' : '#$vibe',
                          style: TextStyle(fontFamily: '.SF Pro Display', 
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DISCOVERY RADIUS', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1.5)),
                        Text('${_searchRadius.round()} KM', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, fontWeight: FontWeight.w900, color: _teal)),
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
        Expanded(
          child: _isLoading && _nearbyBros.isEmpty
              ? _buildPulsingRadar()
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

  Widget _buildDiscoveryCard(Map<String, dynamic> bro) {
    final broId = bro['id'].toString();
    final avatarUrl = bro['avatar_url'];
    final username = bro['username'] ?? 'Bro';
    final distVal = (bro['real_distance'] as double);
    final distance = distVal == 0.0 ? 'LOCAL' : '${distVal.toStringAsFixed(1)} KM';
    
    bool isOnline = false;
    if (bro['updated_at'] != null) {
      final lastActive = DateTime.parse(bro['updated_at']);
      final nowUtc = DateTime.now().toUtc();
      isOnline = nowUtc.difference(lastActive).inMinutes < 15;
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadMutualIntel(broId),
      builder: (context, snapshot) {
        final mutualBros = snapshot.data?['mutualBros'] ?? 0;
        final hasSharedHuddle = snapshot.data?['sharedHuddle'] ?? false;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: broId))),
                    child: Stack(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                            image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                          ),
                          child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Color(0xFFCBD5E1), size: 32) : null,
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 2, right: 2,
                            child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(
                                color: _teal,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [BoxShadow(color: _teal.withOpacity(0.4), blurRadius: 6, spreadRadius: 2)],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(username, style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF1E293B))),
                                if (isOnline) ...[
                                  const SizedBox(width: 8),
                                  Text('ONLINE', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 9, fontWeight: FontWeight.w900, color: _teal, letterSpacing: 1)),
                                ],
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                              child: Text(distance, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 10, fontWeight: FontWeight.w900, color: _teal, letterSpacing: 0.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (mutualBros > 0 || hasSharedHuddle)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Wrap(
                              spacing: 6,
                              children: [
                                if (mutualBros > 0)
                                  _buildIntelBadge(HugeIcons.strokeRoundedUserGroup, '$mutualBros MUTUAL'),
                                if (hasSharedHuddle)
                                  _buildIntelBadge(HugeIcons.strokeRoundedChampion, 'CO-HUDDLE'),
                              ],
                            ),
                          ),
                        Text(bro['bio'] ?? 'This bro is silent but steady. Ready to build.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, color: const Color(0xFF64748B), height: 1.5)),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: broId))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('CONNECT', style: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
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
    );
  }

  Widget _buildIntelBadge(dynamic icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _teal.withOpacity(0.06), borderRadius: BorderRadius.circular(6), border: Border.all(color: _teal.withOpacity(0.12), width: 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [HugeIcon(icon: icon, color: _teal, size: 10), const SizedBox(width: 4), Text(label, style: TextStyle(fontFamily: '.SF Pro Display', color: _teal, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5))]),
    );
  }

  Future<Map<String, dynamic>> _loadMutualIntel(String broId) async {
    try {
      final broConsRes = await Supabase.instance.client.from('conversations').select('user1_id, user2_id').or('user1_id.eq.$broId,user2_id.eq.$broId').eq('status', 'accepted');
      final broConnections = (broConsRes as List).map((c) => c['user1_id'].toString() == broId ? c['user2_id'].toString() : c['user1_id'].toString()).toList();
      int mutualCount = 0;
      for (var id in broConnections) { if (_myConnections.contains(id)) mutualCount++; }
      final broHuddlesRes = await Supabase.instance.client.from('huddle_members').select('huddle_id').eq('user_id', broId);
      final broHuddles = (broHuddlesRes as List).map((h) => h['huddle_id'].toString()).toList();
      bool sharedHuddle = false;
      for (var hId in broHuddles) { if (_myHuddles.contains(hId)) sharedHuddle = true; }
      return {'mutualBros': mutualCount, 'sharedHuddle': sharedHuddle};
    } catch (e) { return {'mutualBros': 0, 'sharedHuddle': false}; }
  }

  Widget _buildPulsingRadar() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [_PulsingRing(color: _teal), const SizedBox(height: 32), Text('PINGING THE BROHOOD...', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black26, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 11))]));
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
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(alignment: Alignment.center, children: [
          Container(width: 120 * _controller.value, height: 120 * _controller.value, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color.withOpacity(1 - _controller.value), width: 3))),
          Container(width: 20, height: 20, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)])),
        ]);
      },
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'package:bro_app/src/core/services/location_service.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:bro_app/src/core/theme/app_theme.dart';

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
  bool _isRadarView = false;

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
            color: context.broColors.card,
            border: Border(bottom: BorderSide(color: context.broColors.border, width: 1)),
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
                          border: Border.all(color: isSelected ? _teal : context.broColors.border, width: 1.5),
                        ),
                        child: Text(
                          vibe == 'ALL' ? 'ALL' : '#$vibe',
                          style: TextStyle(fontFamily: '.SF Pro Display', 
                            color: isSelected ? Colors.white : context.broColors.subtext,
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
                        Text('DISCOVERY RADIUS', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 11, fontWeight: FontWeight.w900, color: context.broColors.subtext, letterSpacing: 1.5)),
                        Text('${_searchRadius.round()} KM', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, fontWeight: FontWeight.w900, color: _teal)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _teal,
                        inactiveTrackColor: context.broColors.border,
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isRadarView = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_isRadarView ? _teal.withOpacity(0.08) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: !_isRadarView ? _teal.withOpacity(0.2) : Colors.transparent),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HugeIcon(icon: HugeIcons.strokeRoundedQueue01, color: !_isRadarView ? _teal : context.broColors.subtext, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'CARDS VIEW',
                                    style: TextStyle(
                                      fontFamily: '.SF Pro Display',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: !_isRadarView ? _teal : context.broColors.subtext,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isRadarView = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _isRadarView ? _teal.withOpacity(0.08) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _isRadarView ? _teal.withOpacity(0.2) : Colors.transparent),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HugeIcon(icon: HugeIcons.strokeRoundedCompass01, color: _isRadarView ? _teal : context.broColors.subtext, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    'RADAR MAP',
                                    style: TextStyle(
                                      fontFamily: '.SF Pro Display',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: _isRadarView ? _teal : context.broColors.subtext,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
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
        Expanded(
          child: _isLoading && _nearbyBros.isEmpty
              ? _buildPulsingRadar()
              : _isRadarView
                  ? BroskyRadarView(
                      nearbyBros: _nearbyBros,
                      searchRadius: _searchRadius,
                      myPosition: _myPosition,
                      onBroTap: (bro) {
                        debugPrint('Tapped bro: ${bro['username']}');
                      },
                    )
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
    if (bro['last_seen_at'] != null) {
      final lastActive = DateTime.parse(bro['last_seen_at']);
      final nowUtc = DateTime.now().toUtc();
      isOnline = nowUtc.difference(lastActive).inSeconds < 60;
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
                            color: context.broColors.border,
                            image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                          ),
                          child: avatarUrl == null ? HugeIcon(icon: HugeIcons.strokeRoundedUser, color: context.broColors.subtext, size: 32) : null,
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 2, right: 2,
                            child: Container(
                              width: 14, height: 14,
                              decoration: BoxDecoration(
                                color: _teal,
                                shape: BoxShape.circle,
                                border: Border.all(color: context.isDark ? context.broColors.card : Colors.white, width: 2.5),
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
                                 Text(username, style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, fontSize: 18, color: context.broColors.text)),
                                if (isOnline) ...[
                                  const SizedBox(width: 8),
                                  Text('ONLINE', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 9, fontWeight: FontWeight.w900, color: _teal, letterSpacing: 1)),
                                ],
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: context.broColors.inputFill, borderRadius: BorderRadius.circular(8)),
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
                        Text(bro['bio'] ?? 'This bro is silent but steady. Ready to build.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, color: context.broColors.subtext, height: 1.5)),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: broId))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(color: context.broColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.broColors.border, width: 1.5)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('CONNECT', style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.text, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                                const SizedBox(width: 8),
                                HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, color: context.broColors.text, size: 14),
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
            Divider(height: 1, thickness: 1, color: context.broColors.border),
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
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [_PulsingRing(color: _teal), const SizedBox(height: 32), Text('PINGING THE BROHOOD...', style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.subtext, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 11))]));
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

// --- STATEFUL TACTICAL INTERACTIVE RADAR VIEW ---
class BroskyRadarView extends StatefulWidget {
  final List<Map<String, dynamic>> nearbyBros;
  final double searchRadius;
  final Function(Map<String, dynamic> bro) onBroTap;
  final Position? myPosition;

  const BroskyRadarView({
    super.key,
    required this.nearbyBros,
    required this.searchRadius,
    required this.onBroTap,
    this.myPosition,
  });

  @override
  State<BroskyRadarView> createState() => _BroskyRadarViewState();
}

class _BroskyRadarViewState extends State<BroskyRadarView> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  Map<String, dynamic>? _selectedBro;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A), // Premium slate dark mode
      child: Stack(
        children: [
          // Radar Grid + Sweeper beam
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: _RadarPainter(
                  angle: _rotationController.value * 2 * math.pi,
                  searchRadius: widget.searchRadius,
                ),
              );
            },
          ),
          
          // Mapped Node elements
          LayoutBuilder(
            builder: (context, constraints) {
              final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
              final maxRadius = constraints.maxWidth < constraints.maxHeight 
                  ? constraints.maxWidth / 2 - 40 
                  : constraints.maxHeight / 2 - 40;

              return Stack(
                children: [
                  ...widget.nearbyBros.map((bro) {
                    final broId = bro['id'].toString();
                    
                    double angle = 0.0;
                    double relativeDistanceFraction = 0.0;
                    
                    if (widget.myPosition != null && bro['last_lat'] != null && bro['last_long'] != null) {
                      double dy = bro['last_lat'] - widget.myPosition!.latitude;
                      double dx = (bro['last_long'] - widget.myPosition!.longitude);
                      
                      angle = math.atan2(dy, dx);

                      double actualDistance = LocationService.calculateDistance(
                        widget.myPosition!.latitude, 
                        widget.myPosition!.longitude, 
                        bro['last_lat'], 
                        bro['last_long']
                      );
                      relativeDistanceFraction = actualDistance / widget.searchRadius;
                    } else {
                      angle = (broId.hashCode % 360) * math.pi / 180;
                      relativeDistanceFraction = ((broId.hashCode % 10) + 1) / 12;
                    }

                    relativeDistanceFraction = relativeDistanceFraction.clamp(0.15, 0.92);
                    
                    final x = center.dx + maxRadius * relativeDistanceFraction * math.cos(angle);
                    final y = center.dy - maxRadius * relativeDistanceFraction * math.sin(angle);
                    
                    final isSelected = _selectedBro?['id'] == bro['id'];

                    return Positioned(
                      left: x - 22,
                      top: y - 22,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedBro = isSelected ? null : bro;
                          });
                          widget.onBroTap(bro);
                        },
                        child: _RadarNodeWidget(
                          avatarUrl: bro['avatar_url'],
                          isOnline: _isBroOnline(bro['last_seen_at']),
                          isSelected: isSelected,
                        ),
                      ),
                    );
                  }).toList(),
                  
                  // Center user ("You")
                  Positioned(
                    left: center.dx - 12,
                    top: center.dy - 12,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          // Preview profile card overlay
          if (_selectedBro != null)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: _buildSelectedBroCard(context, _selectedBro!),
            ),
        ],
      ),
    );
  }

  bool _isBroOnline(String? lastSeenAtStr) {
    if (lastSeenAtStr == null) return false;
    try {
      final lastSeen = DateTime.parse(lastSeenAtStr);
      final difference = DateTime.now().toUtc().difference(lastSeen);
      return difference.inSeconds < 60;
    } catch (_) {
      return false;
    }
  }

  Widget _buildSelectedBroCard(BuildContext context, Map<String, dynamic> bro) {
    final avatarUrl = bro['avatar_url'];
    final username = bro['username'] ?? 'Bro';
    final distVal = (bro['real_distance'] as double? ?? 0.0);
    final distance = distVal == 0.0 ? 'LOCAL' : '${distVal.toStringAsFixed(1)} KM';
    final bio = bro['bio'] ?? 'This Bro is silent but steady.';
    final vibes = List<String>.from(bro['vibes'] ?? []);
    final isOnline = _isBroOnline(bro['last_seen_at']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF1F5F9),
                      image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                    ),
                    child: avatarUrl == null ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Color(0xFFCBD5E1), size: 24) : null,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontFamily: '.SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      distance,
                      style: const TextStyle(
                        fontFamily: '.SF Pro Display',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.black38, size: 20),
                onPressed: () => setState(() => _selectedBro = null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: '.SF Pro Display',
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          if (vibes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: vibes.map((v) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.12)),
                ),
                child: Text(
                  '#$v',
                  style: const TextStyle(
                    fontFamily: '.SF Pro Display',
                    color: Color(0xFF14B8A6),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              )).toList(),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => PublicProfileScreen(userId: bro['id'].toString())),
                );
              },
              child: const Text(
                'VIEW PROFILE',
                style: TextStyle(
                  fontFamily: '.SF Pro Display',
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SCANNING RADAR CIRCULAR GRID & SWEEPER PAINTER ---
class _RadarPainter extends CustomPainter {
  final double angle;
  final double searchRadius;

  _RadarPainter({required this.angle, required this.searchRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width < size.height 
        ? size.width / 2 - 40 
        : size.height / 2 - 40;

    final gridPaint = Paint()
      ..color = const Color(0xFF14B8A6).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Concentric rings grid
    const ringCount = 4;
    for (var i = 1; i <= ringCount; i++) {
      final ringRadius = maxRadius * (i / ringCount);
      canvas.drawCircle(center, ringRadius, gridPaint);
      
      // KM Label text markers
      final distanceText = '${(searchRadius * (i / ringCount)).round()} KM';
      final textPainter = TextPainter(
        text: TextSpan(
          text: distanceText,
          style: TextStyle(
            color: const Color(0xFF14B8A6).withOpacity(0.4),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            fontFamily: '.SF Pro Display',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas, 
        Offset(center.dx - textPainter.width / 2, center.dy - ringRadius - 10),
      );
    }

    // 2. Center crosshair lines
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), gridPaint);

    // 3. Sweeping gradient search beam
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: [
          const Color(0xFF14B8A6).withOpacity(0.0),
          const Color(0xFF14B8A6).withOpacity(0.25),
        ],
        stops: const [0.85, 1.0],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // 4. Bright sweeping leading line edge
    final edgePaint = Paint()
      ..color = const Color(0xFF14B8A6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final edgeX = center.dx + maxRadius * math.cos(angle);
    final edgeY = center.dy + maxRadius * math.sin(angle);
    canvas.drawLine(center, Offset(edgeX, edgeY), edgePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.searchRadius != searchRadius;
  }
}

// --- SCANNING GLOWING RADAR MATCH NODE ---
class _RadarNodeWidget extends StatelessWidget {
  final String? avatarUrl;
  final bool isOnline;
  final bool isSelected;

  const _RadarNodeWidget({
    required this.avatarUrl,
    required this.isOnline,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF14B8A6);
    
    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 44, height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(
              color: isSelected ? teal : Colors.transparent,
              width: 2.0,
            ),
            boxShadow: isSelected 
                ? [BoxShadow(color: teal.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)]
                : null,
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF334155),
              image: avatarUrl != null 
                  ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: avatarUrl == null 
                ? const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: Colors.white30, size: 16)
                : null,
          ),
        ),
        if (isOnline)
          Positioned(
            bottom: 2, right: 2,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: teal,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F172A), width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

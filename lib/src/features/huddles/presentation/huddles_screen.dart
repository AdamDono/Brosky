import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HuddlesScreen extends StatelessWidget {
  const HuddlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Huddles', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
           IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle, color: Color(0xFF2DD4BF), size: 32),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4, // Mock data count
        itemBuilder: (context, index) {
          final isLive = index == 0; // First one is "Live"
          return _HuddleCard(index: index, isLive: isLive);
        },
      ),
    );
  }
}

class _HuddleCard extends StatelessWidget {
  final int index;
  final bool isLive;

  const _HuddleCard({required this.index, required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: isLive ? Border.all(color: const Color(0xFF2DD4BF), width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              Text(
                'Gaming · 5 min ago',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              const Icon(Icons.mic, color: Colors.white54, size: 16),
              const SizedBox(width: 4),
              Text(
                '${3 + index} listening',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isLive ? 'Debating the best COD loadout right now' : 'Startup ideas for 2026 - Brainstorming',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Avatar Stack
              SizedBox(
                width: 80,
                child: Stack(
                  children: [
                    _buildAvatar(0),
                    Positioned(left: 20, child: _buildAvatar(1)),
                    Positioned(left: 40, child: _buildAvatar(2)),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLive ? const Color(0xFF2DD4BF) : Colors.white10,
                  foregroundColor: isLive ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(
                  'Join Room',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(int i) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1E293B), width: 2),
      ),
      child: const Icon(Icons.person, size: 20, color: Colors.white70),
    );
  }
}

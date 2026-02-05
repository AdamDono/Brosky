import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bro Posts', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune, color: Color(0xFF2DD4BF)),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle, color: Color(0xFF2DD4BF), size: 32),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return const BroPostCard();
        },
      ),
    );
  }
}

class BroPostCard extends StatelessWidget {
  const BroPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF2DD4BF),
                child: Icon(Icons.person, color: Colors.black),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mike_JHB', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  Text('2h ago • 1.2km away', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Sports',
                  style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "At the gym in Sandton, who's training? Need someone to debate the rugby results with while I hit chest.",
            style: GoogleFonts.outfit(fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.white60),
              const SizedBox(width: 8),
              const Text('3', style: TextStyle(color: Colors.white60)),
              const SizedBox(width: 24),
              const Icon(Icons.favorite_border, size: 20, color: Colors.white60),
              const SizedBox(width: 8),
              const Text('12', style: TextStyle(color: Colors.white60)),
              const Spacer(),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2DD4BF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HuddlesScreen extends StatefulWidget {
  const HuddlesScreen({super.key});

  @override
  State<HuddlesScreen> createState() => _HuddlesScreenState();
}

class _HuddlesScreenState extends State<HuddlesScreen> {
  double _radius = 25.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Brotherhood Huddles', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                      'GROUP RADIUS',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '${_radius.round()} km',
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
                    value: _radius,
                    min: 5,
                    max: 100,
                    onChanged: (val) {
                      setState(() => _radius = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.groups_outlined, size: 64, color: Colors.white10),
                  const SizedBox(height: 16),
                  Text(
                    'No Huddles in this radius yet.\nStart a local Huddle!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('New Huddle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DD4BF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

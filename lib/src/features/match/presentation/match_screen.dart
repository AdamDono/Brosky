import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ripples
          _buildRipple(_controller, delay: 0.0),
          _buildRipple(_controller, delay: 0.33),
          _buildRipple(_controller, delay: 0.66),
          
          // Center Interactions
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E293B),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2DD4BF).withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    const BoxShadow(
                      color: Color(0xFF0F172A),
                      offset: Offset(-4, -4),
                      blurRadius: 10,
                    ),
                  ],
                  border: Border.all(color: const Color(0xFF2DD4BF).withOpacity(0.5), width: 1),
                ),
                child: const Icon(
                  Icons.radar,
                  size: 50,
                  color: Color(0xFF2DD4BF),
                ),
              ),
              const SizedBox(height: 60),
              
              // Pulsing Text using Opacity
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.5 + (_controller.value.sin() ?? 0.0).abs() * 0.5, // Simple blink approximation
                    child: Text(
                      'SCANNING FOR BROS...',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: const Color(0xFF2DD4BF),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Finding ambitious guys in Joburg\nwho like Sports & Business',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
            ],
          ),

          // Action Button (Simulated Mock)
          Positioned(
            bottom: 40,
            child: TextButton(
              onPressed: () {}, 
              child: Text(
                'Cancel Scan',
                style: GoogleFonts.outfit(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRipple(AnimationController controller, {required double delay}) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double t = (controller.value + delay) % 1.0;
        final double opacity = 1.0 - t;
        final double scale = 1.0 + (t * 3.0); // Grows to 4x size

        return Container(
          width: 120 * scale,
          height: 120 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF2DD4BF).withOpacity(opacity * 0.5),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

// Extension to help with sin calc if needed, though mostly using t direct is fine
extension on double {
  double sin() => math.sin(this * math.pi * 2);
}

import 'package:bro_app/src/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<String> selectedVibes = [];
  
  final List<Map<String, dynamic>> vibes = [
    {'name': 'Sports & Fitness', 'icon': Icons.fitness_center},
    {'name': 'Gaming & Culture', 'icon': Icons.sports_esports},
    {'name': 'Life & Real Talk', 'icon': Icons.chat_bubble_outline},
    {'name': 'Business & Hustle', 'icon': Icons.rocket_launch},
  ];

  Future<void> _saveVibes() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'vibes': selectedVibes})
          .eq('id', user.id);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving vibes: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text(
                'Pick Your Vibes',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'What do you want to talk about today?\nSelect at least 2.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 48),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: vibes.length,
                  itemBuilder: (context, index) {
                    final vibe = vibes[index];
                    final isSelected = selectedVibes.contains(vibe['name']);
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedVibes.remove(vibe['name']);
                          } else {
                            selectedVibes.add(vibe['name']);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? const Color(0xFF2DD4BF).withOpacity(0.1)
                            : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected 
                              ? const Color(0xFF2DD4BF) 
                              : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              vibe['icon'],
                              size: 40,
                              color: isSelected 
                                ? const Color(0xFF2DD4BF) 
                                : Colors.white70,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              vibe['name'],
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: isSelected 
                                  ? const Color(0xFF2DD4BF) 
                                  : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: selectedVibes.length >= 2 ? _saveVibes : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DD4BF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: Colors.white10,
                    ),
                    child: Text(
                      'Let\'s Go',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

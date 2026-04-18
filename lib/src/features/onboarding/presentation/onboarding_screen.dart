import 'package:bro_app/src/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<String> selectedVibes = [];
  final Color _teal = const Color(0xFF14B8A6);
  
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
            content: Text('Error saving vibes: $error', style: const TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w600, color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text(
                'Pick Your Vibes',
                style: TextStyle(fontFamily: '.SF Pro Display', 
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'What do you want to talk about today?\nSelect at least 2.',
                style: TextStyle(fontFamily: '.SF Pro Display', 
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
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
                            ? _teal.withOpacity(0.06)
                            : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected 
                              ? _teal 
                              : const Color(0xFFF1F5F9),
                            width: isSelected ? 2 : 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              vibe['icon'],
                              size: 36,
                              color: isSelected 
                                ? _teal 
                                : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              vibe['name'],
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: '.SF Pro Display', 
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected 
                                  ? const Color(0xFF1E293B) 
                                  : const Color(0xFF64748B),
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
                  height: 56,
                  child: ElevatedButton(
                    onPressed: selectedVibes.length >= 2 ? _saveVibes : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: const Color(0xFFF1F5F9),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(fontFamily: '.SF Pro Display', 
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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

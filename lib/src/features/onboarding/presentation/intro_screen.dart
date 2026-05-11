import 'package:bro_app/src/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Color _primaryColor = const Color(0xFF14B8A6);

  final List<Map<String, String>> _slides = [
    {
      'title': 'THE BROHOOD',
      'subtitle': 'A digital corner store for men to talk, connect, and grow without the noise.',
      'image': 'assets/images/auth_hero.png', // Reusing your premium illustration
    },
    {
      'title': 'SAFE SPACE',
      'subtitle': 'Real talk only. No judgment, no filters—just brotherhood and accountability.',
      'image': 'assets/images/auth_hero.png', 
    },
    {
      'title': 'GLOBAL SQUAD',
      'subtitle': 'Find your tribe. From gaming to fitness, join huddles that match your vibe.',
      'image': 'assets/images/auth_hero.png',
    },
  ];

  Future<void> _completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_intro', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      slide['image']!,
                      height: 350,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),
                    Text(
                      slide['title']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: '.SF Pro Display', 
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      slide['subtitle']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: '.SF Pro Display', 
                        fontSize: 16,
                        color: Colors.black45,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Bottom Navigation
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? _primaryColor : _primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _slides.length - 1) {
                        _completeIntro();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentPage == _slides.length - 1 ? 'GET STARTED' : 'CONTINUE',
                      style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

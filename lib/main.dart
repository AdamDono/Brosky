import 'package:bro_app/src/features/auth/presentation/auth_screen.dart';
import 'package:bro_app/src/features/home/presentation/home_screen.dart';
import 'package:bro_app/src/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://pgrtiirtkoaxnpnybmuw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBncnRpaXJ0a29heG5wbnlibXV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0MjY0ODcsImV4cCI6MjA4NjAwMjQ4N30.uZhiTWtKjCpT8eAaiHuX0f_3S2bD3uQyUc0feINw948',
  );

  runApp(
    const ProviderScope(
      child: BroApp(),
    ),
  );
}

class BroApp extends StatelessWidget {
  const BroApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryIndigo = Color(0xFF14B8A6);

    return MaterialApp(
      title: 'BROSKY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000), // Pure Obsidian
        primaryColor: primaryIndigo,
        canvasColor: const Color(0xFF111111),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, color: Colors.white),
          titleLarge: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w800, color: Colors.white),
          bodyMedium: TextStyle(fontFamily: '.SF Pro Display', color: Colors.white70),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1),
        ),
        colorScheme: const ColorScheme.dark(
          primary: primaryIndigo,
          onPrimary: Colors.white,
          secondary: Color(0xFF4F46E5),
          surface: Color(0xFF0A0A0A),
          onSurface: Colors.white,
          background: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const AuthScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _shakeAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticIn),
    );

    _redirect();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 6));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('vibes')
            .eq('id', session.user.id)
            .maybeSingle();

        final vibes = (profile?['vibes'] as List?) ?? [];
        
        if (mounted) {
          if (vibes.isNotEmpty) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium Animated Geometric Logo
            ScaleTransition(
              scale: _scaleAnimation,
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _shakeAnimation.value,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withOpacity(0.15),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(70),
                        child: Image.asset(
                          'assets/images/brosky_logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'BROSKY',
              style: TextStyle(fontFamily: '.SF Pro Display', 
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The digital corner store.',
              style: TextStyle(fontFamily: '.SF Pro Display', 
                fontSize: 16,
                color: Color(0xFF64748B),
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            const Text(
              'POWERED BY PACE TECH',
              style: TextStyle(
                fontFamily: '.SF Pro Display',
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
}
}

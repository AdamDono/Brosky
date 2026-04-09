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
    const Color primaryIndigo = Color(0xFF6366F1);

    return MaterialApp(
      title: 'BROSKY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000), // Pure Obsidian
        primaryColor: primaryIndigo,
        canvasColor: const Color(0xFF111111),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.white),
          titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white),
          bodyMedium: GoogleFonts.inter(color: Colors.white70),
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

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 3));
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Placeholder
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.handshake_rounded,
                size: 70,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'BROSKY',
              style: GoogleFonts.outfit(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The digital corner store.',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

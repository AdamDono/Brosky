import 'package:bro_app/src/features/home/presentation/home_screen.dart';
import 'package:bro_app/src/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Toggle: True = Sign Up, False = Sign In
  bool _isSignUp = false;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController(); // Only for Sign Up
  bool _isLoading = false;

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) return;
    if (_isSignUp && username.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        // --- SIGN UP ---
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'username': username}, // Save username in metadata
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account Created! Please check your email to confirm.'),
              backgroundColor: Color(0xFF2DD4BF),
            ),
          );
          // Auto-login logic usually follows, or ask them to check email
        }
      } else {
        // --- SIGN IN ---
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        // Auth state listener will handle navigation
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unexpected error occurred'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Check if user has completed onboarding (has vibes)
      final response = await Supabase.instance.client
          .from('profiles')
          .select('vibes')
          .eq('id', user.id)
          .single();

      final vibes = List<String>.from(response['vibes'] ?? []);

      if (mounted) {
        if (vibes.isEmpty) {
          // First time user - show onboarding
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        } else {
          // Returning user - go straight to home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (error) {
      // If error, default to onboarding
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen for successful login
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _checkOnboardingStatus();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2DD4BF), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2DD4BF).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.handshake_outlined,
                    size: 40,
                    color: Color(0xFF2DD4BF),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isSignUp ? 'Join the Brotherhood.' : 'Welcome Back.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp 
                    ? 'Start connecting with real guys today.' 
                    : 'Good to see you again, Bro.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 48),

                // Form Fields
                if (_isSignUp) ...[
                  TextField(
                    controller: _usernameController,
                    style: GoogleFonts.outfit(color: Colors.white),
                    decoration: _inputDecoration('Username'),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _emailController,
                  style: GoogleFonts.outfit(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email Address'),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: GoogleFonts.outfit(color: Colors.white),
                  decoration: _inputDecoration('Password'),
                ),

                const SizedBox(height: 32),

                // Primary Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2DD4BF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          height: 24, 
                          width: 24, 
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                        )
                      : Text(
                          _isSignUp ? 'Create Account' : 'Sign In',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                  ),
                ),

                const SizedBox(height: 24),

                // Toggle Sign Up / Sign In
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp ? 'Already have an account?' : 'New to BRO?',
                      style: GoogleFonts.outfit(color: Colors.white60),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp ? 'Sign In' : 'Create Account',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF2DD4BF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF2DD4BF)),
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }
}

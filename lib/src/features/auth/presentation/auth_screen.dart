import 'package:bro_app/src/features/auth/presentation/terms_screen.dart';
import 'package:bro_app/src/features/auth/presentation/forgot_password_screen.dart';
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
  bool _rememberMe = false;
  bool _agreeTerms = false;
  bool _confirmMale = false;
  bool _obscurePassword = true;

  final Color _primaryColor = const Color(0xFF14B8A6); // Clean Premium Teal

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.redAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    // --- VALIDATION ---
    if (email.isEmpty) {
      _showError('Please enter your email address, Bro.');
      return;
    }
    if (password.isEmpty) {
      _showError('Password is required to proceed.');
      return;
    }
    if (_isSignUp) {
      if (username.isEmpty) {
        _showError('Please pick a username for the Brotherhood.');
        return;
      }
      if (!_agreeTerms) {
        _showError('You must agree to the Brotherhood Pact to join.');
        return;
      }
      if (!_confirmMale) {
        _showError('This app is an exclusive space for men. You must confirm your identity.');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        // --- SIGN UP ---
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'username': username},
        );
        if (mounted) {
          _showSuccess('Account Created! Please check your email to verify.');
        }
      } else {
        // --- SIGN IN ---
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        _showError(error.message);
      }
    } catch (error) {
      if (mounted) {
        _showError('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        final user = data.session?.user;
        if (user == null) return;
        try {
          final profile = await Supabase.instance.client.from('profiles').select('vibes').eq('id', user.id).maybeSingle();
          final vibes = (profile?['vibes'] as List?) ?? [];
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => vibes.isNotEmpty ? const HomeScreen() : const OnboardingScreen()),
            );
          }
        } catch (e) {
          if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomeScreen()));
        }
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
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: _primaryColor,
        textTheme: ThemeData.light().textTheme.apply(fontFamily: '.SF Pro Display'),
      ),
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isSignUp) ...[
                  // --- High-End Line Art Illustration ---
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Center(
                      child: Image.asset(
                        'assets/images/auth_hero.png',
                        height: 380,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => Container(
                          height: 300,
                          alignment: Alignment.center,
                          child: Icon(Icons.person_outline_rounded, size: 80, color: _primaryColor.withOpacity(0.1)),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // --- Sign Up Header ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 60, 28, 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          _primaryColor.withOpacity(0.08),
                          _primaryColor.withOpacity(0.01),
                          Colors.white,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: () => setState(() => _isSignUp = false),
                          icon: const Icon(Icons.arrow_back, color: Colors.black87),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Let\'s Get Started',
                          style: TextStyle(fontFamily: '.SF Pro Display', 
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join the Brotherhood today',
                          style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 16, color: Colors.black38),
                        ),
                      ],
                    ),
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isSignUp) ...[
                         const SizedBox(height: 10),
                      ],
                      
                      if (_isSignUp) ...[
                        _buildLabel('Username'),
                        TextField(
                          controller: _usernameController,
                          decoration: _inputDecoration('e.g. bro_master'),
                        ),
                        const SizedBox(height: 24),
                      ],

                      _buildLabel('Email Address'),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('your@email.com'),
                      ),
                      const SizedBox(height: 24),
                      
                      _buildLabel('Password'),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          '••••••••', 
                          isPassword: true,
                          onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                          isPasswordVisible: !_obscurePassword,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _isSignUp ? _agreeTerms : _rememberMe,
                                  onChanged: (val) => setState(() {
                                    if (_isSignUp) _agreeTerms = val!;
                                    else _rememberMe = val!;
                                  }),
                                  activeColor: _primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _isSignUp 
                                  ? GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsScreen())),
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            const TextSpan(text: 'I agree with ', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, color: Colors.black87)),
                                            TextSpan(text: 'terms of use', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, color: _primaryColor, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    )
                                  : const Text('Remember me next time', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, color: Colors.black87)),
                              ),
                            ],
                          ),
                          if (_isSignUp) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _confirmMale,
                                    onChanged: (val) => setState(() => _confirmMale = val!),
                                    activeColor: _primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text('I confirm I identify as male and agree to the Brohood Code of Conduct.', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, color: Colors.black87)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 40),

                      if (!_isSignUp) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                            child: Text('Forgot Password?', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 13, fontWeight: FontWeight.w600, color: _primaryColor)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(_isSignUp ? 'Sign up' : 'Sign in', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                      ),

                      const SizedBox(height: 32),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_isSignUp ? 'Already have an account? ' : 'New to BRO? ', style: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black38)),
                            GestureDetector(
                              onTap: () => setState(() => _isSignUp = !_isSignUp),
                              child: Text(_isSignUp ? 'Sign in' : 'Create account', style: TextStyle(fontFamily: '.SF Pro Display', color: _primaryColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(label, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
    );
  }

  InputDecoration _inputDecoration(String hint, {bool isPassword = false, VoidCallback? onToggleVisibility, bool isPasswordVisible = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black12),
      filled: true,
      fillColor: Colors.grey.withOpacity(0.04),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _primaryColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      prefixIcon: Icon(isPassword ? Icons.lock_open_rounded : Icons.alternate_email_rounded, size: 20, color: Colors.black26),
      suffixIcon: isPassword 
        ? IconButton(
            icon: Icon(isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: Colors.black26),
            onPressed: onToggleVisibility,
          )
        : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

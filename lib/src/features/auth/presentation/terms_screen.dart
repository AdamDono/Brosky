import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'THE BROTHERHOOD PACT',
          style: TextStyle(fontFamily: '.SF Pro Display', 
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.black,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1. CODE OF CONDUCT',
              'By joining Brosky, you agree to treat every member with respect. Harassment, hate speech, or toxic behavior is grounds for immediate expulsion from the Brotherhood.',
            ),
            const SizedBox(height: 32),
            _buildSection(
              '2. PRIVACY & DATA',
              'Your data is your own. We use your location and profile info solely to connect you with nearby Bros and Huddles. We do not sell your personal brotherhood history to third parties.',
            ),
            const SizedBox(height: 32),
            _buildSection(
              '3. REAL CONNECTIONS',
              'Brosky is built for real-world interaction. While we provide the digital corner store, you are responsible for maintaining safe and authentic connections in the physical world.',
            ),
            const SizedBox(height: 32),
            _buildSection(
              '4. TERMINATION',
              'We reserve the right to suspend any account that violates the elite standards of the Brotherhood without prior notice.',
            ),
            const SizedBox(height: 60),
            Center(
              child: Text(
                'STAY AUTHENTIC. STAY BRO.',
                style: TextStyle(fontFamily: '.SF Pro Display', 
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: Colors.black26,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontFamily: '.SF Pro Display', 
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: const Color(0xFF14B8A6), // Teal accent
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(fontFamily: '.SF Pro Display', 
            fontSize: 14,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

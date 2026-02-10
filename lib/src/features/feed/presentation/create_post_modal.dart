import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostModal extends StatefulWidget {
  const CreatePostModal({super.key});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final TextEditingController _contentController = TextEditingController();
  String _selectedVibe = 'General';
  bool _isLoading = false;

  final List<String> _vibeOptions = [
    'General',
    'Sports & Fitness',
    'Gaming & Culture',
    'Life & Real Talk',
    'Business & Hustle',
  ];

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('bro_posts').insert({
        'user_id': user.id,
        'content': content,
        'vibe': _selectedVibe,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post Shared, Bro! 🤝'),
            backgroundColor: Color(0xFF2DD4BF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SHARE A THOUGHT, BRO',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2DD4BF),
                  letterSpacing: 1.5,
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2DD4BF)),
                )
              else
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 4,
            autofocus: true,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: "What's on your mind? Location, rugby, hustle...",
              hintStyle: const TextStyle(color: Colors.white24),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.all(20),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF2DD4BF), width: 1),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'CHOOSE THE VIBE',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white38,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _vibeOptions.length,
              itemBuilder: (context, index) {
                final vibe = _vibeOptions[index];
                final isSelected = _selectedVibe == vibe;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedVibe = vibe),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2DD4BF) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      vibe,
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.black : Colors.white60,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2DD4BF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'POST TO THE FEED',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

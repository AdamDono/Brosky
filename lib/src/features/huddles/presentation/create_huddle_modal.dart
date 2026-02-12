import 'package:bro_app/src/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateHuddleModal extends StatefulWidget {
  const CreateHuddleModal({super.key});

  @override
  State<CreateHuddleModal> createState() => _CreateHuddleModalState();
}

class _CreateHuddleModalState extends State<CreateHuddleModal> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedVibe = 'General';
  bool _isSubmitting = false;

  final List<String> _vibes = [
    'General',
    'Sports & Fitness',
    'Gaming & Culture',
    'Life & Real Talk',
    'Business & Hustle',
  ];

  Future<void> _createHuddle() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Get current location for pinning the huddle
      final pos = await LocationService.updateLocation();
      if (pos == null) {
        throw 'Location required to start a Huddle, Bro.';
      }

      // 2. Insert into Supabase
      final huddleResponse = await Supabase.instance.client.from('huddles').insert({
        'creator_id': user.id,
        'name': name,
        'vibe': _selectedVibe,
        'lat': pos.latitude,
        'long': pos.longitude,
      }).select().single();

      // 3. Automatically join the creator as the first member
      await Supabase.instance.client.from('huddle_members').insert({
        'huddle_id': huddleResponse['id'],
        'user_id': user.id,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Huddle is LIVE. Let the bros know! 🏟️⚡️')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        color: Color(0xFF1E293B),
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
                'START A HUDDLE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2DD4BF),
                  letterSpacing: 2,
                ),
              ),
              if (_isSubmitting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2DD4BF)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Huddle Name (e.g. Morning Run)',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'CHOOSE THE VIBE',
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _vibes.map((vibe) {
                final isSelected = _selectedVibe == vibe;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(vibe),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedVibe = vibe),
                    backgroundColor: const Color(0xFF0F172A),
                    selectedColor: const Color(0xFF2DD4BF),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white60,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _createHuddle,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2DD4BF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('LAUNCH HUDDLE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:bro_app/src/core/services/location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class CreatePostModal extends StatefulWidget {
  final Map<String, dynamic>? initialPost; // For editing

  const CreatePostModal({super.key, this.initialPost});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  late TextEditingController _contentController;
  late String _selectedVibe;
  bool _isLoading = false;
  XFile? _imageFile;
  String? _existingImageUrl; // For editing
  final _picker = ImagePicker();
  final Color _tealColor = const Color(0xFF14B8A6);

  final List<String> _vibeOptions = [
    'General',
    'Sports & Fitness',
    'Gaming & Culture',
    'Life & Real Talk',
    'Business & Hustle',
  ];

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialPost?['content'] ?? '');
    _selectedVibe = widget.initialPost?['vibe'] ?? 'General';
    _existingImageUrl = widget.initialPost?['image_url'];
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        _imageFile = image;
        _existingImageUrl = null; 
      });
    }
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imageFile == null && _existingImageUrl == null) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      String? imageUrl = _existingImageUrl;

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final fileExt = kIsWeb ? 'jpg' : _imageFile!.path.split('.').last;
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await Supabase.instance.client.storage.from('post_images').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: _imageFile!.mimeType ?? 'image/jpeg', upsert: true),
        );

        imageUrl = Supabase.instance.client.storage
            .from('post_images')
            .getPublicUrl(fileName);
      }

      if (widget.initialPost == null) {
        final position = await LocationService.updateLocation();
        await Supabase.instance.client.from('bro_posts').insert({
          'user_id': user.id,
          'content': content,
          'vibe': _selectedVibe,
          'image_url': imageUrl,
          if (position != null) 'location_lat': position.latitude,
          if (position != null) 'location_lng': position.longitude,
        });
      } else {
        await Supabase.instance.client.from('bro_posts').update({
          'content': content,
          'vibe': _selectedVibe,
          'image_url': imageUrl,
        }).eq('id', widget.initialPost!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
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
    final isEditing = widget.initialPost != null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
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
                isEditing ? 'RELOAD THE VIBE' : 'SNAP THE VIBE',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 1.5,
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _tealColor),
                )
              else
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.black12, size: 24),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_imageFile != null || _existingImageUrl != null)
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: _imageFile != null 
                        ? (kIsWeb ? NetworkImage(_imageFile!.path) : FileImage(File(_imageFile!.path)) as ImageProvider)
                        : (NetworkImage(_existingImageUrl!) as ImageProvider),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() { _imageFile = null; _existingImageUrl = null; }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),

          TextField(
            controller: _contentController,
            maxLines: 3,
            autofocus: !isEditing,
            style: GoogleFonts.inter(color: Colors.black, fontSize: 16),
            decoration: InputDecoration(
              hintText: "What's hitting, Bro?",
              hintStyle: GoogleFonts.inter(color: Colors.black26),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.black.withOpacity(0.04),
              contentPadding: const EdgeInsets.all(20),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _tealColor.withOpacity(0.1), width: 1),
              ),
              suffixIcon: IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.black26),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'CHOOSE THE VIBE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.black26,
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
                      color: isSelected ? _tealColor : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      vibe.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : Colors.black38,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 0.5,
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
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: _tealColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                isEditing ? 'RELOAD THE VIBE' : 'POST TO THE FEED',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

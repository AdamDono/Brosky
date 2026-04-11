import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreatePostModal extends StatefulWidget {
  final Map<String, dynamic>? existingPost;
  const CreatePostModal({super.key, this.existingPost});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isPosting = false;
  final Color _teal = const Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    if (widget.existingPost != null) {
      _contentController.text = widget.existingPost!['content'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) setState(() => _selectedImage = image);
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _selectedImage == null && widget.existingPost == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isPosting = true);

    try {
      String? imageUrl = widget.existingPost?['image_url'];

      // --- IMAGE UPLOAD LOGIC ---
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final fileName = 'post_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = '${user.id}/$fileName';
        
        await Supabase.instance.client.storage.from('post_images').uploadBinary(path, bytes);
        imageUrl = Supabase.instance.client.storage.from('post_images').getPublicUrl(path);
      }

      if (widget.existingPost != null) {
        // --- EDIT MODE ---
        await Supabase.instance.client.from('bro_posts').update({
          'content': content,
          'image_url': imageUrl,
        }).eq('id', widget.existingPost!['id']);
      } else {
        // --- NEW POST MODE ---
        await Supabase.instance.client.from('bro_posts').insert({
          'user_id': user.id,
          'content': content,
          'image_url': imageUrl,
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Post failed: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed, Bro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existingPost != null;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                isEdit ? 'EDIT POST' : 'NEW POST', 
                style: GoogleFonts.poppins(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2, color: Colors.black26)
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.black12, size: 22)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 5,
            autofocus: true,
            style: GoogleFonts.inter(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "What's the word, Bro?",
              hintStyle: GoogleFonts.inter(color: Colors.black12, fontSize: 16, fontWeight: FontWeight.w600),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null || (isEdit && widget.existingPost!['image_url'] != null))
            Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: _selectedImage != null 
                        ? (kIsWeb ? NetworkImage(_selectedImage!.path) : FileImage(File(_selectedImage!.path)) as ImageProvider)
                        : NetworkImage(widget.existingPost!['image_url']),
                      fit: BoxFit.cover
                    ),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImage = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                onPressed: _pickImage,
                icon: HugeIcon(icon: HugeIcons.strokeRoundedImageAdd01, color: _selectedImage != null ? _teal : Colors.black26, size: 28),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isPosting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _isPosting 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(isEdit ? 'UPDATE' : 'POST', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

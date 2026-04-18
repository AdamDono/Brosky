import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bro_app/src/features/auth/presentation/auth_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const EditProfileScreen({super.key, required this.initialData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late List<String> _selectedVibes;
  bool _isLoading = false;
  XFile? _imageFile;
  final _picker = ImagePicker();

  final List<String> _vibeOptions = [
    'Sports & Fitness',
    'Gaming & Culture',
    'Life & Real Talk',
    'Business & Hustle',
  ];

  final List<String> _presetAvatars = [
    'https://api.dicebear.com/7.x/avataaars/png?seed=Bro1&backgroundColor=2dd4bf',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Bro2&backgroundColor=2dd4bf',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Bro3&backgroundColor=2dd4bf',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Bro4&backgroundColor=2dd4bf',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Bro5&backgroundColor=2dd4bf',
    'https://api.dicebear.com/7.x/avataaars/png?seed=Bro6&backgroundColor=2dd4bf',
  ];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialData['username'] ?? '');
    _bioController = TextEditingController(text: widget.initialData['bio'] ?? '');
    
    // Safely parse vibes which might come back from Supabase as a List<dynamic>
    final rawVibes = widget.initialData['vibes'];
    if (rawVibes is List) {
      _selectedVibes = rawVibes.map((e) => e.toString()).toList();
    } else {
      _selectedVibes = [];
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      String? avatarUrl = widget.initialData['avatar_url'];

      // --- Handle Image Upload ---
      if (_imageFile != null) {
        // On web, path is a blob URL, so we shouldn't use it for extension
        String fileExt = 'jpg'; 
        try {
          if (!kIsWeb) {
            fileExt = _imageFile!.path.split('.').last;
          } else {
            // For web, try to get extension from mimeType or default to jpg
            final mime = _imageFile!.mimeType;
            if (mime != null && mime.contains('/')) {
              fileExt = mime.split('/').last;
            }
          }
        } catch (_) {}

        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = fileName;

        final bytes = await _imageFile!.readAsBytes();
        
        // Upload to 'avatars' bucket
        await Supabase.instance.client.storage.from('avatars').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: _imageFile!.mimeType, upsert: true),
        );

        // Get public URL
        avatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(filePath);
      }

      // Update basic info + avatar_url
      await Supabase.instance.client.from('profiles').update({
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'vibes': _selectedVibes,
        'avatar_url': avatarUrl,
      }).eq('id', user.id);

      if (mounted) {
        Navigator.pop(context, true); // Return true to signal refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile Updated, Bro! 🤝'),
            backgroundColor: Color(0xFFFFFFFF),
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

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account', style: TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 20)),
        content: const Text(
          'Are you absolutely sure?\n\nThis will permanently delete your profile, all your posts, active huddle memberships, and messages. This action cannot be undone.',
          style: TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF64748B), height: 1.5, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Permanently', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      // Step 1: Call the RPC function to delete the auth user
      // Note: We need a Supabase edge function or RPC for complete auth.users deletion.
      // We will attempt to call an RPC 'delete_user_account'
      await Supabase.instance.client.rpc('delete_user_account');
      
      // Step 2: Sign out
      await Supabase.instance.client.auth.signOut();
      
      if (mounted) {
        // Pop back to Auth Screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error deleting account: $e\nEnsure RPC function is deployed.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Edit Profile', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(fontFamily: '.SF Pro Display', 
                  color: Color(0xFF14B8A6),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar Selection
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
                      image: _imageFile != null
                          ? DecorationImage(
                              image: kIsWeb
                                  ? NetworkImage(_imageFile!.path)
                                  : FileImage(File(_imageFile!.path)) as ImageProvider,
                              fit: BoxFit.cover,
                            )
                          : (widget.initialData['avatar_url'] != null
                              ? DecorationImage(
                                  image: NetworkImage(widget.initialData['avatar_url']),
                                  fit: BoxFit.cover,
                                )
                              : null),
                    ),
                    child: (_imageFile == null && widget.initialData['avatar_url'] == null)
                        ? const Icon(Icons.person, size: 60, color: Colors.white24)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: const Text(
                'OR CHOOSE A BRO PORTRAIT',
                style: TextStyle(fontFamily: '.SF Pro Display', 
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _presetAvatars.length,
                itemBuilder: (context, index) {
                  final avatar = _presetAvatars[index];
                  final isSelected = widget.initialData['avatar_url'] == avatar && _imageFile == null;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _imageFile = null; // Clear local pick
                        widget.initialData['avatar_url'] = avatar; // Set preset
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFFFFFF) : Colors.white10,
                          width: 2,
                        ),
                        image: DecorationImage(
                          image: NetworkImage(avatar),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),

            // Username Input
            _buildLabel('Username'),
            _buildTextField(
              controller: _usernameController,
              hint: 'How should the bros call you?',
            ),
            const SizedBox(height: 24),

            // Bio Input
            _buildLabel('Bio'),
            _buildTextField(
              controller: _bioController,
              hint: 'What\'s your story?',
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // Vibes Selection
            _buildLabel('Your Vibes'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _vibeOptions.map((vibe) {
                final isSelected = _selectedVibes.contains(vibe);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedVibes.remove(vibe);
                      } else {
                        _selectedVibes.add(vibe);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFFFFF).withOpacity(0.1)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFFFFFF) : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      vibe,
                      style: TextStyle(fontFamily: '.SF Pro Display', 
                        color: isSelected ? const Color(0xFFFFFFFF) : Colors.white60,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 48),
            const Divider(color: Color(0xFFF1F5F9), thickness: 1),
            const SizedBox(height: 24),
            
            // Delete Account Section (Apple Mandate)
            _buildLabel('Danger Zone'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => _showDeleteConfirmation(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  foregroundColor: Colors.redAccent,
                ),
                child: const Text('Delete Account', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action is permanent and will remove all your posts, connections, and personal data from Brosky.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 40),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontFamily: '.SF Pro Display', 
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF64748B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }
}

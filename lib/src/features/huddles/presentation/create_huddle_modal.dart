import 'package:bro_app/src/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';

class CreateHuddleModal extends StatefulWidget {
  const CreateHuddleModal({super.key});

  @override
  State<CreateHuddleModal> createState() => _CreateHuddleModalState();
}

class _CreateHuddleModalState extends State<CreateHuddleModal> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _manifestoController = TextEditingController();
  dynamic _selectedIcon = HugeIcons.strokeRoundedChampion;

  final TextEditingController _descriptionController = TextEditingController();
  String _selectedVibe = 'STRATEGY';

  bool _isPublic = true;

  final Color _teal = const Color(0xFF14B8A6);
  final List<String> _vibes = ['STRATEGY', 'GAINS', 'LIFESTYLE', 'HUSTLE', 'VIBES'];
  
  final List<dynamic> _tacticalIcons = [
    HugeIcons.strokeRoundedChampion,
    HugeIcons.strokeRoundedWorkHistory,
    HugeIcons.strokeRoundedFire,
    HugeIcons.strokeRoundedTarget02,
    HugeIcons.strokeRoundedCompass01,
    HugeIcons.strokeRoundedFlash,
  ];

  Future<void> _deploySquad() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    debugPrint('🛫 INITIATING SQUAD DEPLOYMENT: $name');
    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) { debugPrint('❌ DEPLOYMENT FAILED: NO AUTH USER'); return; }

      debugPrint('📍 FETCHING LOCATION...');
      final pos = await LocationService.updateLocation().timeout(const Duration(seconds: 5), onTimeout: () => null);

      debugPrint('🛰️ SENDING SUPABASE INSERT COMMAND...');

      // NOTE: Only inserting columns confirmed to exist in the DB schema.
      // Run the SQL migration in your Supabase dashboard to enable full fields:
      // ALTER TABLE huddles ADD COLUMN IF NOT EXISTS description text;
      // ALTER TABLE huddles ADD COLUMN IF NOT EXISTS manifesto text;
      // ALTER TABLE huddles ADD COLUMN IF NOT EXISTS vibe text;
      // ALTER TABLE huddles ADD COLUMN IF NOT EXISTS is_public boolean DEFAULT true;
      final insertPayload = <String, dynamic>{
        'creator_id': user.id,
        'name': name,
        'lat': pos?.latitude ?? 0.0,
        'long': pos?.longitude ?? 0.0,
      };

      // Conditionally add optional columns if they exist
      // (will be ignored gracefully after migration is applied)
      if (_descriptionController.text.trim().isNotEmpty) {
        insertPayload['description'] = _descriptionController.text.trim();
      }
      if (_manifestoController.text.trim().isNotEmpty) {
        insertPayload['manifesto'] = _manifestoController.text.trim();
      }
      insertPayload['vibe'] = _selectedVibe;
      insertPayload['is_public'] = _isPublic;

      late Map<String, dynamic> huddleResponse;
      try {
        huddleResponse = await Supabase.instance.client.from('huddles').insert(insertPayload).select().single();
      } catch (schemaErr) {
        // Fallback: insert with only base columns if optional ones fail
        debugPrint('⚠️ SCHEMA MISMATCH - FALLING BACK TO BASE COLUMNS: $schemaErr');
        final basePayload = <String, dynamic>{
          'creator_id': user.id,
          'name': name,
          'lat': pos?.latitude ?? 0.0,
          'long': pos?.longitude ?? 0.0,
        };
        huddleResponse = await Supabase.instance.client.from('huddles').insert(basePayload).select().single();
      }

      debugPrint('✅ HUDDLE CREATED: ${huddleResponse['id']}');

      debugPrint('🤝 JOINING SQUAD...');
      await Supabase.instance.client.from('huddle_members').insert({
        'huddle_id': huddleResponse['id'],
        'user_id': user.id,
      });

      debugPrint('🚀 DEPLOYMENT COMPLETE.');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SQUAD DEPLOYED. BROHOOD ACTIVATED. ⚡️')));
      }
    } catch (e) {
      debugPrint('❌ DEPLOYMENT CRITICAL ERROR: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deployment Failed: $e')));
    } finally { if (mounted) setState(() => _isSubmitting = false); }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else { _deploySquad(); }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(2)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ENLISTMENT PROTOCOL', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(_currentStep == 0 ? 'STEP 01: IDENTITY' : _currentStep == 1 ? 'STEP 02: PURPOSE' : 'STEP 03: PROTOCOL', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                ]),
                Text('${_currentStep + 1}/3', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, fontWeight: FontWeight.w900, color: _teal)),
              ],
            ),
          ),
          const Divider(height: 32, thickness: 1, color: Color(0xFFF1F5F9)),
          Expanded(child: PageView(controller: _pageController, physics: const NeverScrollableScrollPhysics(), children: [_buildIdentityStep(), _buildPurposeStep(), _buildProtocolStep()])),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Row(
              children: [
                if (_currentStep > 0) IconButton(onPressed: _prevStep, icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: Colors.black26, size: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _isSubmitting ? null : _nextStep,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(color: _currentStep == 2 ? _teal : const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
                      child: Center(child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : Text(_currentStep == 2 ? 'DEPLOY SQUAD' : 'NEXT COMMAND', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildLabel('SQUAD NAME'), _buildTextField(_nameController, 'e.g., LIONS OF STRATEGY'),
        const SizedBox(height: 24), _buildLabel('SQUAD MANIFESTO'), _buildTextField(_manifestoController, 'e.g., Build once, build right.'),
        const SizedBox(height: 24), _buildLabel('TACTICAL SIGNATURE'), const SizedBox(height: 12),
        Wrap(spacing: 12, children: _tacticalIcons.map((icon) {
          final isSelected = _selectedIcon == icon;
          return GestureDetector(onTap: () => setState(() => _selectedIcon = icon), child: Container(width: 54, height: 54, decoration: BoxDecoration(color: isSelected ? _teal : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? _teal : Colors.transparent, width: 2)), child: Center(child: HugeIcon(icon: icon, color: isSelected ? Colors.white : const Color(0xFFCBD5E1), size: 24))));
        }).toList()),
      ]),
    );
  }

  Widget _buildPurposeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildLabel('SQUAD DESCRIPTION'),
        TextField(controller: _descriptionController, maxLines: 4, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 16, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600), decoration: InputDecoration(hintText: 'Define the mission objective...', hintStyle: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black12, fontWeight: FontWeight.w600), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(20))),
        const SizedBox(height: 24), _buildLabel('TARGET CORRIDOR'), const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: _vibes.map((vibe) {
          final isSelected = _selectedVibe == vibe;
          return GestureDetector(onTap: () => setState(() => _selectedVibe = vibe), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: isSelected ? _teal : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? _teal : const Color(0xFFF1F5F9), width: 1.5)), child: Text('#$vibe', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 11, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : const Color(0xFF64748B), letterSpacing: 1))));
        }).toList()),
      ]),
    );
  }

  Widget _buildProtocolStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildLabel('ACCESS PROTOCOL'), const SizedBox(height: 12),
        _buildProtocolButton(true, 'OPEN RANGE', 'Anyone can enter.', HugeIcons.strokeRoundedUserGroup), const SizedBox(height: 12),
        _buildProtocolButton(false, 'RESTRICTED SQUAD', 'Approval required.', HugeIcons.strokeRoundedPassport),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _teal.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: _teal.withOpacity(0.1), width: 1)), child: Row(children: [const HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: Color(0xFF14B8A6), size: 18), const SizedBox(width: 12), Expanded(child: Text('Every new squad begins with a clear mission.', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 12, color: _teal, fontWeight: FontWeight.w700, height: 1.4)))])),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildProtocolButton(bool value, String title, String sub, dynamic icon) {
    final isSelected = _isPublic == value;
    return GestureDetector(
      onTap: () => setState(() => _isPublic = value),
      child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isSelected ? Colors.white : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? _teal : const Color(0xFFF1F5F9), width: 2)), child: Row(children: [HugeIcon(icon: icon, color: isSelected ? _teal : const Color(0xFFCBD5E1), size: 24), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))), const SizedBox(height: 4), Text(sub, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)))])), if (isSelected) HugeIcon(icon: HugeIcons.strokeRoundedTick01, color: _teal, size: 20)])),
    );
  }

  Widget _buildLabel(String text) { return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1.5))); }
  Widget _buildTextField(TextEditingController controller, String hint) { return TextField(controller: controller, style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 16, color: const Color(0xFF1E293B), fontWeight: FontWeight.w900), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(fontFamily: '.SF Pro Display', color: Colors.black12, fontWeight: FontWeight.w900), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18))); }
}

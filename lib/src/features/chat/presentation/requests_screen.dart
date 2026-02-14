import 'package:bro_app/src/features/chat/presentation/chat_screen.dart';
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  Future<void> _respondToRequest(String conversationId, bool accept) async {
    try {
      debugPrint('Responding to request: $conversationId, accept: $accept');
      if (accept) {
        final response = await Supabase.instance.client
            .from('conversations')
            .update({'status': 'accepted'})
            .eq('id', conversationId)
            .select();
        
        debugPrint('Accept response: $response');
        if (response.isEmpty) {
          debugPrint('Warning: Update returned empty. Likely RLS block.');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to accept. RLS permission error?')));
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection accepted! Chat is open. ⚡️')));
        }
      } else {
        await Supabase.instance.client
            .from('conversations')
            .delete()
            .eq('id', conversationId);
            
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request removed.')));
        }
      }
      setState(() {}); // Refresh list
    } catch (e) {
      debugPrint('Error responding: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser!.id;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text('Connection Requests', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
       leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // Fetch pending requests where I am the TARGET (user2 usually, or check both if logic allows, 
        // but typically initiator is user1. My previous logic set initiator_id, so let's use that.)
        future: Supabase.instance.client
            .from('conversations')
            .select('*, user1:user1_id(username, avatar_url), user2:user2_id(username, avatar_url)')
            .eq('status', 'pending')
            .neq('initiator_id', myId), // Show only incoming requests
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2DD4BF)));
          }
          
          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.white10),
                   const SizedBox(height: 16),
                   Text(
                     'No pending requests.',
                     style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
                   ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              // Determine which user object is the "other" person
              // Since I am not the initiator, the initiator must be the other person to show.
              final initiatorId = req['initiator_id'];
              final isUser1Initiator = initiatorId == req['user1_id'];
              final otherUser = isUser1Initiator ? req['user1'] : req['user2'];
              
              final username = otherUser['username'] ?? 'Bro';
              final avatarUrl = otherUser['avatar_url'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Determine the ID of the person who sent the request (the other user)
                          // Since I am viewing this, I am not the initiator. The initiator is the other person.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => PublicProfileScreen(userId: initiatorId),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              backgroundColor: const Color(0xFF2DD4BF),
                              child: avatarUrl == null ? const Icon(Icons.person, color: Colors.black) : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(username, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const Text('Wants to connect', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () => _respondToRequest(req['id'], false),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.check, color: Color(0xFF2DD4BF)),
                      onPressed: () => _respondToRequest(req['id'], true),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

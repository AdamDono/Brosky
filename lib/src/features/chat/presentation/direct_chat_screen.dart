import 'dart:async';
import 'dart:io' show File, Directory;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'voice_call_screen.dart';
import 'voice_message_bubble.dart';

class DirectChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerUsername;
  final String? partnerAvatar;

  const DirectChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerUsername,
    this.partnerAvatar,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _messageSubscription;
  bool _isLoading = true;

  // Audio recording state variables
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;

  // Presence state variables
  StreamSubscription? _partnerPresenceSubscription;
  String? _partnerLastSeen;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _setupMessageListener();
    _setupPartnerPresenceListener();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _setupPartnerPresenceListener() {
    _partnerPresenceSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final partnerProf = data.firstWhere(
              (p) => p['id'] == widget.partnerId,
              orElse: () => <String, dynamic>{},
            );
            if (partnerProf.isNotEmpty) {
              setState(() {
                _partnerLastSeen = partnerProf['last_seen_at'];
              });
            }
          }
        });
  }

  bool _isPartnerOnline() {
    if (_partnerLastSeen == null) return false;
    try {
      final lastSeen = DateTime.parse(_partnerLastSeen!);
      final difference = DateTime.now().toUtc().difference(lastSeen);
      return difference.inSeconds < 60;
    } catch (_) {
      return false;
    }
  }

  void _setupMessageListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _messageSubscription = Supabase.instance.client
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .listen((data) {
          final filtered = data.where((msg) {
            return (msg['sender_id'] == user.id && msg['receiver_id'] == widget.partnerId) ||
                   (msg['sender_id'] == widget.partnerId && msg['receiver_id'] == user.id);
          }).toList();

          if (mounted) {
            setState(() {
              _messages = filtered;
              _isLoading = false;
            });

            // Mark any new incoming messages as read
            final unreadIncoming = filtered.where((m) => m['receiver_id'] == user.id && m['is_read'] == false).toList();
            if (unreadIncoming.isNotEmpty) {
              _markMessagesAsRead();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }
        }, onError: (err) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
  }

  Future<void> _markMessagesAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('direct_messages')
          .update({'is_read': true})
          .eq('receiver_id', user.id)
          .eq('sender_id', widget.partnerId)
          .eq('is_read', false);
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _partnerPresenceSubscription?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _isSending = true);
    try {
      await Supabase.instance.client.from('direct_messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.partnerId,
        'content': content,
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      debugPrint('Microphone permission result: $hasPermission');
      
      if (hasPermission) {
        String path = '';
        if (!kIsWeb) {
          final tempDir = Directory.systemTemp;
          path = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        
        if (mounted) {
          setState(() {
            _isRecording = true;
            _recordingPath = path;
            _recordingDuration = 0;
          });
          _startRecordingTimer();
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.mic_off_rounded, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text('Microphone Blocked'),
                ],
              ),
              content: const Text(
                'Microphone access is blocked or disabled (common on non-localhost HTTP sites). '
                'Would you like to send a simulated Voice Note to test player features and waveform layout?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _sendMockVoiceNote();
                  },
                  child: const Text('Send Simulated Note', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
    }
  }

  Future<void> _sendMockVoiceNote() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    setState(() => _isSending = true);
    try {
      // Public sample audio track
      const mockAudioUrl = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
      
      await Supabase.instance.client.from('direct_messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.partnerId,
        'content': '[voice_note]$mockAudioUrl',
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending mock voice note: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration++;
        });
      }
    });
  }

  void _cancelRecording() async {
    _recordingTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null && !kIsWeb) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = 0;
      });
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null && mounted) {
        setState(() {
          _isRecording = false;
          _isSending = true;
        });
        await _uploadVoiceNote(path);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isSending = false;
        });
      }
    }
  }

  Future<void> _uploadVoiceNote(String path) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'voice_notes/${user.id}_$timestamp.m4a';
      
      Uint8List bytes;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        bytes = response.bodyBytes;
      } else {
        bytes = await File(path).readAsBytes();
      }
      
      await Supabase.instance.client.storage
          .from('post_images')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(contentType: 'audio/mpeg'));
          
      final publicUrl = Supabase.instance.client.storage
          .from('post_images')
          .getPublicUrl(fileName);
          
      await Supabase.instance.client.from('direct_messages').insert({
        'sender_id': user.id,
        'receiver_id': widget.partnerId,
        'content': '[voice_note]$publicUrl',
      });
      
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error uploading voice note: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _recordingPath = null;
          _recordingDuration = 0;
        });
      }
    }
  }

  String _formatRecordingDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not authenticated')));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1E293B)), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                    image: widget.partnerAvatar != null ? DecorationImage(image: NetworkImage(widget.partnerAvatar!), fit: BoxFit.cover) : null,
                  ),
                  child: widget.partnerAvatar == null ? const Icon(Icons.person, color: Colors.black26, size: 18) : null,
                ),
                if (_isPartnerOnline())
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.partnerUsername, 
                  style: const TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 1),
                Text(
                  _isPartnerOnline() ? 'Active now' : 'Offline', 
                  style: TextStyle(
                    fontFamily: '.SF Pro Display', 
                    fontSize: 10, 
                    fontWeight: FontWeight.w600,
                    color: _isPartnerOnline() ? const Color(0xFF14B8A6) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: Color(0xFF14B8A6), size: 26),
            tooltip: 'Voice Call',
            onPressed: () {
              final myId = Supabase.instance.client.auth.currentUser!.id;
              final ids = [myId, widget.partnerId]..sort();
              final roomId = 'bro_call_${ids[0]}_${ids[1]}';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VoiceCallScreen(
                    callId: roomId,
                    myUserId: myId,
                    myUserName: Supabase.instance.client.auth.currentUser!.email ?? myId,
                    otherUserName: widget.partnerUsername,
                    isCaller: true,
                    partnerId: widget.partnerId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = _messages[idx];
                      final isMe = msg['sender_id'] == user.id;
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final createdAt = DateTime.parse(message['created_at']);
    const _primaryColor = Color(0xFF14B8A6);
    
    final content = message['content'] as String? ?? '';
    if (content.startsWith('[voice_note]')) {
      final audioUrl = content.substring('[voice_note]'.length);
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              VoiceMessageBubble(audioUrl: audioUrl, isMe: isMe),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  timeago.format(createdAt), 
                  style: TextStyle(fontFamily: '.SF Pro Display', color: const Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _primaryColor : Colors.white,
          border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: isMe ? [BoxShadow(color: _primaryColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message['content'] ?? '', 
              style: TextStyle(fontFamily: '.SF Pro Display', color: isMe ? Colors.white : const Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w400, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              timeago.format(createdAt), 
              style: TextStyle(fontFamily: '.SF Pro Display', color: isMe ? Colors.white.withOpacity(0.7) : const Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    const _primaryColor = Color(0xFF14B8A6);
    final isTextEmpty = _messageController.text.trim().isEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.04), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: _isRecording
            ? Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
                    onPressed: _cancelRecording,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recording ${_formatRecordingDuration(_recordingDuration)}',
                    style: const TextStyle(
                      fontFamily: '.SF Pro Display',
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _stopAndSendRecording,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController, 
                      style: const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF1E293B), fontSize: 15), 
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Message...', 
                        hintStyle: const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF94A3B8), fontSize: 15), 
                        filled: true, 
                        fillColor: const Color(0xFFF1F5F9), 
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)
                      )
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _isSending
                        ? null
                        : (isTextEmpty ? _startRecording : _sendMessage),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: _isSending 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(
                                isTextEmpty ? Icons.mic_rounded : Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

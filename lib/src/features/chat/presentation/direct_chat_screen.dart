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
import 'package:bro_app/src/features/feed/presentation/public_profile_screen.dart';
import 'voice_call_screen.dart';
import 'voice_message_bubble.dart';
import 'package:bro_app/src/core/theme/app_theme.dart';

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

  // Typing indicator state
  bool _partnerIsTyping = false;
  Timer? _typingDebounce;
  bool _amTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _setupMessageListener();
    _setupPartnerPresenceListener();
    _setupPartnerTypingListener();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
    _broadcastTyping();
  }

  Future<void> _broadcastTyping() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (!_amTyping) {
      _amTyping = true;
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'typing_with': widget.partnerId})
            .eq('id', user.id);
      } catch (_) {}
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () async {
      _amTyping = false;
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'typing_with': null})
            .eq('id', user.id);
      } catch (_) {}
    });
  }

  Future<void> _clearTyping() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _typingDebounce?.cancel();
    _amTyping = false;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'typing_with': null})
          .eq('id', user.id);
    } catch (_) {}
  }

  void _setupPartnerTypingListener() {
    Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (!mounted) return;
          final partner = data.firstWhere(
            (p) => p['id'] == widget.partnerId,
            orElse: () => <String, dynamic>{},
          );
          if (partner.isNotEmpty) {
            final typingWith = partner['typing_with'];
            final myId = Supabase.instance.client.auth.currentUser?.id;
            final isTypingToMe = typingWith == myId;
            if (_partnerIsTyping != isTypingToMe && mounted) {
              setState(() => _partnerIsTyping = isTypingToMe);
            }
          }
        });
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
    _clearTyping();
    _typingDebounce?.cancel();
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
    _clearTyping();
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

  Future<void> _deleteMessage(String messageId) async {
    try {
      await Supabase.instance.client
          .from('direct_messages')
          .update({'is_deleted': true})
          .eq('id', messageId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  void _showDeleteSheet(String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Delete Message', style: TextStyle(fontFamily: '.SF Pro Display', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text('This message will be removed for everyone.', style: TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF64748B), fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteMessage(messageId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Delete', style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF64748B), fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
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
      backgroundColor: context.broColors.bg,
      appBar: AppBar(
        backgroundColor: context.broColors.card,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: context.broColors.border, width: 1)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 20, color: context.broColors.text), onPressed: () => Navigator.pop(context)),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PublicProfileScreen(userId: widget.partnerId),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Stack(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.broColors.border,
                    border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                    image: widget.partnerAvatar != null ? DecorationImage(image: NetworkImage(widget.partnerAvatar!), fit: BoxFit.cover) : null,
                  ),
                  child: widget.partnerAvatar == null ? Icon(Icons.person, color: context.broColors.subtext, size: 18) : null,
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
                        border: Border.all(color: context.isDark ? context.broColors.card : Colors.white, width: 2),
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
                  style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w700, fontSize: 15, color: context.broColors.text),
                ),
                const SizedBox(height: 1),
                Text(
                  _isPartnerOnline() ? 'Active now' : 'Offline', 
                  style: TextStyle(
                    fontFamily: '.SF Pro Display', 
                    fontSize: 10, 
                    fontWeight: FontWeight.w600,
                    color: _isPartnerOnline() ? const Color(0xFF14B8A6) : context.broColors.subtext,
                  ),
                ),
              ],
            ),
          ],
        ),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_partnerIsTyping ? 1 : 0),
                    itemBuilder: (ctx, idx) {
                      if (_partnerIsTyping && idx == _messages.length) {
                        return _buildTypingBubble();
                      }
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

  String _formatActualTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final timeStr = '$displayHour:$minute $period';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(localTime.year, localTime.month, localTime.day);
    
    if (messageDate == today) {
      return timeStr;
    } else if (today.difference(messageDate).inDays == 1) {
      return 'Yesterday, $timeStr';
    } else {
      return '${localTime.day}/${localTime.month}/${localTime.year}, $timeStr';
    }
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.broColors.card,
          border: Border.all(color: context.broColors.border, width: 1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(delay: 0),
            const SizedBox(width: 4),
            _TypingDot(delay: 150),
            const SizedBox(width: 4),
            _TypingDot(delay: 300),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final isDeleted = message['is_deleted'] == true;
    final createdAt = DateTime.parse(message['created_at']);
    const _primaryColor = Color(0xFF14B8A6);
    final isRead = message['is_read'] == true;

    // Deleted message placeholder
    if (isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.broColors.inputFill,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 20),
            ),
          ),
          child: Text(
            '🚫  This message was removed',
            style: TextStyle(
              fontFamily: '.SF Pro Display',
              color: context.broColors.subtext,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onDoubleTap: () => _toggleDefaultReaction(message),
                    onLongPress: () => _showReactionPicker(message),
                    child: VoiceMessageBubble(audioUrl: audioUrl, isMe: isMe),
                  ),
                  if (message['reaction'] != null)
                    _buildReactionBadge(message['reaction'] as String, isMe),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _formatActualTime(createdAt), 
                  style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.subtext, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onDoubleTap: () => _toggleDefaultReaction(message),
            onLongPress: () {
              if (isMe) {
                _showDeleteSheet(message['id']);
              } else {
                _showReactionPicker(message);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? _primaryColor : context.broColors.card,
                border: isMe ? null : Border.all(color: context.broColors.border, width: 1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: isMe 
                  ? [BoxShadow(color: _primaryColor.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] 
                  : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message['content'] ?? '', 
                    style: TextStyle(fontFamily: '.SF Pro Display', color: isMe ? Colors.white : context.broColors.text, fontSize: 15, fontWeight: FontWeight.w400, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatActualTime(createdAt), 
                        style: TextStyle(fontFamily: '.SF Pro Display', color: isMe ? Colors.white.withOpacity(0.7) : context.broColors.subtext, fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: isRead
                              ? const Color(0xFFB2F0EC)
                              : Colors.white.withOpacity(0.6),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message['reaction'] != null)
            _buildReactionBadge(message['reaction'] as String, isMe),
        ],
      ),
    );
  }

  Widget _buildReactionBadge(String reaction, bool isMe) {
    return Positioned(
      bottom: 2,
      right: isMe ? 12 : null,
      left: isMe ? null : 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: context.broColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.broColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          reaction,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Future<void> _setReaction(String messageId, String? reaction) async {
    try {
      await Supabase.instance.client
          .from('direct_messages')
          .update({'reaction': reaction})
          .eq('id', messageId);
    } catch (e) {
      debugPrint('Error setting reaction: $e');
    }
  }

  Future<void> _toggleDefaultReaction(Map<String, dynamic> message) async {
    final currentReaction = message['reaction'];
    if (currentReaction == '👊') {
      await _setReaction(message['id'], null);
    } else {
      await _setReaction(message['id'], '👊');
    }
  }

  void _showReactionPicker(Map<String, dynamic> message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['👊', '🔥', '💯', '❤️', '😂', '😮'].map((emoji) {
                final isSelected = message['reaction'] == emoji;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    if (isSelected) {
                      _setReaction(message['id'], null);
                    } else {
                      _setReaction(message['id'], emoji);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
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
        color: context.broColors.card, 
        border: Border(top: BorderSide(color: context.broColors.border, width: 1)),
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
                      style: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.text, fontSize: 15), 
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Message...', 
                        hintStyle: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.subtext, fontSize: 15), 
                        filled: true, 
                        fillColor: context.broColors.inputFill, 
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

/// Animated bouncing dot for the typing indicator bubble.
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _animation.value),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF94A3B8),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

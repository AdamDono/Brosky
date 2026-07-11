import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  // Premium static waveform heights
  static const List<double> _waveformHeights = [
    6, 12, 18, 14, 8, 16, 22, 10, 14, 18, 24, 16, 10, 14, 20, 12, 6, 10, 16, 8, 12, 18, 10, 6
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    
    // Warm up the source URL
    _audioPlayer.setSource(UrlSource(widget.audioUrl)).catchError((e) {
      debugPrint('Error setting source URL: $e');
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          // If completed, reset to start
          if (state == PlayerState.completed) {
            _position = Duration.zero;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryTeal = const Color(0xFF14B8A6);
    
    final double progressFraction = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    final bubbleColor = widget.isMe ? primaryTeal : const Color(0xFFE2E8F0);
    final secondaryColor = widget.isMe ? Colors.white70 : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: widget.isMe ? const Radius.circular(20) : const Radius.circular(4),
          bottomRight: widget.isMe ? const Radius.circular(4) : const Radius.circular(20),
        ),
      ),
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause Circle Action Button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMe ? Colors.white : primaryTeal,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? primaryTeal : Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Waveform bars and timeline labels
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 24,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: List.generate(_waveformHeights.length, (index) {
                    final double barLimit = index / _waveformHeights.length;
                    final bool isPlayed = progressFraction >= barLimit;
                    
                    return Container(
                      width: 2.5,
                      height: _waveformHeights[index],
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: isPlayed
                            ? (widget.isMe ? Colors.white : primaryTeal)
                            : (widget.isMe ? Colors.white38 : Colors.black12),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: TextStyle(
                      fontFamily: '.SF Pro Display',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 80),
                  Text(
                    _duration == Duration.zero ? '...' : _formatDuration(_duration),
                    style: TextStyle(
                      fontFamily: '.SF Pro Display',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

class VoiceCallScreen extends StatelessWidget {
  final String callId;
  final String myUserId;
  final String myUserName;
  final String otherUserName;
  final bool isGroupCall;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    required this.myUserId,
    required this.myUserName,
    required this.otherUserName,
    this.isGroupCall = false,
  });

  // ── ZegoCloud credentials ────────────────────────────────────────────────
  static const int _appId = 626459684;
  static const String _appSign =
      'c87f43b04893313468f98e5b258c9c41cd6e9cd6a085f65b5b887b365e4dab06';

  @override
  Widget build(BuildContext context) {
    // If running in a web browser, load the elegant web fallback UI instead
    // of Zego, since the mobile Zego package relies on dart:io Platform calls.
    if (kIsWeb) {
      return WebMockCallScreen(otherUserName: otherUserName);
    }

    final config = isGroupCall
        ? ZegoUIKitPrebuiltCallConfig.groupVoiceCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    // Voice-only: camera off
    config.turnOnCameraWhenJoining = false;

    // Bottom bar: Mute, Speaker, End Call
    config.bottomMenuBar.buttons = [
      ZegoCallMenuBarButtonName.toggleMicrophoneButton,
      ZegoCallMenuBarButtonName.switchAudioOutputButton,
      ZegoCallMenuBarButtonName.hangUpButton,
    ];

    // Top bar: show who you're calling
    config.topMenuBar.title = otherUserName;
    config.topMenuBar.isVisible = true;

    return ZegoUIKitPrebuiltCall(
      appID: _appId,
      appSign: _appSign,
      callID: callId,
      userID: myUserId,
      userName: myUserName,
      config: config,
      events: ZegoUIKitPrebuiltCallEvents(
        onHangUpConfirmation: (event, defaultAction) async {
          // Pop back to previous screen when call ends
          if (event.context.mounted) Navigator.of(event.context).pop();
          return true;
        },
      ),
    );
  }
}

// ── Elegant Mock Calling Interface for Web Preview ─────────────────────────
class WebMockCallScreen extends StatefulWidget {
  final String otherUserName;
  const WebMockCallScreen({super.key, required this.otherUserName});

  @override
  State<WebMockCallScreen> createState() => _WebMockCallScreenState();
}

class _WebMockCallScreenState extends State<WebMockCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timer;
  Timer? _ringTimeoutTimer;
  int _seconds = 0;
  bool _isMuted = false;
  bool _isSpeaker = false;
  String _statusText = 'Ringing...';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // If no action is taken, ring for 30 seconds then time out
    _ringTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isConnected && _statusText == 'Ringing...') {
        setState(() {
          _statusText = 'No Answer';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  void _simulateAnswer() {
    if (_isConnected) return;
    _ringTimeoutTimer?.cancel();
    setState(() {
      _isConnected = true;
      _statusText = '00:00';
    });
    _startTimer();
  }

  void _simulateBusy() {
    if (_isConnected) return;
    _ringTimeoutTimer?.cancel();
    setState(() {
      _statusText = 'Busy';
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _simulateOffline() {
    if (_isConnected) return;
    _ringTimeoutTimer?.cancel();
    setState(() {
      _statusText = 'User Offline';
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
          _statusText = _formatDuration(_seconds);
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _ringTimeoutTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryTeal = const Color(0xFF14B8A6);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D), // Deep Midnight Blue
      body: Stack(
        children: [
          // Background Gradient Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    primaryTeal.withOpacity(0.08),
                    const Color(0xFF0A0F1D),
                  ],
                ),
              ),
            ),
          ),
          
          // Call UI content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Header info + Debug Simulator Panel
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Column(
                    children: [
                      // Simulator Control Panel
                      if (!_isConnected && _statusText == 'Ringing...')
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: primaryTeal.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text(
                                'SIMULATE:',
                                style: TextStyle(
                                  color: primaryTeal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              _buildSimButton('ANSWER', _simulateAnswer, primaryTeal),
                              _buildSimButton('BUSY', _simulateBusy, Colors.orangeAccent),
                              _buildSimButton('OFFLINE', _simulateOffline, Colors.redAccent),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white24,
                        size: 16,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'END-TO-END ENCRYPTED',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Avatar and Call Info
                Column(
                  children: [
                    // Pulsing Ring around Avatar
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryTeal.withOpacity(0.04),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryTeal.withOpacity(0.08),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFF1E293B),
                            child: Text(
                              widget.otherUserName.isNotEmpty
                                  ? widget.otherUserName[0].toUpperCase()
                                  : 'B',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_statusText == 'Ringing...')
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryTeal,
                            ),
                          ),
                        Text(
                          _statusText,
                          style: TextStyle(
                            fontSize: 16,
                            color: _statusText == 'Ringing...'
                                ? Colors.white70
                                : (_statusText == 'Busy' || _statusText == 'User Offline' || _statusText == 'No Answer'
                                    ? Colors.redAccent
                                    : primaryTeal),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Web Info Alert + Calling Actions
                Column(
                  children: [
                    // Info Alert Box
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: primaryTeal, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Web Preview: Click the SIMULATE controls at the top to test answering, busy, or offline behaviors on the web client.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Call control buttons
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Mute Button
                          _buildRoundButton(
                            icon: _isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            isActive: _isMuted,
                            onTap: () {
                              setState(() => _isMuted = !_isMuted);
                            },
                          ),

                          // Hang Up Button (Red)
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent,
                                    blurRadius: 15,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),

                          // Speaker Button
                          _buildRoundButton(
                            icon: _isSpeaker
                                ? Icons.volume_up_rounded
                                : Icons.volume_down_rounded,
                            isActive: _isSpeaker,
                            onTap: () {
                              setState(() => _isSpeaker = !_isSpeaker);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimButton(String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5), width: 1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.white : Colors.white.withOpacity(0.08),
        ),
        child: Icon(
          icon,
          color: isActive ? const Color(0xFF0A0F1D) : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

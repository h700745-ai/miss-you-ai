import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/services/voice_message_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VoiceMessageScreen extends StatefulWidget {
  final String coupleId;

  const VoiceMessageScreen({super.key, required this.coupleId});

  @override
  State<VoiceMessageScreen> createState() => _VoiceMessageScreenState();
}

class _VoiceMessageScreenState extends State<VoiceMessageScreen> {
  final _service = VoiceMessageService();
  final _player = AudioPlayer();
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;

  String? _playingMessageId;

  @override
  void dispose() {
    _timer?.cancel();
    _service.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _timer?.cancel();
      final path = await _service.stopRecording();
      setState(() => _isRecording = false);

      if (path == null) {
        _showSnack('Recording too short');
        _recordDuration = Duration.zero;
        return;
      }

      final duration = _recordDuration.inSeconds;
      _recordDuration = Duration.zero;

      try {
        await _service.uploadAndSend(
          coupleId: widget.coupleId,
          localFilePath: path,
          durationSeconds: duration,
        );
      } catch (e) {
        _showSnack('Failed to send: $e');
      }
    } else {
      try {
        await _service.startRecording();
        setState(() {
          _isRecording = true;
          _recordDuration = Duration.zero;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        });
      } catch (e) {
        _showSnack('$e');
      }
    }
  }

  Future<void> _togglePlay(VoiceMessage message) async {
    if (_playingMessageId == message.id) {
      await _player.stop();
      setState(() => _playingMessageId = null);
    } else {
      await _player.play(UrlSource(message.audioUrl));
      setState(() => _playingMessageId = message.id);
      _player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _playingMessageId = null);
      });
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Messages')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<VoiceMessage>>(
              stream: _service.streamVoiceMessages(widget.coupleId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No voice messages yet. Record one below 💌'),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isMine = message.senderId == _currentUserId;
                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isMine
                              ? const LinearGradient(colors: [
                                  Color(0xFFFF6B9D),
                                  Color(0xFFFF8FAB),
                                ])
                              : null,
                          color: isMine ? null : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _playingMessageId == message.id
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                color: isMine ? Colors.white : Colors.pink,
                              ),
                              onPressed: () => _togglePlay(message),
                            ),
                            Text(
                              _formatDuration(message.durationSeconds),
                              style: TextStyle(
                                color: isMine ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_isRecording)
                  Text(
                    _formatDuration(_recordDuration.inSeconds),
                    style: const TextStyle(fontSize: 18, color: Colors.red),
                  ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isRecording
                            ? [Colors.red, Colors.redAccent]
                            : [
                                const Color(0xFFFF6B9D),
                                const Color(0xFFFF8FAB),
                              ],
                      ),
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 32,
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
}

class VoiceMessageEntry extends StatelessWidget {
  const VoiceMessageEntry({super.key});

  Future<String?> _fetchCoupleId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['coupleId'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _fetchCoupleId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final coupleId = snapshot.data;
        if (coupleId == null) {
          return const Scaffold(
            body: Center(child: Text('Couple not linked yet')),
          );
        }
        return VoiceMessageScreen(coupleId: coupleId);
      },
    );
  }
}

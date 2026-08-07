import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VoiceMessage {
  final String id;
  final String senderId;
  final String audioUrl;
  final int durationSeconds;
  final DateTime createdAt;

  VoiceMessage({
    required this.id,
    required this.senderId,
    required this.audioUrl,
    required this.durationSeconds,
    required this.createdAt,
  });

  factory VoiceMessage.fromFirestore(Map<String, dynamic> data, String id) {
    return VoiceMessage(
      id: id,
      senderId: data['senderId'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      durationSeconds: data['durationSeconds'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class VoiceMessageService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _recorder = AudioRecorder();
  final _uuid = const Uuid();

  DateTime? _recordingStartTime;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (!await hasPermission()) {
      throw Exception('Microphone permission denied');
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${_uuid.v4()}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _recordingStartTime = DateTime.now();
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    final duration = _recordingStartTime == null
        ? 0
        : DateTime.now().difference(_recordingStartTime!).inSeconds;
    _recordingStartTime = null;
    if (path == null || duration < 1) return null;
    return path;
  }

  Future<void> cancelRecording() async {
    final path = await _recorder.stop();
    _recordingStartTime = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> uploadAndSend({
    required String coupleId,
    required String localFilePath,
    required int durationSeconds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final file = File(localFilePath);
    final storageRef = _storage
        .ref()
        .child('couples/$coupleId/voice_messages/${_uuid.v4()}.m4a');

    await storageRef.putFile(
      file,
      SettableMetadata(contentType: 'audio/m4a'),
    );
    final audioUrl = await storageRef.getDownloadURL();

    final message = VoiceMessage(
      id: '',
      senderId: user.uid,
      audioUrl: audioUrl,
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('voiceMessages')
        .add(message.toFirestore());

    if (await file.exists()) await file.delete();
  }

  Stream<List<VoiceMessage>> streamVoiceMessages(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('voiceMessages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => VoiceMessage.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  void dispose() {
    _recorder.dispose();
  }
}

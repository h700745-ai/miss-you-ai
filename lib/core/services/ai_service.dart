import 'dart:convert';
import 'package:dio/dio.dart';

/// Moods supported by the Love Letter Generator.
enum LetterMood {
  romantic,
  cute,
  flirty,
  emotional,
  apology,
  birthday,
  anniversary
}

extension LetterMoodX on LetterMood {
  String get label => switch (this) {
        LetterMood.romantic => 'Romantic',
        LetterMood.cute => 'Cute',
        LetterMood.flirty => 'Flirty',
        LetterMood.emotional => 'Emotional',
        LetterMood.apology => 'Apology',
        LetterMood.birthday => 'Birthday',
        LetterMood.anniversary => 'Anniversary',
      };

  String get emoji => switch (this) {
        LetterMood.romantic => '❤️',
        LetterMood.cute => '😊',
        LetterMood.flirty => '😉',
        LetterMood.emotional => '🥹',
        LetterMood.apology => '😔',
        LetterMood.birthday => '🎂',
        LetterMood.anniversary => '💍',
      };
}

enum LetterLanguage { english, hindi, hinglish }

extension LetterLanguageX on LetterLanguage {
  String get label => switch (this) {
        LetterLanguage.english => 'English',
        LetterLanguage.hindi => 'Hindi',
        LetterLanguage.hinglish => 'Hinglish',
      };
}

/// All AI calls in the app go through this single service so that:
/// - the API key lives in exactly one place (never in client code in prod —
///   see note at the bottom of this file)
/// - every feature (letters, chat coach, mood detection, date planner)
/// gets consistent error handling and retry logic.
class AIService {
  AIService._internal();
  static final AIService instance = AIService._internal();

  // IMPORTANT (read this before shipping):
  // Never ship a raw OpenAI key inside the Flutter client binary — anyone can
  // decompile the APK and extract it, then rack up charges on your account.
  // The correct architecture is:
  //   Flutter app --> Firebase Cloud Function (holds the key) --> OpenAI API
  // This service is written to call YOUR backend endpoint, not OpenAI directly.
  // Point _baseUrl at your deployed Cloud Function / backend base URL.
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://miss-you-worker.luck-love.workers.dev',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  /// Attach the Firebase ID token so the backend can verify the caller
  /// and enforce free-vs-premium usage limits server-side.
  void setAuthToken(String idToken) {
    _dio.options.headers['Authorization'] = 'Bearer $idToken';
  }

  /// Generates a love letter / message for the given mood + language.
  Future<String> generateLoveLetter({
    required LetterMood mood,
    required LetterLanguage language,
    String? context, // e.g. "we had a fight about him forgetting my birthday"
    String? partnerName,
  }) async {
    try {
      final response = await _dio.post('/generateLoveLetter', data: {
        'mood': mood.name,
        'language': language.name,
        'context': context,
        'partnerName': partnerName,
      });
      return response.data['text'] as String;
    } on DioException catch (e) {
      throw AIServiceException(_mapDioError(e));
    }
  }

  /// Relationship AI chat coach — helps write replies, gives advice,
  /// suggests surprises, helps resolve misunderstandings.
  Future<String> relationshipCoachReply({
    required String userMessage,
    required List<Map<String, String>> conversationHistory, // [{role, content}]
  }) async {
    try {
      final response = await _dio.post('/relationshipCoach', data: {
        'message': userMessage,
        'history': conversationHistory,
      });
      return response.data['reply'] as String;
    } on DioException catch (e) {
      throw AIServiceException(_mapDioError(e));
    }
  }

  /// Analyzes a batch of recent messages (only ever sent with explicit
  /// user permission — see MoodDetectionConsent flow) and returns a mood.
  Future<MoodResult> detectMood(List<String> recentMessages) async {
    try {
      final response = await _dio.post('/detectMood', data: {
        'messages': recentMessages,
      });
      return MoodResult.fromMap(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AIServiceException(_mapDioError(e));
    }
  }

  /// AI date planner — suggests virtual dates for long-distance couples.
  Future<List<DateIdea>> planDates({
    required String vibe, // e.g. "cozy", "adventurous", "budget-friendly"
    bool longDistance = true,
  }) async {
    try {
      final response = await _dio.post('/planDates', data: {
        'vibe': vibe,
        'longDistance': longDistance,
      });
      final list = response.data['ideas'] as List;
      return list
          .map((e) => DateIdea.fromMap(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw AIServiceException(_mapDioError(e));
    }
  }

  /// Daily surprise generator — good morning / good night / compliments / quotes.
  Future<String> generateDailySurprise(String type) async {
    try {
      final response = await _dio.post('/dailySurprise', data: {'type': type});
      return response.data['text'] as String;
    } on DioException catch (e) {
      throw AIServiceException(_mapDioError(e));
    }
  }

  /// Converts text to a natural voice message (returns a URL to the
  /// generated audio file in Firebase Storage).
  Future<String> textToSpeech({
    required String text,
    required String voice, // e.g. "male_warm", "female_soft"
  }) async {
    try {
      final response = await _dio.post('/textToSpeech', data: {
        'text': text,
        'voice': voice,
      });
      return response.data['audioUrl'] as String;
    } on DioException catch (e) {
      throw AIServiceException(_mapDioError(e));
    }
  }

  String _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your internet and try again.';
    }
    if (e.response?.statusCode == 429) {
      return 'You\'ve hit your daily AI limit. Upgrade to Premium for unlimited messages.';
    }
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Something went wrong. Please try again.';
  }
}

class AIServiceException implements Exception {
  final String message;
  AIServiceException(this.message);
  @override
  String toString() => message;
}

class MoodResult {
  final String mood; // happy, romantic, sad, stressed, calm, neutral
  final double confidence;
  final String? suggestedSupportMessage;

  MoodResult(
      {required this.mood,
      required this.confidence,
      this.suggestedSupportMessage});

  factory MoodResult.fromMap(Map<String, dynamic> map) {
    return MoodResult(
      mood: map['mood'] ?? 'neutral',
      confidence: (map['confidence'] ?? 0).toDouble(),
      suggestedSupportMessage: map['suggestedSupportMessage'],
    );
  }
}

class DateIdea {
  final String title;
  final String description;
  final String category; // movie, game, conversation, gift
  final String emoji;

  DateIdea({
    required this.title,
    required this.description,
    required this.category,
    required this.emoji,
  });

  factory DateIdea.fromMap(Map<String, dynamic> map) {
    return DateIdea(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      emoji: map['emoji'] ?? '💕',
    );
  }
}

/// Helper to safely decode backend JSON error bodies.
String prettyJson(Object obj) =>
    const JsonEncoder.withIndent('  ').convert(obj);

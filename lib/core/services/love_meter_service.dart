import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoveMeterService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ---------- Question banks ----------

  static const List<Map<String, dynamic>> syncQuizQuestions = [
    {
      'id': 'sq1',
      'question': 'Ideal weekend?',
      'options': [
        'Netflix & chill',
        'Outdoor adventure',
        'Trying new food',
        'Just sleeping in'
      ],
    },
    {
      'id': 'sq2',
      'question': 'Love language?',
      'options': [
        'Words of affirmation',
        'Quality time',
        'Physical touch',
        'Gifts'
      ],
    },
    {
      'id': 'sq3',
      'question': 'Dream vacation?',
      'options': ['Beach', 'Mountains', 'City exploring', 'Road trip'],
    },
    {
      'id': 'sq4',
      'question': 'Morning or night person?',
      'options': ['Morning', 'Night', 'Neither', 'Both, honestly'],
    },
    {
      'id': 'sq5',
      'question': 'Favorite way to show love?',
      'options': [
        'Cooking for them',
        'Surprise gifts',
        'Long hugs',
        'Deep conversations'
      ],
    },
  ];

  static const List<Map<String, String>> knowMeQuestions = [
    {'id': 'km1', 'question': "What's their favorite color?"},
    {'id': 'km2', 'question': "What's their comfort food?"},
    {'id': 'km3', 'question': "What's their biggest fear?"},
    {'id': 'km4', 'question': "What's their dream job?"},
    {'id': 'km5', 'question': "What's their favorite movie?"},
  ];

  static const List<String> dailyQuestions = [
    "What's one thing you're grateful for about us today?",
    "What made you smile today?",
    "If we could teleport anywhere right now, where would you go?",
    "What's a small thing I did recently that made you happy?",
    "What song reminds you of us?",
    "What's your favorite memory of us this month?",
    "What's something new you'd like us to try together?",
  ];

  String _todaysDailyQuestion() {
    final dayOfYear = int.parse(DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays
        .toString());
    return dailyQuestions[dayOfYear % dailyQuestions.length];
  }

  String _dateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ---------- Sync Quiz ----------

  Future<void> submitSyncQuizAnswers(
      String coupleId, Map<String, String> answers) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('syncQuiz')
        .collection('answers')
        .doc(uid)
        .set({
      'answers': answers,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<Map<String, dynamic>> streamSyncQuizResult(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('syncQuiz')
        .collection('answers')
        .snapshots()
        .map((snap) {
      if (snap.docs.length < 2) {
        return {'ready': false, 'submittedCount': snap.docs.length};
      }
      final docs = snap.docs;
      final answersA = Map<String, dynamic>.from(docs[0]['answers']);
      final answersB = Map<String, dynamic>.from(docs[1]['answers']);
      int matches = 0;
      for (final q in syncQuizQuestions) {
        if (answersA[q['id']] == answersB[q['id']]) matches++;
      }
      final score = (matches / syncQuizQuestions.length * 100).round();
      return {'ready': true, 'score': score, 'matches': matches};
    });
  }

  // ---------- Know Me ----------

  Future<void> submitKnowMeActualAnswers(
      String coupleId, Map<String, String> answers) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('knowMe')
        .collection('actualAnswers')
        .doc(uid)
        .set({'answers': answers, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> submitKnowMeGuesses(
      String coupleId, String aboutUid, Map<String, String> guesses) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('knowMe')
        .collection('guesses')
        .doc('${uid}_about_$aboutUid')
        .set({
      'guesserUid': uid,
      'aboutUid': aboutUid,
      'guesses': guesses,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getKnowMeActualAnswers(
      String coupleId, String uid) async {
    final doc = await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('knowMe')
        .collection('actualAnswers')
        .doc(uid)
        .get();
    return doc.data();
  }

  Stream<int?> streamKnowMeScore(
      String coupleId, String guesserUid, String aboutUid) {
    final guessRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('knowMe')
        .collection('guesses')
        .doc('${guesserUid}_about_$aboutUid');
    final actualRef = _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('knowMe')
        .collection('actualAnswers')
        .doc(aboutUid);

    return guessRef.snapshots().asyncMap((guessSnap) async {
      if (!guessSnap.exists) return null;
      final actualSnap = await actualRef.get();
      if (!actualSnap.exists) return null;
      final guesses = Map<String, dynamic>.from(guessSnap['guesses']);
      final actual = Map<String, dynamic>.from(actualSnap['answers']);
      int correct = 0;
      for (final q in knowMeQuestions) {
        final id = q['id'];
        final g = (guesses[id] ?? '').toString().trim().toLowerCase();
        final a = (actual[id] ?? '').toString().trim().toLowerCase();
        if (g.isNotEmpty && g == a) correct++;
      }
      return (correct / knowMeQuestions.length * 100).round();
    });
  }

  // ---------- Daily Question ----------

  String get todaysQuestion => _todaysDailyQuestion();

  Future<void> submitDailyAnswer(String coupleId, String answer) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');
    await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('dailyQuestion')
        .collection('entries')
        .doc(_dateKey())
        .set({
      'question': _todaysDailyQuestion(),
      'answers.$uid': answer,
      'answeredAt.$uid': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> streamTodaysDailyEntry(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('dailyQuestion')
        .collection('entries')
        .doc(_dateKey())
        .snapshots()
        .map((doc) => doc.data());
  }

  Future<int> getStreak(String coupleId) async {
    final entries = await _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('loveMeter')
        .doc('dailyQuestion')
        .collection('entries')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(60)
        .get();

    int streak = 0;
    DateTime expected = DateTime.now();
    for (final doc in entries.docs) {
      final answers = Map<String, dynamic>.from(doc.data()['answers'] ?? {});
      final expectedKey =
          '${expected.year}-${expected.month.toString().padLeft(2, '0')}-${expected.day.toString().padLeft(2, '0')}';
      if (doc.id != expectedKey) break;
      if (answers.length < 2) break;
      streak++;
      expected = expected.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

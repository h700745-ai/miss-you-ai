import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/love_meter_service.dart';

class LoveMeterScreen extends StatefulWidget {
  final String coupleId;

  const LoveMeterScreen({super.key, required this.coupleId});

  @override
  State<LoveMeterScreen> createState() => _LoveMeterScreenState();
}

class _LoveMeterScreenState extends State<LoveMeterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = LoveMeterService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String?> _getPartnerUid() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final coupleDoc = await FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .get();
    final members = List<String>.from(coupleDoc.data()?['membersUids'] ?? []);
    return members.firstWhere((id) => id != myUid, orElse: () => '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Love Meter'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sync Quiz'),
            Tab(text: 'Know Me'),
            Tab(text: 'Daily'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SyncQuizTab(coupleId: widget.coupleId, service: _service),
          _KnowMeTab(
            coupleId: widget.coupleId,
            service: _service,
            getPartnerUid: _getPartnerUid,
          ),
          _DailyQuestionTab(coupleId: widget.coupleId, service: _service),
        ],
      ),
    );
  }
}

// ---------------- Sync Quiz Tab ----------------

class _SyncQuizTab extends StatefulWidget {
  final String coupleId;
  final LoveMeterService service;

  const _SyncQuizTab({required this.coupleId, required this.service});

  @override
  State<_SyncQuizTab> createState() => _SyncQuizTabState();
}

class _SyncQuizTabState extends State<_SyncQuizTab> {
  final Map<String, String> _answers = {};
  bool _submitted = false;

  Future<void> _submit() async {
    if (_answers.length < LoveMeterService.syncQuizQuestions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer all questions first')),
      );
      return;
    }
    await widget.service.submitSyncQuizAnswers(widget.coupleId, _answers);
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return StreamBuilder<Map<String, dynamic>>(
        stream: widget.service.streamSyncQuizResult(widget.coupleId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data['ready'] != true) {
            return const Center(
              child: Text('Waiting for your partner to finish...'),
            );
          }
          return Center(
            child: Text(
              'You matched ${data['score']}%! 💕',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final q in LoveMeterService.syncQuizQuestions)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q['question'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final option in q['options'])
                    RadioListTile<String>(
                      title: Text(option),
                      value: option,
                      groupValue: _answers[q['id']],
                      onChanged: (val) =>
                          setState(() => _answers[q['id']] = val!),
                    ),
                ],
              ),
            ),
          ),
        ElevatedButton(onPressed: _submit, child: const Text('Submit Answers')),
      ],
    );
  }
}

// ---------------- Know Me Tab ----------------

class _KnowMeTab extends StatefulWidget {
  final String coupleId;
  final LoveMeterService service;
  final Future<String?> Function() getPartnerUid;

  const _KnowMeTab({
    required this.coupleId,
    required this.service,
    required this.getPartnerUid,
  });

  @override
  State<_KnowMeTab> createState() => _KnowMeTabState();
}

class _KnowMeTabState extends State<_KnowMeTab> {
  final Map<String, TextEditingController> _actualControllers = {};
  final Map<String, TextEditingController> _guessControllers = {};

  @override
  void initState() {
    super.initState();
    for (final q in LoveMeterService.knowMeQuestions) {
      _actualControllers[q['id']!] = TextEditingController();
      _guessControllers[q['id']!] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _actualControllers.values) {
      c.dispose();
    }
    for (final c in _guessControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveActualAnswers() async {
    final answers = {
      for (final e in _actualControllers.entries) e.key: e.value.text.trim()
    };
    await widget.service.submitKnowMeActualAnswers(widget.coupleId, answers);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved your answers')));
    }
  }

  Future<void> _submitGuesses(String partnerUid) async {
    final guesses = {
      for (final e in _guessControllers.entries) e.key: e.value.text.trim()
    };
    await widget.service
        .submitKnowMeGuesses(widget.coupleId, partnerUid, guesses);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<String?>(
      future: widget.getPartnerUid(),
      builder: (context, partnerSnap) {
        if (!partnerSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final partnerUid = partnerSnap.data;
        if (partnerUid == null || partnerUid.isEmpty) {
          return const Center(child: Text('Couple not linked yet'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('About you (your real answers)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final q in LoveMeterService.knowMeQuestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _actualControllers[q['id']],
                  decoration: InputDecoration(
                    labelText: q['question'],
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: _saveActualAnswers,
              child: const Text('Save My Answers'),
            ),
            const Divider(height: 32),
            Text('Guess about your partner',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final q in LoveMeterService.knowMeQuestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _guessControllers[q['id']],
                  decoration: InputDecoration(
                    labelText: q['question'],
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: () => _submitGuesses(partnerUid),
              child: const Text('Submit Guesses'),
            ),
            const SizedBox(height: 16),
            StreamBuilder<int?>(
              stream: widget.service
                  .streamKnowMeScore(widget.coupleId, myUid, partnerUid),
              builder: (context, scoreSnap) {
                if (!scoreSnap.hasData || scoreSnap.data == null) {
                  return const SizedBox.shrink();
                }
                return Center(
                  child: Text(
                    'You know them ${scoreSnap.data}% right! 💖',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ---------------- Daily Question Tab ----------------

class _DailyQuestionTab extends StatefulWidget {
  final String coupleId;
  final LoveMeterService service;

  const _DailyQuestionTab({required this.coupleId, required this.service});

  @override
  State<_DailyQuestionTab> createState() => _DailyQuestionTabState();
}

class _DailyQuestionTabState extends State<_DailyQuestionTab> {
  final _controller = TextEditingController();
  int? _streak;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    final streak = await widget.service.getStreak(widget.coupleId);
    if (mounted) setState(() => _streak = streak);
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    await widget.service
        .submitDailyAnswer(widget.coupleId, _controller.text.trim());
    _controller.clear();
    _loadStreak();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_streak != null)
          Center(
            child: Chip(
              label: Text('🔥 $_streak day streak'),
              backgroundColor: Colors.pink.shade50,
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.service.todaysQuestion,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Your answer...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: _submit, child: const Text('Submit')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<Map<String, dynamic>?>(
          stream: widget.service.streamTodaysDailyEntry(widget.coupleId),
          builder: (context, snapshot) {
            final data = snapshot.data;
            if (data == null) return const SizedBox.shrink();
            final answers = Map<String, dynamic>.from(data['answers'] ?? {});
            final partnerEntry = answers.entries
                .where((e) => e.key != myUid)
                .cast<MapEntry<String, dynamic>?>()
                .firstWhere((_) => true, orElse: () => null);
            if (partnerEntry == null) {
              return const Text("Waiting for your partner's answer...");
            }
            return Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Partner's answer: ${partnerEntry.value}"),
              ),
            );
          },
        ),
      ],
    );
  }
}
class LoveMeterEntry extends StatelessWidget {
  const LoveMeterEntry({super.key});

  Future<String?> _fetchCoupleId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
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
        return LoveMeterScreen(coupleId: coupleId);
      },
    );
  }
}
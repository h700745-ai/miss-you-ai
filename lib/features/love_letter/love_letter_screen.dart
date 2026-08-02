import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/ai_service.dart';
import '../../core/theme/app_colors.dart';

class LoveLetterScreen extends StatefulWidget {
  final String? partnerName;
  const LoveLetterScreen({super.key, this.partnerName});

  @override
  State<LoveLetterScreen> createState() => _LoveLetterScreenState();
}

class _LoveLetterScreenState extends State<LoveLetterScreen> {
  LetterMood _selectedMood = LetterMood.romantic;
  LetterLanguage _selectedLanguage = LetterLanguage.hinglish;
  final _contextController = TextEditingController();

  bool _loading = false;
  String? _generatedText;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _generatedText = null;
    });
    try {
      // Attach the current Firebase login token so the backend can
      // verify who's calling -- without this every AI request is
      // rejected as unauthenticated ("Session expired").
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You need to be logged in to use this.');
      }
      final idToken = await user.getIdToken();
      AIService.instance.setAuthToken(idToken!);

      final text = await AIService.instance.generateLoveLetter(
        mood: _selectedMood,
        language: _selectedLanguage,
        context: _contextController.text.trim().isEmpty
            ? null
            : _contextController.text.trim(),
        partnerName: widget.partnerName,
      );
      setState(() => _generatedText = text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _contextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Love Letter Generator')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.loveGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How are you feeling? 💌',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 14),
                      _buildMoodPicker(),
                      const SizedBox(height: 20),
                      Text(
                        'Language',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 10),
                      _buildLanguagePicker(),
                      const SizedBox(height: 20),
                      Text(
                        'Add context (optional)',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _contextController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText:
                              'e.g. "It\'s our 1 year anniversary" or "I forgot to call last night"',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _generate,
                          icon: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(_loading
                              ? 'Writing from the heart...'
                              : 'Generate Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.white)),
                ],
                if (_generatedText != null) ...[
                  const SizedBox(height: 20),
                  _buildResultCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }

  Widget _buildMoodPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: LetterMood.values.map((mood) {
        final selected = mood == _selectedMood;
        return GestureDetector(
          onTap: () => setState(() => _selectedMood = mood),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '${mood.emoji} ${mood.label}',
              style: TextStyle(
                color: selected ? AppColors.primaryDark : Colors.white,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildLanguagePicker() {
    return Row(
      children: LetterLanguage.values.map((lang) {
        final selected = lang == _selectedLanguage;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: ChoiceChip(
            label: Text(lang.label),
            selected: selected,
            onSelected: (_) => setState(() => _selectedLanguage = lang),
            selectedColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: selected ? AppColors.primaryDark : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedMood.emoji} Your message',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _generatedText!,
            style:
                const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: copy to clipboard
                  },
                  icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                  label:
                      const Text('Copy', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: navigate to voice message generator, prefilled with this text
                  },
                  icon: const Icon(Icons.graphic_eq,
                      color: Colors.white, size: 18),
                  label: const Text('Voice',
                      style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: send directly into shared couple chat
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

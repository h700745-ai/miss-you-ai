import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../love_letter/love_letter_screen.dart';
import '../voice_message/voice_message_screen.dart';
import '../love_meter/love_meter_screen.dart';
import '../vault/vault_screen.dart';

class HomeFeature {
  final String title;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  HomeFeature({
    required this.title,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Wire each of these to its real screen as we build them out.
  List<HomeFeature> _features(BuildContext context) => [
        HomeFeature(
          title: 'Love Letter AI',
          icon: Icons.mail_outline,
          color: AppColors.primary,
          builder: (_) => const LoveLetterScreen(),
        ),
        HomeFeature(
          title: 'Voice Message',
          icon: Icons.graphic_eq,
          color: AppColors.secondary,
          builder: (_) => const VoiceMessageEntry(),
        ),
        HomeFeature(
          title: 'Date Planner',
          icon: Icons.local_movies_outlined,
          color: AppColors.accent,
          builder: (_) => const _ComingSoonScreen(title: 'AI Date Planner'),
        ),
        HomeFeature(
          title: 'Relationship Coach',
          icon: Icons.forum_outlined,
          color: AppColors.moodCalm,
          builder: (_) =>
              const _ComingSoonScreen(title: 'Relationship AI Chat'),
        ),
        HomeFeature(
          title: 'Memory Timeline',
          icon: Icons.photo_library_outlined,
          color: AppColors.moodSad,
          builder: (_) => const _ComingSoonScreen(title: 'Memory Timeline'),
        ),
        HomeFeature(
          title: 'Love Meter',
          icon: Icons.favorite_border,
          color: AppColors.error,
          builder: (_) => const LoveMeterEntry(),
        ),
        HomeFeature(
          title: 'Daily Surprise',
          icon: Icons.card_giftcard_outlined,
          color: AppColors.moodHappy,
          builder: (_) => const _ComingSoonScreen(title: 'Daily Surprise'),
        ),
        HomeFeature(
          title: 'Private Vault',
          icon: Icons.lock_outline,
          color: AppColors.textSecondaryDark,
          builder: (_) => const VaultScreen(),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Log out',
                onPressed: () => AuthService.instance.signOut(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppColors.loveGradient),
                child: SafeArea(child: _buildCountdownHeader()),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final feature = _features(context)[index];
                  return _FeatureCard(feature: feature)
                      .animate()
                      .fadeIn(delay: (index * 60).ms, duration: 300.ms)
                      .slideY(begin: 0.08, end: 0);
                },
                childCount: _features(context).length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownHeader() {
    // TODO: bind these to the real CoupleModel via a provider once
    // couple pairing + Firestore stream is wired into the widget tree.
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Miss You, Love 💕',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          _CountdownChip(label: 'Together', value: '—'),
        ],
      ),
    );
  }
}

class _CountdownChip extends StatelessWidget {
  final String label;
  final String value;
  const _CountdownChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $value days',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final HomeFeature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: feature.builder),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(feature.icon, color: feature.color, size: 26),
              ),
              Text(
                feature.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonScreen extends StatelessWidget {
  final String title;
  const _ComingSoonScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('$title — building this next 🚧'),
      ),
    );
  }
}

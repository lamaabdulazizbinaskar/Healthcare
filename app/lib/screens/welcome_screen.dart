import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/visuals.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = S.of(context);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 48,
              24,
              70,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, Color(0xFF0D3B4A)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: Column(
              children: [
                const _DoctorHero(),
                const SizedBox(height: 18),
                Text(
                  s.t('app_name'),
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.t('tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: Color(0xE6FFFFFF),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.translate_rounded,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  s.t('choose_language'),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SegmentedPills(
                              labels: const ['العربية', 'English'],
                              index: state.lang == 'ar' ? 0 : 1,
                              onChanged: (i) =>
                                  state.setLang(i == 0 ? 'ar' : 'en'),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      await state.startNewUser();
                                      if (!context.mounted) return;
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const OnboardingScreen(),
                                        ),
                                      );
                                    },
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 28,
                              ),
                              label: Text(s.t('start_new')),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () async {
                                      setState(() => _busy = true);
                                      try {
                                        await state.useDemo();
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                s.t('error_generic'),
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _busy = false);
                                        }
                                      }
                                    },
                              icon: const Icon(
                                Icons.person_outline_rounded,
                                size: 28,
                              ),
                              label: Text(s.t('try_demo')),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AiStatus(on: state.aiMode == 'claude'),
                      const SizedBox(height: 12),
                      const DisclaimerBanner(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 3D doctor guide surrounded by floating health "cards" (heart, food, pill, water).
class _DoctorHero extends StatefulWidget {
  const _DoctorHero();

  @override
  State<_DoctorHero> createState() => _DoctorHeroState();
}

class _DoctorHeroState extends State<_DoctorHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  Widget _bubble(String img, double dy) => AnimatedBuilder(
    animation: _float,
    builder: (_, child) => Transform.translate(
      offset: Offset(0, (_float.value - 0.5) * dy),
      child: child,
    ),
    child: Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Img3D(img),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 176,
            height: 176,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Colors.white, Color(0xFFD7F2EA)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.glow.withValues(alpha: 0.45),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Img3D('doctor'),
          ),
          Positioned(left: 0, top: 18, child: _bubble('red_heart', 14)),
          Positioned(right: 0, top: 8, child: _bubble('salad', -12)),
          Positioned(left: 14, bottom: 4, child: _bubble('pill', -10)),
          Positioned(right: 12, bottom: 0, child: _bubble('droplet', 12)),
        ],
      ),
    );
  }
}

/// Shows whether the AI (Claude) is active, so it's clear in a demo.
class _AiStatus extends StatelessWidget {
  const _AiStatus({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: on ? AppColors.primaryLight : const Color(0xFFEFEDE8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            on ? Icons.auto_awesome_rounded : Icons.offline_bolt_outlined,
            color: on ? AppColors.primary : AppColors.muted,
            size: 22,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              on ? s.t('ai_on') : s.t('demo_ai'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: on ? AppColors.primary : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

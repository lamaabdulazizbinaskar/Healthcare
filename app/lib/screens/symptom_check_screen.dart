import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../safety/red_flags.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'emergency_screen.dart';

const _symptomIcons = {
  'chest_pain': Icons.monitor_heart_rounded,
  'severe_headache': Icons.psychology_alt_rounded,
  'shortness_of_breath': Icons.air_rounded,
  'vision_changes': Icons.visibility_off_rounded,
  'weakness_numbness': Icons.back_hand_rounded,
  'confusion_speech': Icons.record_voice_over_rounded,
};

/// "I feel unwell" — one tap per symptom, rule-based check, full-screen alert if needed.
class SymptomCheckScreen extends StatefulWidget {
  const SymptomCheckScreen({super.key});

  @override
  State<SymptomCheckScreen> createState() => _SymptomCheckScreenState();
}

class _SymptomCheckScreenState extends State<SymptomCheckScreen> {
  final Set<String> _selected = {};
  bool _checked = false;

  Future<void> _check() async {
    final symptoms = _selected.toList();
    Map<String, dynamic> result;
    try {
      result = await AppScope.read(context).api.safetyCheck(symptoms);
    } catch (_) {
      result = isEmergency(symptoms: symptoms)
          ? EmergencyScreen.offlineResult()
          : {'level': 'ok'};
    }
    if (!mounted) return;
    if (result['level'] == 'emergency') {
      await EmergencyScreen.show(context, result);
    } else {
      setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('symptom_title')),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: kFont,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                s.t('symptom_sub'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              for (final sym in warningSymptoms)
                ChoiceTile(
                  label: s.t(sym),
                  icon: _symptomIcons[sym],
                  iconColor: AppColors.danger,
                  multi: true,
                  selected: _selected.contains(sym),
                  onTap: () => setState(() {
                    _checked = false;
                    _selected.contains(sym)
                        ? _selected.remove(sym)
                        : _selected.add(sym);
                  }),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: _check,
                icon: const Icon(Icons.health_and_safety_rounded, size: 28),
                label: Text(s.t('check_now')),
              ),
              if (_checked) ...[
                const SizedBox(height: 16),
                AppCard(
                  color: AppColors.okBg,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.ok,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.t('no_warning'),
                          style: const TextStyle(fontSize: 19, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

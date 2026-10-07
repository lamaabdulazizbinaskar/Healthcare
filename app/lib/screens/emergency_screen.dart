import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../theme.dart';

/// Full-screen emergency alert. Triggered only by the rule-based safety layer.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key, required this.safety});

  /// SafetyResult JSON from the backend (or built locally by the offline mirror).
  final Map<String, dynamic> safety;

  static Future<void> show(BuildContext context, Map<String, dynamic> safety) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EmergencyScreen(safety: safety),
      ),
    );
  }

  /// Used when the server can't be reached: same rules, fixed wording.
  static Map<String, dynamic> offlineResult() => {
    'level': 'emergency',
    'title_en': 'Warning sign detected',
    'title_ar': 'تم رصد علامة خطر',
    'message_en':
        'Seek emergency care now. Call 997 or go to the nearest emergency department. Do not drive yourself.',
    'message_ar':
        'اطلب الرعاية الطارئة الآن. اتصل على 997 أو توجّه إلى أقرب قسم طوارئ. لا تقد السيارة بنفسك.',
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.danger,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 110,
                ),
                const SizedBox(height: 16),
                Text(
                  s.pick(safety, 'title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  s.pick(safety, 'message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 84,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.danger,
                      textStyle: const TextStyle(
                        fontFamily: kFont,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: () => launchUrl(Uri.parse('tel:997')),
                    icon: const Icon(Icons.phone_in_talk, size: 36),
                    label: Text(s.t('call_997')),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.t('im_safe')),
                ),
                const SizedBox(height: 12),
                Text(
                  s.t('emergency_note'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

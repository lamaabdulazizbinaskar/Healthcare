import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'bp_screen.dart';
import 'glucose_screen.dart';

/// "My readings": blood pressure and/or blood sugar, depending on the patient's condition(s).
class ReadingsScreen extends StatefulWidget {
  const ReadingsScreen({super.key});

  @override
  State<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<ReadingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final disease =
        AppScope.of(context).profile?['disease'] as String? ?? 'hypertension';
    if (disease == 'hypertension') return const BpScreen();
    if (disease == 'diabetes') return const GlucoseScreen();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: SegmentedPills(
            labels: [s.t('sugar_short'), s.t('bp_short')],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(child: _tab == 0 ? const GlucoseScreen() : const BpScreen()),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/visuals.dart';

const _insightImages = {
  'flag': 'target',
  'chair': 'chair',
  'weight': 'scale',
  'pill': 'pill',
  'salt': 'salt',
  'smoke': 'no_smoking',
  'heart': 'heart',
  'steps': 'walking',
  'bp': 'stethoscope',
  'stop': 'stop',
};

const _timeImages = {
  'morning': 'sun',
  'afternoon': 'sun_cloud',
  'evening': 'moon',
};

/// "Your healthy lifestyle": the plan built from the health history, explained.
/// Shown right after onboarding (with [onStart]) and from the home screen.
class PlanSummaryScreen extends StatelessWidget {
  const PlanSummaryScreen({super.key, required this.plan, this.onStart});
  final Map<String, dynamic> plan;
  final void Function(BuildContext context)? onStart;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final insights = (plan['insights'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final goals = (plan['goals'] as List)
        .cast<Map<String, dynamic>>()
        .where((g) => g['active_to'] == null)
        .toList();
    final summary = s.pick(plan, 'summary');

    Widget group(String freq, String titleKey) {
      final list = goals.where((g) => g['frequency'] == freq).toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('${s.t(titleKey)} · ${list.length}'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final (i, g) in list.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: i > 0
                          ? const Border(
                              top: BorderSide(color: Color(0xFFEDEAE4)),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Img3DBadge(
                          CategoryStyle.of(g['category'] as String?).image,
                          color: CategoryStyle.of(
                            g['category'] as String?,
                          ).color,
                          size: 50,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.pick(g, 'title'),
                            style: const TextStyle(
                              fontSize: 18.5,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (_timeImages.containsKey(g['time_of_day'])) ...[
                          const SizedBox(width: 8),
                          Img3D(_timeImages[g['time_of_day']]!, size: 30),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.t('your_plan'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              DoctorSays(
                text: s.t('plan_ready'),
                sub: summary.isEmpty ? null : summary,
                size: 76,
              ),
              if (insights.isNotEmpty) ...[
                const SizedBox(height: 8),
                DashboardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Img3D('clipboard', size: 34),
                          const SizedBox(width: 10),
                          Text(
                            s.t('based_on_history'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final ins in insights)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.glow.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Img3D(
                                  _insightImages[ins['icon']] ?? 'sparkles',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.pick(ins, 'text'),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        color: Colors.white,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if ((ins['source'] as String? ?? '')
                                        .isNotEmpty)
                                      Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(
                                          '${ins['rule']} · ${ins['source']}',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            color: AppColors.glow,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              group('daily', 'daily_goals'),
              group('weekly', 'weekly_goals'),
              group('monthly', 'monthly_goals'),
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.primaryLight,
                child: Row(
                  children: [
                    const Img3D('seedling', size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.t('plan_changes_note'),
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (onStart != null)
                FilledButton.icon(
                  onPressed: () => onStart!(context),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 28),
                  label: Text(s.t('start_plan')),
                )
              else
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.t('close')),
                ),
              const SizedBox(height: 14),
              const DisclaimerBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

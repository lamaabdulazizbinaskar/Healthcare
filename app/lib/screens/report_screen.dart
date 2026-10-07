import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/visuals.dart';

const _reasonKeys = {'too_hard', 'no_time', 'pain', 'forgot', 'dont_like'};

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? _report;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await AppScope.read(context).api.report();
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_error != null) return ErrorView(onRetry: _load, detail: '$_error');
    if (_report == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final r = _report!;
    final bp = r['bp'] as Map<String, dynamic>;
    final adherence = r['adherence_percent'] as int;
    final goals = (r['goals'] as List).cast<Map<String, dynamic>>();
    final changes = (r['difficulties'] as List).cast<Map<String, dynamic>>();
    final change = bp['change_systolic'] as int?;
    final fmt = DateFormat('d MMM', s.lang);
    final period =
        '${fmt.format(DateTime.parse(r['period']['start'] as String))} – ${fmt.format(DateTime.parse(r['period']['end'] as String))}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Row(
          children: [
            const Img3D('chart', size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('report_title'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    period,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DashboardCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  GlowRing(
                    value: adherence / 100,
                    label: '$adherence%',
                    size: 124,
                    color: adherence >= 70 ? AppColors.glow : AppColors.accent,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('adherence'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.t(
                            adherence >= 70
                                ? 'cheer_mid'
                                : adherence >= 50
                                ? 'cheer_almost'
                                : 'cheer_start',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.glow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (bp['count'] != 0) ...[
                Divider(
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                Row(
                  children: [
                    const Img3D('red_heart', size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.t('bp_change'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (change != null) _ChangePill(change: change),
                  ],
                ),
                const SizedBox(height: 12),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      Expanded(
                        child: _BpValue(
                          label: s.t('start'),
                          value: bp['first_avg'] as String,
                          muted: true,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 30,
                        color: AppColors.glow,
                      ),
                      Expanded(
                        child: _BpValue(
                          label: s.t('end'),
                          value: bp['last_avg'] as String,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        label: s.t('avg_bp'),
                        value: '${bp['avg_systolic']}/${bp['avg_diastolic']}',
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: s.t('readings_count'),
                        value: '${bp['count']}',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if ((r['glucose'] as Map?)?['count'] != null &&
            (r['glucose'] as Map)['count'] != 0) ...[
          const SizedBox(height: 14),
          _GlucoseSummary(g: (r['glucose'] as Map).cast<String, dynamic>()),
        ],
        SectionTitle(s.t('hardest_goals')),
        AppCard(
          child: Column(
            children: [
              for (final (i, g)
                  in goals
                      .where((g) => g['retired'] != true)
                      .take(4)
                      .indexed) ...[
                if (i > 0) const SizedBox(height: 16),
                _GoalBar(goal: g),
              ],
            ],
          ),
        ),
        if (changes.isNotEmpty) ...[
          SectionTitle(s.t('plan_changes')),
          for (final d in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChangeCard(change: d),
            ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(AppScope.read(context).api.reportPdfUrl()),
            webOnlyWindowName: '_blank',
          ),
          icon: const Img3D('clipboard', size: 30),
          label: Text(s.t('open_pdf')),
        ),
        const SizedBox(height: 8),
        Text(
          s.t('pdf_note'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        const DisclaimerBanner(),
      ],
    );
  }
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.change});
  final Map<String, dynamic> change;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final harder = change['direction'] == 'harder';
    final reason = change['reason'] as String;
    final color = harder ? AppColors.ok : AppColors.warn;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Img3D(harder ? 'trophy' : 'seedling', size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  harder
                      ? s.t('stepped_up')
                      : '${s.t('made_easier')} · ${_reasonKeys.contains(reason) ? s.t('r_$reason') : reason}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.pick(change, 'old'),
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.muted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                harder ? Icons.north_rounded : Icons.south_rounded,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.pick(change, 'new'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.change});
  final int change;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final good = change <= 0;
    final color = good ? AppColors.glow : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            good ? Icons.trending_down_rounded : Icons.trending_up_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 4),
          Text(
            s.t(good ? 'down_by' : 'up_by', {'n': change.abs()}),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BpValue extends StatelessWidget {
  const _BpValue({
    required this.label,
    required this.value,
    this.muted = false,
  });
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white60,
        ),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: muted ? Colors.white54 : Colors.white,
            shadows: muted
                ? null
                : [
                    Shadow(
                      color: AppColors.glow.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ],
          ),
        ),
      ),
    ],
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsetsDirectional.only(end: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white60,
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.goal});
  final Map<String, dynamic> goal;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pct = goal['adherence'] as int;
    final color = pct >= 70
        ? AppColors.ok
        : pct >= 50
        ? AppColors.warn
        : AppColors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                s.pick(goal, 'title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 12,
            color: color,
            backgroundColor: color.withValues(alpha: 0.13),
          ),
        ),
      ],
    );
  }
}

class _GlucoseSummary extends StatelessWidget {
  const _GlucoseSummary({required this.g});
  final Map<String, dynamic> g;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget stat(String label, String value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );
    final lows = g['lows'] as int? ?? 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Img3D('blood', size: 30),
              const SizedBox(width: 8),
              Text(
                s.t('sugar_short'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${g['in_range_pct']}% 70–180',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ok,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(s.isAr ? 'المتوسط' : 'Average', '${g['avg']}'),
              stat(s.t('ctx_fasting'), '${g['fasting_avg'] ?? '-'}'),
              stat(
                s.t('glu_low'),
                '$lows',
                color: lows > 0 ? AppColors.danger : AppColors.ok,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

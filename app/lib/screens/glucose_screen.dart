import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/visuals.dart';
import 'emergency_screen.dart';

const _contexts = ['fasting', 'before_meal', 'after_meal', 'bedtime'];

/// Display status (ADA 2026 Table 6.3 goals; Table 6.4 low levels). Alerts come from the backend rules.
({String key, Color color, Color bg}) _status(int v, String ctx) {
  if (v < 70) {
    return (key: 'glu_low', color: AppColors.danger, bg: AppColors.dangerBg);
  }
  final high = (ctx == 'fasting' || ctx == 'before_meal') ? v > 130 : v >= 180;
  if (high) {
    return (key: 'glu_high', color: AppColors.warn, bg: AppColors.warnBg);
  }
  return (key: 'glu_in_range', color: AppColors.ok, bg: AppColors.okBg);
}

class GlucoseScreen extends StatefulWidget {
  const GlucoseScreen({super.key});

  @override
  State<GlucoseScreen> createState() => _GlucoseScreenState();
}

class _GlucoseScreenState extends State<GlucoseScreen> {
  List<Map<String, dynamic>>? _readings;
  Object? _error;
  num _value = 120;
  String _ctx = 'fasting';
  bool _severe = false;
  bool _saving = false;
  Map<String, dynamic>? _lastSafety;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = (await AppScope.read(
        context,
      ).api.glucose()).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _readings = list;
        if (list.isNotEmpty) _value = list.last['value'] as int;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    Map<String, dynamic>? safety;
    final v = _value.round();
    try {
      final res = await AppScope.read(
        context,
      ).api.addGlucose(v, _ctx, _severe ? ['confused'] : []);
      safety = res['safety'] as Map<String, dynamic>;
    } catch (_) {
      // Offline fallback mirrors ADA thresholds.
      if (_severe || v < 54) safety = EmergencyScreen.offlineResult();
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _lastSafety = safety;
      _severe = false;
    });
    final level = safety?['level'];
    if (level == 'emergency' || level == 'urgent') {
      await EmergencyScreen.show(context, safety!);
    } else if (safety != null && level == 'ok') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).t('saved'))));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_error != null) return ErrorView(onRetry: _load, detail: '$_error');
    if (_readings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final live = _status(_value.round(), _ctx);
    final last = _readings!.isEmpty ? null : _readings!.last;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (last != null) _LastCard(r: last),
        SectionTitle(s.t('log_sugar')),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NumberTile(
                label: s.t('sugar_value'),
                value: _value,
                min: 20,
                max: 600,
                color: _value < 70 ? AppColors.danger : null,
                onChanged: (v) => setState(() => _value = v),
              ),
              const SizedBox(height: 12),
              Text(
                s.t('when_measured'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _contexts)
                    ChoiceChip(
                      label: Text(
                        s.t('ctx_$c'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      selected: _ctx == c,
                      selectedColor: AppColors.primaryLight,
                      onSelected: (_) => setState(() => _ctx = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: live.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  s.t(live.key),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: live.color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.t('glu_goal_note'),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              ChoiceTile(
                label: s.t('sev_symptoms'),
                image: 'ambulance',
                iconColor: AppColors.danger,
                multi: true,
                selected: _severe,
                onTap: () => setState(() => _severe = !_severe),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded, size: 30),
                label: Text(s.t('save_reading')),
              ),
            ],
          ),
        ),
        if (_lastSafety?['level'] == 'low') ...[
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.dangerBg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.pick(_lastSafety!, 'title'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.pick(_lastSafety!, 'message'),
                  style: const TextStyle(fontSize: 18, height: 1.45),
                ),
              ],
            ),
          ),
        ],
        SectionTitle(s.t('trend')),
        if (_readings!.length >= 2)
          _GlucoseChart(readings: _readings!)
        else
          AppCard(child: Text(s.t('no_readings'))),
        SectionTitle(s.t('recent')),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final (i, r) in _readings!.reversed.take(7).indexed)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: i > 0
                        ? const Border(
                            top: BorderSide(color: Color(0xFFEDEAE4)),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _status(
                            r['value'] as int,
                            r['context'] as String,
                          ).color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${r['value']}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.t('ctx_${r['context']}'),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat(
                          'd/M · HH:mm',
                        ).format(DateTime.parse(r['taken_at'] as String)),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LastCard extends StatelessWidget {
  const _LastCard({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final v = r['value'] as int;
    final st = _status(v, r['context'] as String);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('last_reading'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$v',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.t('mgdl'),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: st.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${s.t(st.key)} · ${s.t('ctx_${r['context']}')}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: st.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Img3DBadge('blood', color: st.color, size: 62),
        ],
      ),
    );
  }
}

class _GlucoseChart extends StatelessWidget {
  const _GlucoseChart({required this.readings});
  final List<Map<String, dynamic>> readings;

  @override
  Widget build(BuildContext context) {
    final recent = readings.length > 60
        ? readings.sublist(readings.length - 60)
        : readings;
    final first = DateTime.parse(recent.first['taken_at'] as String);
    double x(Map<String, dynamic> r) =>
        DateTime.parse(r['taken_at'] as String).difference(first).inMinutes /
        (60 * 24);
    final fmt = DateFormat('d/M');
    return DashboardCard(
      padding: const EdgeInsets.fromLTRB(8, 18, 16, 12),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 40,
              maxY: 260,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 40,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Color(0x1AFFFFFF), strokeWidth: 1),
              ),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  HorizontalRangeAnnotation(
                    y1: 70,
                    y2: 180,
                    color: AppColors.glow.withValues(alpha: 0.10),
                  ),
                ],
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 70,
                    color: AppColors.glowRed.withValues(alpha: 0.7),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
                  HorizontalLine(
                    y: 180,
                    color: AppColors.glow.withValues(alpha: 0.6),
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 40,
                    getTitlesWidget: (v, _) => Text(
                      '${v.round()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 7,
                    reservedSize: 26,
                    getTitlesWidget: (v, _) => Text(
                      fmt.format(first.add(Duration(hours: (v * 24).round()))),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (final r in recent)
                      FlSpot(x(r), (r['value'] as int).toDouble()),
                  ],
                  color: AppColors.glowBlue,
                  barWidth: 3,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  shadow: Shadow(
                    color: AppColors.glowBlue.withValues(alpha: 0.8),
                    blurRadius: 10,
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                      radius: 3.5,
                      color: spot.y < 70
                          ? AppColors.glowRed
                          : AppColors.glowBlue,
                      strokeWidth: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

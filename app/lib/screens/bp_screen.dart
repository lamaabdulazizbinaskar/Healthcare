import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/strings.dart';
import '../safety/red_flags.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/visuals.dart';
import 'emergency_screen.dart';

/// Display-only status for a reading. Emergencies use the rule engine in red_flags.dart.
({String key, Color color, Color bg, IconData icon}) _status(int sys, int dia) {
  if (isEmergency(systolic: sys, diastolic: dia)) {
    return (
      key: 'bp_crisis',
      color: AppColors.danger,
      bg: AppColors.dangerBg,
      icon: Icons.warning_rounded,
    );
  }
  if (sys >= 130 || dia >= 80) {
    return (
      key: 'bp_above',
      color: AppColors.warn,
      bg: AppColors.warnBg,
      icon: Icons.arrow_upward_rounded,
    );
  }
  return (
    key: 'bp_in_target',
    color: AppColors.ok,
    bg: AppColors.okBg,
    icon: Icons.check_circle_rounded,
  );
}

class BpScreen extends StatefulWidget {
  const BpScreen({super.key});

  @override
  State<BpScreen> createState() => _BpScreenState();
}

class _BpScreenState extends State<BpScreen> {
  List<Map<String, dynamic>>? _readings;
  Object? _error;
  num _sys = 130;
  num _dia = 80;
  bool _showSymptoms = false;
  final Set<String> _symptoms = {};
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
      ).api.bp()).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _readings = list;
        _error = null;
        if (list.isNotEmpty) {
          _sys = list.last['systolic'] as int;
          _dia = list.last['diastolic'] as int;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    final sys = _sys.round(), dia = _dia.round();
    final symptoms = _symptoms.toList();
    setState(() => _saving = true);
    Map<String, dynamic>? safety;
    try {
      final res = await AppScope.read(
        context,
      ).api.addBp(sys, dia, null, symptoms);
      safety = res['safety'] as Map<String, dynamic>;
    } catch (_) {
      // Offline: the local rule mirror still protects the user.
      if (isEmergency(systolic: sys, diastolic: dia, symptoms: symptoms)) {
        safety = EmergencyScreen.offlineResult();
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _lastSafety = safety;
      _symptoms.clear();
      _showSymptoms = false;
    });
    if (safety?['level'] == 'emergency') {
      await EmergencyScreen.show(context, safety!);
    } else if (safety != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).t('saved'))));
    }
    _load();
  }

  void _measureTip() {
    final s = S.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Img3D('chair', size: 84),
              const SizedBox(height: 12),
              Text(
                s.t('how_to_measure'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                s.t('measure_tip'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, height: 1.5),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.t('close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_error != null) return ErrorView(onRetry: _load, detail: '$_error');
    if (_readings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final live = _status(_sys.round(), _dia.round());
    final last = _readings!.isEmpty ? null : _readings!.last;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        if (last != null) _LastReadingCard(r: last),
        SectionTitle(s.t('new_reading')),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: NumberTile(
                      label: s.t('top_number'),
                      value: _sys,
                      min: 60,
                      max: 260,
                      color: _sys >= crisisSystolic ? AppColors.danger : null,
                      onChanged: (v) => setState(() => _sys = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberTile(
                      label: s.t('bottom_number'),
                      value: _dia,
                      min: 30,
                      max: 180,
                      color: _dia >= crisisDiastolic ? AppColors.danger : null,
                      onChanged: (v) => setState(() => _dia = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: live.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(live.icon, color: live.color, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      s.t(live.key),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: live.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ChoiceTile(
                label: s.t('have_symptoms'),
                image: 'thinking',
                iconColor: AppColors.danger,
                multi: true,
                selected: _showSymptoms,
                onTap: () => setState(() {
                  _showSymptoms = !_showSymptoms;
                  if (!_showSymptoms) _symptoms.clear();
                }),
              ),
              if (_showSymptoms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sym in warningSymptoms)
                        FilterChip(
                          label: Text(s.t(sym)),
                          selected: _symptoms.contains(sym),
                          onSelected: (v) => setState(
                            () =>
                                v ? _symptoms.add(sym) : _symptoms.remove(sym),
                          ),
                        ),
                    ],
                  ),
                ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 30),
                label: Text(s.t('save_reading')),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _measureTip,
                icon: const Icon(Icons.help_outline_rounded, size: 22),
                label: Text(
                  s.t('how_to_measure'),
                  style: const TextStyle(
                    fontFamily: kFont,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_lastSafety?['level'] == 'elevated') ...[
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.warnBg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, color: AppColors.warn, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.pick(_lastSafety!, 'title'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warn,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.pick(_lastSafety!, 'message'),
                        style: const TextStyle(fontSize: 17, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        SectionTitle(s.t('trend')),
        if (_readings!.length < 2)
          AppCard(
            child: Text(
              s.t('no_readings'),
              style: const TextStyle(fontSize: 18),
            ),
          )
        else
          _BpChart(readings: _readings!),
        SectionTitle(s.t('recent')),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final (i, r) in _readings!.reversed.take(7).indexed)
                _ReadingRow(r: r, divider: i > 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _LastReadingCard extends StatelessWidget {
  const _LastReadingCard({required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sys = r['systolic'] as int, dia = r['diastolic'] as int;
    final st = _status(sys, dia);
    final dt = DateTime.parse(r['taken_at'] as String);
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
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$sys/$dia',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.t('mmhg'),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: st.bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(st.icon, size: 18, color: st.color),
                          const SizedBox(width: 4),
                          Text(
                            s.t(st.key),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: st.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('d MMM · HH:mm', s.lang).format(dt),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Img3DBadge('red_heart', color: st.color, size: 62),
        ],
      ),
    );
  }
}

class _BpChart extends StatelessWidget {
  const _BpChart({required this.readings});
  final List<Map<String, dynamic>> readings;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final recent = readings.length > 60
        ? readings.sublist(readings.length - 60)
        : readings;
    final first = DateTime.parse(recent.first['taken_at'] as String);
    double x(Map<String, dynamic> r) =>
        DateTime.parse(r['taken_at'] as String).difference(first).inMinutes /
        (60 * 24);
    LineChartBarData line(String field, Color color) => LineChartBarData(
      spots: [
        for (final r in recent) FlSpot(x(r), (r[field] as int).toDouble()),
      ],
      color: color,
      barWidth: 3.5,
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      dotData: const FlDotData(show: false),
      shadow: Shadow(color: color.withValues(alpha: 0.8), blurRadius: 10),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ),
      ),
    );
    final fmt = DateFormat('d/M');
    return DashboardCard(
      padding: const EdgeInsets.fromLTRB(8, 18, 16, 12),
      child: Column(
        children: [
          // Charts read left-to-right (time axis) even in Arabic.
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 230,
              child: LineChart(
                LineChartData(
                  minY: 50,
                  maxY: 200,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 30,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0x1AFFFFFF), strokeWidth: 1),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 180,
                        color: AppColors.glowRed.withValues(alpha: 0.6),
                        strokeWidth: 2,
                        dashArray: [6, 4],
                      ),
                      HorizontalLine(
                        y: 130,
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
                        interval: 30,
                        getTitlesWidget: (v, _) => Text(
                          '${v.round()}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 7,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => Text(
                          fmt.format(
                            first.add(Duration(hours: (v * 24).round())),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    line('systolic', AppColors.glowRed),
                    line('diastolic', AppColors.glowBlue),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _Legend(color: AppColors.glowRed, label: s.t('top_number')),
              _Legend(color: AppColors.glowBlue, label: s.t('bottom_number')),
              _Legend(color: AppColors.glow, label: '130', dashed: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
  });
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 20,
        height: dashed ? 3 : 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6),
          ],
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    ],
  );
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.r, required this.divider});
  final Map<String, dynamic> r;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final sys = r['systolic'] as int, dia = r['diastolic'] as int;
    final st = _status(sys, dia);
    final dt = DateTime.parse(r['taken_at'] as String);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: divider
            ? const Border(top: BorderSide(color: Color(0xFFEDEAE4)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 40,
            decoration: BoxDecoration(
              color: st.color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$sys / $dia',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const Spacer(),
          Text(
            DateFormat('EEE d/M · HH:mm', s.lang).format(dt),
            style: const TextStyle(fontSize: 16, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

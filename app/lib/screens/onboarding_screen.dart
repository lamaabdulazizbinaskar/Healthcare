import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/visuals.dart';
import 'emergency_screen.dart';
import 'plan_summary_screen.dart';

/// Question text in the current language (registry items use plain `en` / `ar` keys).
String _qt(Map<String, dynamic> m, S s) =>
    (m[s.lang] ?? m['en'] ?? '') as String;

/// Health-history interview. The questions, answer options and their sources come from the
/// backend registry (GET /api/intake → backend/app/intake/hypertension.py), so the app asks
/// exactly what the documented decision rules need. One question per screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic> _sections = {};
  final Map<String, dynamic> _answers = {};
  final Set<String> _unknownBp =
      {}; // question ids where "I don't know" was chosen
  final _text = TextEditingController();
  final _other = TextEditingController();
  int _index = 0; // index into the *visible* questions
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AppScope.read(context).api.intake();
      final qs = (res['questions'] as List).cast<Map<String, dynamic>>();
      for (final q in qs) {
        // Defaults so number questions are always answered and multi questions start empty.
        switch (q['type']) {
          case 'number':
            _answers[q['field'] as String] = q['default'];
          case 'numbers' || 'bp':
            for (final f
                in (q['fields'] as List).cast<Map<String, dynamic>>()) {
              _answers[f['field'] as String] = f['default'];
            }
          case 'multi':
            _answers[q['field'] as String] = <dynamic>[];
        }
      }
      setState(() {
        _questions = qs;
        _sections = res['sections'] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  // ---------------------------------------------------------------- logic
  bool _visible(Map<String, dynamic> q) {
    bool test(Map<String, dynamic> c) {
      final v = _answers[c['field']];
      if (c.containsKey('eq')) return v == c['eq'];
      if (c.containsKey('in')) return (c['in'] as List).contains(v);
      if (c.containsKey('lt')) return v is num && v < (c['lt'] as num);
      if (c.containsKey('gt')) return v is num && v > (c['gt'] as num);
      if (c['not_empty'] == true) return v is List && v.isNotEmpty;
      return true;
    }

    final cond = q['show_if'] as Map<String, dynamic>?;
    if (cond == null) return true;
    if (cond.containsKey('all')) {
      return (cond['all'] as List).cast<Map<String, dynamic>>().every(test);
    }
    return test(cond);
  }

  List<Map<String, dynamic>> get _visibleQuestions =>
      _questions.where(_visible).toList();

  bool _answered(Map<String, dynamic> q) {
    if (q['type'] == 'choice') return _answers[q['field']] != null;
    return true; // text is optional; numbers have defaults; multi allows "none"
  }

  void _next() {
    if (_index >= _visibleQuestions.length - 1) {
      _submit();
    } else {
      setState(() => _index++);
    }
  }

  void _back() => setState(
    () => _index = (_index - 1).clamp(0, _visibleQuestions.length - 1),
  );

  Map<String, dynamic> _payload() {
    final state = AppScope.read(context);
    final out = <String, dynamic>{..._answers, 'language': state.lang};
    out['name'] = _text.text.trim();
    // Answers to questions that ended up hidden are dropped (e.g. pregnancy for men).
    for (final q in _questions.where((q) => !_visible(q))) {
      if (q['field'] != null) out.remove(q['field']);
    }
    for (final id in _unknownBp) {
      final q = _questions.firstWhere((q) => q['id'] == id);
      for (final f in (q['fields'] as List).cast<Map<String, dynamic>>()) {
        out.remove(f['field']);
      }
    }
    out['medications'] = [
      ...(out['medications'] as List? ?? []),
      if (_other.text.trim().isNotEmpty) _other.text.trim(),
    ];
    out.removeWhere((k, v) => v == null);
    return out;
  }

  Future<void> _submit() async {
    final state = AppScope.read(context);
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final res = await state.api.onboard(_payload());
      if (!mounted) return;
      final excluded = res['excluded'] as Map<String, dynamic>?;
      if (excluded != null) {
        setState(() => _generating = false);
        await _showExcluded(excluded);
        return;
      }
      final safety = res['safety'] as Map<String, dynamic>?;
      if (safety?['level'] == 'emergency') {
        await EmergencyScreen.show(context, safety!);
        if (!mounted) return;
      }
      final profile = res['profile'] as Map<String, dynamic>;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PlanSummaryScreen(
            plan: res['plan'] as Map<String, dynamic>,
            onStart: (ctx) {
              Navigator.of(ctx).popUntil((r) => r.isFirst);
              state.onboarded(profile);
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _generating = false;
        _error = '$e';
      });
    }
  }

  Future<void> _showExcluded(Map<String, dynamic> ex) async {
    final s = S.of(context);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Img3D('doctor', size: 80),
        title: Text(s.pick(ex, 'title'), textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.pick(ex, 'message'),
                style: const TextStyle(fontSize: 18, height: 1.5),
              ),
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  'Source: ${ex['source']}',
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.t('close')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _whyAsk(Map<String, dynamic> q) {
    final s = S.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Img3D('doctor', size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.t('why_ask'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                s.pick(q, 'why'),
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.bg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.t('source'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q['source'] as String,
                            style: const TextStyle(fontSize: 16, height: 1.45),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Question based on: ${q['instrument']}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

  // ---------------------------------------------------------------- UI per question type
  Widget _body(Map<String, dynamic> q, S s) {
    final field = q['field'] as String?;
    final lang = s.lang;

    switch (q['type']) {
      case 'text':
        return TextField(
          controller: _text,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            labelText: _qt(q, s),
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
          onSubmitted: (_) => _next(),
        );
      case 'number':
        return NumberStepper(
          label: _qt(q, s),
          unit: (q['unit_$lang'] ?? '') as String,
          value: _answers[field] as num,
          min: q['min'] as num,
          max: q['max'] as num,
          onChanged: (v) => setState(() => _answers[field!] = v.round()),
        );
      case 'numbers':
        return Column(
          children: [
            for (final f
                in (q['fields'] as List).cast<Map<String, dynamic>>()) ...[
              NumberStepper(
                label: _qt(f, s),
                unit: (f['unit_$lang'] ?? '') as String,
                value: _answers[f['field']] as num,
                min: f['min'] as num,
                max: f['max'] as num,
                onChanged: (v) =>
                    setState(() => _answers[f['field'] as String] = v.round()),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      case 'bp':
        final fields = (q['fields'] as List).cast<Map<String, dynamic>>();
        final unknown = _unknownBp.contains(q['id']);
        return Column(
          children: [
            if (!unknown)
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    for (final (i, f) in fields.indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: NumberTile(
                          label: _qt(f, s),
                          value: _answers[f['field']] as num,
                          min: f['min'] as num,
                          max: f['max'] as num,
                          onChanged: (v) => setState(
                            () => _answers[f['field'] as String] = v.round(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            ChoiceTile(
              label: s.t('dont_know'),
              image: 'thinking',
              multi: true,
              selected: unknown,
              onTap: () => setState(
                () => unknown
                    ? _unknownBp.remove(q['id'])
                    : _unknownBp.add(q['id'] as String),
              ),
            ),
          ],
        );
      case 'choice':
        return Column(
          children: [
            for (final o in (q['options'] as List).cast<Map<String, dynamic>>())
              ChoiceTile(
                label: _qt(o, s),
                image: o['img'] as String?,
                selected: _answers[field] == o['value'],
                onTap: () {
                  setState(() => _answers[field!] = o['value']);
                  // Auto-advance: one tap answers and moves on (fewer steps for older users).
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted && _visibleQuestions.indexOf(q) == _index) {
                      _next();
                    }
                  });
                },
              ),
          ],
        );
      case 'multi':
        final selected = (_answers[field] as List).cast<dynamic>();
        final max = q['max'] as int?;
        final none = q['none_option'] as Map<String, dynamic>?;
        return Column(
          children: [
            for (final o in (q['options'] as List).cast<Map<String, dynamic>>())
              ChoiceTile(
                label: _qt(o, s),
                image: o['img'] as String?,
                multi: true,
                selected: selected.contains(o['value']),
                onTap: () => setState(() {
                  if (selected.contains(o['value'])) {
                    selected.remove(o['value']);
                  } else if (max == null || selected.length < max) {
                    selected.add(o['value']);
                  }
                }),
              ),
            if (none != null)
              ChoiceTile(
                label: _qt(none, s),
                image: 'check',
                selected: selected.isEmpty,
                onTap: () => setState(selected.clear),
              ),
            if (q['allow_other'] == true)
              TextField(
                controller: _other,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  labelText: s.t('other_med'),
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
              ),
          ],
        );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_generating) return _GeneratingView(s: s);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(onRetry: _loadQuestions, detail: _error),
      );
    }
    final visible = _visibleQuestions;
    _index = _index.clamp(0, visible.length - 1);
    final q = visible[_index];
    final last = _index == visible.length - 1;
    final sectionKeys = _sections.keys.toList();
    final sectionNo = sectionKeys.indexOf(q['section'] as String) + 1;
    final section = (_sections[q['section']] as Map).cast<String, dynamic>();
    final help = (q['help_${s.lang}'] ?? '') as String;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('part_n', {
                'n': sectionNo,
                'total': sectionKeys.length,
                'name': _qt(section, s),
              }),
              style: const TextStyle(
                fontFamily: kFont,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_index + 1) / visible.length,
                minHeight: 10,
                backgroundColor: AppColors.border,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            key: ValueKey(q['id']),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              DoctorSays(
                text: _qt(q, s),
                sub: help.isEmpty ? null : help,
                size: 60,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 48),
                    textStyle: const TextStyle(
                      fontFamily: kFont,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () => _whyAsk(q),
                  icon: const Icon(Icons.help_outline_rounded, size: 26),
                  label: Text(s.t('why_ask')),
                ),
              ),
              const SizedBox(height: 6),
              _body(q, s),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${s.t('error_generic')}\n$_error',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Row(
            children: [
              if (_index > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _back,
                    child: Text(s.t('back')),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _answered(q) ? _next : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          last ? s.t('start_new') : s.t('next'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        last
                            ? Icons.auto_awesome_rounded
                            : Icons.arrow_forward_rounded,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView({required this.s});
  final S s;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kDashboardGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 170,
                      height: 170,
                      child: CircularProgressIndicator(
                        strokeWidth: 5,
                        color: AppColors.glow,
                      ),
                    ),
                    Container(
                      width: 140,
                      height: 140,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.glow.withValues(alpha: 0.5),
                            blurRadius: 40,
                          ),
                        ],
                      ),
                      child: const Img3D('doctor'),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  s.t('generating'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  s.t('generating_sub'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    color: Color(0xCCFFFFFF),
                    height: 1.4,
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

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/visuals.dart';
import 'home_shell.dart' show kMaxContentWidth;
import 'plan_summary_screen.dart';

const _timeImages = {
  'morning': 'sun',
  'afternoon': 'sun_cloud',
  'evening': 'moon',
};
const _slotOrder = ['morning', 'afternoon', 'evening'];

String _currentSlot() {
  final h = DateTime.now().hour;
  return h < 12 ? 'morning' : (h < 17 ? 'afternoon' : 'evening');
}

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _water;
  Object? _error;
  int _tab = 0;
  final Set<String> _asked = {}; // goals already asked about this session
  final Set<String> _snoozed = {}; // "Later" on the Now card
  static const _periods = ['daily', 'weekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = AppScope.read(context).api;
    try {
      final d = await api.checklist();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
      api
          .water()
          .then((w) {
            if (mounted) setState(() => _water = w);
          })
          .catchError((_) {});
      final pending = d['pending_adaptation'] as Map<String, dynamic>?;
      final goalId = (pending?['goal'] as Map?)?['id'] as String?;
      if (pending != null && goalId != null && !_asked.contains(goalId)) {
        _asked.add(goalId);
        WidgetsBinding.instance.addPostFrameCallback((_) => _askAdapt(pending));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _setDone(Map<String, dynamic> item, bool value) async {
    final goal = item['goal'] as Map<String, dynamic>;
    setState(() => item['done'] = value); // optimistic
    try {
      await AppScope.read(context).api.check(goal['id'] as String, value);
    } catch (_) {
      if (mounted) setState(() => item['done'] = !value);
    }
  }

  Future<void> _water1(int delta) async {
    try {
      final w = await AppScope.read(context).api.addWater(delta);
      if (mounted) setState(() => _water = w);
    } catch (_) {}
  }

  Future<void> _openPlan() async {
    final api = AppScope.read(context).api;
    final plan = await api.plan();
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlanSummaryScreen(plan: plan)));
  }

  /// Ask about one goal: why it's being missed (make easier) or whether to step it up.
  Future<void> _askAdapt(Map<String, dynamic> pending) async {
    final s = S.of(context);
    final goal = pending['goal'] as Map<String, dynamic>;
    final ready = pending['type'] == 'ready';
    final style = CategoryStyle.of(goal['category'] as String?);
    final Map<String, String> options = ready
        ? {'level_up': 'trophy', 'keep': 'thinking'}
        : {
            'too_hard': 'muscle',
            'no_time': 'calendar',
            'pain': 'bone',
            'forgot': 'bell',
            'dont_like': 'stop',
            'keep': 'seedling',
          };
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Img3D(ready ? 'trophy' : 'thinking', size: 84)),
              const SizedBox(height: 10),
              Text(
                s.t(ready ? 'ready_title' : 'adapt_title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Img3DBadge(style.image, color: style.color, size: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.pick(goal, 'title'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                ready
                    ? s.t('ready_q', {
                        'goal': s.pick(goal, 'title'),
                        'days': pending['done_days'],
                      })
                    : s.t('adapt_q', {
                        'goal': s.pick(goal, 'title'),
                        'days': pending['missed_days'],
                      }),
                style: const TextStyle(
                  fontSize: 19,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 14),
              for (final o in options.entries)
                ChoiceTile(
                  label: s.t(
                    o.key == 'keep' && ready ? 'not_yet' : 'r_${o.key}',
                  ),
                  selected: false,
                  image: o.value,
                  iconColor: o.key == 'level_up'
                      ? AppColors.accent
                      : AppColors.warn,
                  onTap: () => Navigator.pop(ctx, o.key),
                ),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !mounted) return;
    final api = AppScope.read(context).api;
    try {
      if (reason == 'keep') {
        await api.adapt(goal['id'] as String, 'keep');
        return;
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final res = await api.adapt(goal['id'] as String, reason);
      if (!mounted) return;
      Navigator.of(context).pop();
      await _showNewGoal(
        res['new_goal'] as Map<String, dynamic>,
        harder: reason == 'level_up',
      );
      _load();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.t('error_generic'))));
      }
    }
  }

  Future<void> _showNewGoal(Map<String, dynamic> goal, {required bool harder}) {
    final s = S.of(context);
    final style = CategoryStyle.of(goal['category'] as String?);
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Img3D(harder ? 'party' : 'sparkles', size: 76),
        title: Text(
          s.t(harder ? 'stepped_up' : 'made_easier'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppCard(
              color: style.color.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Img3DBadge(style.image, color: style.color, size: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.pick(goal, 'title'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.pick(goal, 'why'),
              style: const TextStyle(fontSize: 18, height: 1.45),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.t('adapt_ok')),
          ),
        ],
      ),
    );
  }

  void _showWhy(Map<String, dynamic> goal) {
    final s = S.of(context);
    final style = CategoryStyle.of(goal['category'] as String?);
    final sources = (goal['sources'] as List).cast<Map<String, dynamic>>();
    final tailoring = s.pick(goal, 'tailoring');
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
                  Img3DBadge(style.image, color: style.color, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.pick(goal, 'title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Img3D('red_heart', size: 26),
                        const SizedBox(width: 8),
                        Text(
                          s.t('why_matters'),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.pick(goal, 'why'),
                      style: const TextStyle(fontSize: 21, height: 1.55),
                    ),
                  ],
                ),
              ),
              if (tailoring.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  color: AppColors.primaryLight,
                  child: Row(
                    children: [
                      const Img3D('doctor', size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.t('made_for_you'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              tailoring,
                              style: const TextStyle(fontSize: 18, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    size: 20,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.t('source'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              for (final src in sources)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${src['citation']}  [${src['id']}]',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
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

  /// The goal the app should ask about right now (current or earlier time of day, not done).
  Map<String, dynamic>? _nowItem(List<Map<String, dynamic>> daily) {
    final slotIdx = _slotOrder.indexOf(_currentSlot());
    final candidates =
        daily.where((i) {
          final g = i['goal'] as Map<String, dynamic>;
          final idx = _slotOrder.indexOf(
            g['time_of_day'] as String? ?? 'anytime',
          );
          return i['done'] != true &&
              idx >= 0 &&
              idx <= slotIdx &&
              !_snoozed.contains(g['id']);
        }).toList()..sort(
          (a, b) => _slotOrder
              .indexOf((b['goal'] as Map)['time_of_day'] as String)
              .compareTo(
                _slotOrder.indexOf((a['goal'] as Map)['time_of_day'] as String),
              ),
        );
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_error != null) return ErrorView(onRetry: _load, detail: '$_error');
    if (_data == null) return const Center(child: CircularProgressIndicator());
    final lists = _data!['lists'] as Map<String, dynamic>;
    final items = (lists[_periods[_tab]] as List).cast<Map<String, dynamic>>();
    final daily = (lists['daily'] as List).cast<Map<String, dynamic>>();
    final done = items.where((i) => i['done'] == true).length;
    final now = _tab == 0 ? _nowItem(daily) : null;

    Widget row(Map<String, dynamic> item) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GoalRow(
        item: item,
        onToggle: () => _setDone(item, !(item['done'] as bool)),
        onInfo: () => _showWhy(item['goal'] as Map<String, dynamic>),
      ),
    );

    final List<Widget> goalSection;
    if (_tab == 0) {
      // Today: grouped by time of day, so it's obvious what to do now.
      goalSection = [
        for (final slot in [..._slotOrder, 'anytime'])
          if (items.any(
            (i) => ((i['goal'] as Map)['time_of_day'] ?? 'anytime') == slot,
          )) ...[
            _SlotHeader(
              slot: slot,
              items: items
                  .where(
                    (i) =>
                        ((i['goal'] as Map)['time_of_day'] ?? 'anytime') ==
                        slot,
                  )
                  .toList(),
              isNow: slot == _currentSlot(),
            ),
            for (final item in items.where(
              (i) => ((i['goal'] as Map)['time_of_day'] ?? 'anytime') == slot,
            ))
              row(item),
          ],
      ];
    } else {
      goalSection = [for (final item in items) row(item)];
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            done: done,
            total: items.length,
            title: s.t(['plan_today', 'plan_week', 'plan_month'][_tab]),
            week: _data!['plan_week'] as int? ?? 1,
            onPlan: _openPlan,
          ),
          _Centered(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedPills(
                    labels: [s.t('today'), s.t('this_week'), s.t('this_month')],
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 16),
                  if (now != null) ...[
                    _NowCard(
                      item: now,
                      onDone: () => _setDone(now, true),
                      onLater: () => setState(
                        () =>
                            _snoozed.add((now['goal'] as Map)['id'] as String),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  ...goalSection,
                  if (_tab == 0 && _water != null) ...[
                    const SizedBox(height: 10),
                    _WaterCard(
                      water: _water!,
                      onAdd: () => _water1(1),
                      onRemove: () => _water1(-1),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const DisclaimerBanner(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
      child: child,
    ),
  );
}

/// Simple green header: "2 of 6 done" + one thick progress bar.
class _Header extends StatelessWidget {
  const _Header({
    required this.done,
    required this.total,
    required this.title,
    required this.week,
    required this.onPlan,
  });
  final int done;
  final int total;
  final String title;
  final int week;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final ratio = total == 0 ? 0.0 : done / total;
    final complete = total > 0 && done == total;
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
      child: _Centered(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$title · ${s.t('week_n', {'n': week})}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xE6FFFFFF),
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    textStyle: const TextStyle(
                      fontFamily: kFont,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  onPressed: onPlan,
                  child: Text(s.t('view_plan')),
                ),
              ],
            ),
            Text(
              complete
                  ? s.t('cheer_done')
                  : s.t('progress', {'done': done, 'total': total}),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 500),
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 12,
                  color: complete ? AppColors.accent : Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "☀️ Morning   1 of 3" section title on the Today list.
class _SlotHeader extends StatelessWidget {
  const _SlotHeader({
    required this.slot,
    required this.items,
    required this.isNow,
  });
  final String slot;
  final List<Map<String, dynamic>> items;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final done = items.where((i) => i['done'] == true).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          if (_timeImages.containsKey(slot)) ...[
            Img3D(_timeImages[slot]!, size: 32),
            const SizedBox(width: 8),
          ],
          Text(
            s.t(slot),
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          if (isNow) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                s.t('now'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            '$done / ${items.length}',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: done == items.length ? AppColors.ok : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple "it's time" question: what, then two big answers.
class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.item,
    required this.onDone,
    required this.onLater,
  });
  final Map<String, dynamic> item;
  final VoidCallback onDone;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final goal = item['goal'] as Map<String, dynamic>;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.accent, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Img3D('bell', size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.t('now_ask'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warn,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.pick(goal, 'title'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.ok),
                  onPressed: onDone,
                  icon: const Icon(Icons.check_rounded, size: 30),
                  label: Text(s.t('yes_done')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: onLater,
                  child: Text(s.t('later')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({
    required this.water,
    required this.onAdd,
    required this.onRemove,
  });
  final Map<String, dynamic> water;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cups = water['cups'] as int;
    final target = water['target'] as int;
    final reached = cups >= target;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WaterBall(
                value: target == 0 ? 0 : cups / target,
                label: '$cups',
                size: 92,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('water_title'),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      reached
                          ? s.t('water_done')
                          : s.t('water_count', {'n': cups, 'target': target}),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: reached ? AppColors.water : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.water,
                  ),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 30),
                  label: Text(s.t('add_cup')),
                ),
              ),
              if (cups > 0) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(64, 64),
                    ),
                    onPressed: onRemove,
                    child: const Icon(Icons.remove_rounded, size: 30),
                  ),
                ),
              ],
            ],
          ),
          if (water['fluid_caution'] == true) ...[
            const SizedBox(height: 10),
            Text(
              s.t('water_caution'),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.warn,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One goal = one big row. Tap anywhere to tick; ⓘ opens "why this matters".
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.item,
    required this.onToggle,
    required this.onInfo,
  });
  final Map<String, dynamic> item;
  final VoidCallback onToggle;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final goal = item['goal'] as Map<String, dynamic>;
    final done = item['done'] == true;
    final style = CategoryStyle.of(goal['category'] as String?);
    return Material(
      color: done ? AppColors.okBg : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onToggle,
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: done ? AppColors.ok : AppColors.border,
              width: done ? 2.5 : 1.5,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category colour stripe: quick visual grouping without extra text.
                Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: style.color,
                    borderRadius: const BorderRadiusDirectional.horizontal(
                      start: Radius.circular(20),
                    ).resolve(Directionality.of(context)),
                  ),
                ),
                const SizedBox(width: 12),
                Center(child: _CheckCircle(done: done)),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        s.pick(goal, 'title'),
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          color: done ? AppColors.ok : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: IconButton(
                    iconSize: 32,
                    tooltip: s.t('why_matters'),
                    color: AppColors.primary,
                    onPressed: onInfo,
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: done ? AppColors.ok : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: done ? AppColors.ok : const Color(0xFF7D8984),
            width: 3,
          ),
        ),
        child: done
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 30)
            : null,
      ),
    );
  }
}

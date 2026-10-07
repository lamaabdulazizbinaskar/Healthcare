import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/visuals.dart';

const _slotImages = {
  'breakfast': 'sun',
  'lunch': 'sun_cloud',
  'dinner': 'moon',
  'snack': 'herb',
};

const Map<String, Map<String, String>> _tagLabels = {
  'low_salt': {'ar': 'ملح قليل', 'en': 'Low salt'},
  'fibre': {'ar': 'ألياف', 'en': 'Fibre'},
  'no_added_sugar': {'ar': 'بدون سكر مضاف', 'en': 'No added sugar'},
  'legumes': {'ar': 'بقوليات', 'en': 'Legumes'},
  'whole_grain': {'ar': 'حبوب كاملة', 'en': 'Whole grain'},
  'vegetables': {'ar': 'خضار', 'en': 'Vegetables'},
  'protein': {'ar': 'بروتين', 'en': 'Protein'},
  'fish': {'ar': 'سمك', 'en': 'Fish'},
  'dairy': {'ar': 'ألبان', 'en': 'Dairy'},
  'nuts': {'ar': 'مكسرات', 'en': 'Nuts'},
  'fruit': {'ar': 'فاكهة', 'en': 'Fruit'},
  'potassium': {'ar': 'بوتاسيوم', 'en': 'Potassium'},
};

/// "What to eat today": guideline-based meal ideas instead of photographing meals.
class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  Map<String, dynamic>? _data;
  Object? _error;
  final Map<String, int> _choice = {}; // slot -> option index

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AppScope.read(context).api.meals();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_error != null) return ErrorView(onRetry: _load, detail: '$_error');
    if (_data == null) return const Center(child: CircularProgressIndicator());
    final slots = (_data!['slots'] as List).cast<Map<String, dynamic>>();
    final notes = (_data!['notes'] as Map).cast<String, dynamic>();
    final noteList = ((notes[s.lang] ?? notes['en']) as List).cast<String>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        Row(
          children: [
            const Img3D('pot', size: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('food_title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    s.t('food_sub'),
                    style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final slot in slots)
          if ((slot['options'] as List).isNotEmpty) ...[
            _MealCard(
              slot: slot['slot'] as String,
              meal:
                  (slot['options'] as List)[(_choice[slot['slot']] ?? 0) %
                          (slot['options'] as List).length]
                      as Map<String, dynamic>,
              onAnother: () => setState(
                () => _choice[slot['slot'] as String] =
                    (_choice[slot['slot']] ?? 0) + 1,
              ),
            ),
            const SizedBox(height: 14),
          ],
        if (noteList.isNotEmpty)
          _ListCard(
            image: 'sparkles',
            title: s.t('tips'),
            items: noteList,
            sources: (notes['sources'] as List? ?? [])
                .cast<Map<String, dynamic>>(),
            color: AppColors.primaryLight,
          ),
        const SizedBox(height: 14),
        _ListCard(
          image: 'cup',
          title: s.t('drinks'),
          items: (((_data!['drinks'] as Map)[s.lang]) as List).cast<String>(),
          sources: ((_data!['drinks'] as Map)['sources'] as List)
              .cast<Map<String, dynamic>>(),
          color: const Color(0xFFE6F3FC),
        ),
        const SizedBox(height: 14),
        _ListCard(
          image: 'stop',
          title: s.t('limit_these'),
          items: (((_data!['limit'] as Map)[s.lang]) as List).cast<String>(),
          sources: ((_data!['limit'] as Map)['sources'] as List)
              .cast<Map<String, dynamic>>(),
          color: AppColors.warnBg,
        ),
        const SizedBox(height: 16),
        Text(
          s.pick(_data!, 'authored_note'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        const DisclaimerBanner(),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.slot,
    required this.meal,
    required this.onAnother,
  });
  final String slot;
  final Map<String, dynamic> meal;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tags = (meal['tags'] as List).cast<String>();
    final sources = (meal['sources'] as List).cast<Map<String, dynamic>>();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Img3D(_slotImages[slot] ?? 'salad', size: 32),
              const SizedBox(width: 8),
              Text(
                s.t(slot),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(meal['id']),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.pick(meal, 'name'),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in tags)
                      if (_tagLabels.containsKey(t))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.okBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _tagLabels[t]![s.lang]!,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ok,
                            ),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Img3D('red_heart', size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.pick(meal, 'why'),
                        style: const TextStyle(fontSize: 17.5, height: 1.45),
                      ),
                    ),
                  ],
                ),
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      sources.map((x) => x['citation']).join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: onAnother,
            icon: const Icon(Icons.refresh_rounded, size: 26),
            label: Text(s.t('another_idea')),
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.image,
    required this.title,
    required this.items,
    required this.sources,
    required this.color,
  });
  final String image;
  final String title;
  final List<String> items;
  final List<Map<String, dynamic>> sources;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Img3D(image, size: 34),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 9),
                    child: Icon(Icons.circle, size: 8, color: AppColors.ink),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      it,
                      style: const TextStyle(fontSize: 18, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          if (sources.isNotEmpty)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                sources.map((x) => x['citation']).join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

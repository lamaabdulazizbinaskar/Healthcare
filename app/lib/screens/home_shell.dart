import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'ask_screen.dart';
import 'checklist_screen.dart';
import 'food_screen.dart';
import 'readings_screen.dart';
import 'report_screen.dart';
import 'symptom_check_screen.dart';

/// Max content width so the app reads like a phone screen on desktop browsers too.
const kMaxContentWidth = 600.0;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _settings() {
    final state = AppScope.read(context);
    final s = S.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.t('settings'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.translate_rounded),
                onPressed: () {
                  Navigator.pop(ctx);
                  state.setLang(state.lang == 'ar' ? 'en' : 'ar');
                },
                label: Text(s.t('switch_lang')),
              ),
              const SizedBox(height: 12),
              if (state.userId == demoUserId) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await state.api.resetDemo();
                    setState(() => _index = 0);
                    await state.useDemo();
                  },
                  label: Text(s.t('reset_demo')),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  Navigator.pop(ctx);
                  state.signOut();
                },
                label: Text(s.t('restart')),
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
    final state = AppScope.of(context);
    final name =
        (state.profile?['name'] as String?)?.trim().split(' ').first ?? '';
    final date = DateFormat(
      state.lang == 'ar' ? 'EEEE، d MMMM' : 'EEEE, d MMMM',
      state.lang,
    ).format(DateTime.now());
    // Rebuilt on every tab switch so each tab shows fresh data (e.g. report after ticking goals).
    final page = switch (_index) {
      0 => ChecklistScreen(key: ValueKey('c-${state.userId}')),
      1 => ReadingsScreen(key: ValueKey('b-${state.userId}')),
      2 => const AskScreen(),
      3 => const FoodScreen(),
      _ => ReportScreen(key: ValueKey('r-${state.userId}')),
    };
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name.isEmpty ? s.t('app_name') : '${s.t('hello')} $name',
                style: const TextStyle(
                  fontFamily: kFont,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                date,
                style: const TextStyle(
                  fontFamily: kFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xD9FFFFFF),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 2),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.danger,
                minimumSize: const Size(0, 50),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                textStyle: const TextStyle(
                  fontFamily: kFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SymptomCheckScreen()),
              ),
              icon: const Icon(Icons.emergency_rounded, size: 24),
              label: Text(s.t('feel_unwell')),
            ),
          ),
          IconButton(
            iconSize: 30,
            color: Colors.white,
            onPressed: _settings,
            icon: const Icon(Icons.settings_rounded),
            tooltip: s.t('settings'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      // The checklist manages its own width so its green header can span the full screen.
      body: _index == 0
          ? page
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                child: page,
              ),
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.checklist_rounded),
              label: s.t('tab_today'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.favorite_border_rounded),
              selectedIcon: const Icon(Icons.favorite_rounded),
              label: s.t('tab_readings'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.forum_outlined),
              selectedIcon: const Icon(Icons.forum_rounded),
              label: s.t('tab_ask'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.restaurant_outlined),
              selectedIcon: const Icon(Icons.restaurant_rounded),
              label: s.t('tab_food'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insert_chart_outlined_rounded),
              selectedIcon: const Icon(Icons.insert_chart_rounded),
              label: s.t('tab_report'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(); // Arabic + English day/month names
  final state = AppState()..init();
  runApp(AppScope(state: state, child: const KhutwaApp()));
}

class KhutwaApp extends StatelessWidget {
  const KhutwaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return MaterialApp(
      title: 'Khutwa',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Arabic locale => Flutter lays out the whole UI right-to-left automatically.
      locale: Locale(state.lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        // Respect the user's OS font scaling but never go below our large base sizes.
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.of(
            context,
          ).textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6),
        ),
        child: child!,
      ),
      home: !state.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : state.hasPlan
          ? const HomeShell()
          : const WelcomeScreen(),
    );
  }
}

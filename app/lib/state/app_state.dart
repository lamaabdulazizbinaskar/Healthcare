import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

const demoUserId = 'demo-patient';

/// App-wide state: language, current user id, and whether the user has a plan.
class AppState extends ChangeNotifier {
  String lang = 'ar';
  String? userId;
  bool hasPlan = false;
  bool ready = false;
  Map<String, dynamic>? profile;
  String aiMode = '';

  ApiClient get api => ApiClient(userId ?? demoUserId);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    lang = prefs.getString('lang') ?? 'ar';
    userId = prefs.getString('userId');
    if (userId != null) {
      try {
        final p = await api.profile();
        hasPlan = p['has_plan'] == true;
        profile = p['profile'] as Map<String, dynamic>?;
      } catch (_) {
        hasPlan = false;
      }
    }
    try {
      aiMode = (await api.health())['ai_mode'] as String? ?? '';
    } catch (_) {}
    ready = true;
    notifyListeners();
  }

  Future<void> setLang(String value) async {
    lang = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', value);
    if (hasPlan) {
      try {
        await api.setLanguage(value);
      } catch (_) {}
    }
  }

  Future<void> useDemo() async {
    await _setUser(demoUserId);
    final p = await api.profile();
    hasPlan = p['has_plan'] == true;
    profile = p['profile'] as Map<String, dynamic>?;
    notifyListeners();
  }

  /// A new local user id for a real (non-demo) onboarding. Firebase Auth would replace this.
  Future<void> startNewUser() async {
    final id =
        'user-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 30).toRadixString(36)}';
    await _setUser(id);
    hasPlan = false;
    profile = null;
    notifyListeners();
  }

  void onboarded(Map<String, dynamic> newProfile) {
    profile = newProfile;
    hasPlan = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    userId = null;
    hasPlan = false;
    profile = null;
    notifyListeners();
  }

  Future<void> _setUser(String id) async {
    userId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', id);
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

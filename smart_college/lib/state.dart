import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'theme.dart';

enum Dest {
  dashboard,
  students,
  studentProfile,
  studentForm,
  teachers,
  classes,
  timetable,
  scan,
  register,
  attendance,
  fees,
  collect,
  exams,
  results,
  leaves,
  homework,
  assignments,
  announcements,
  notifications,
  reports,
  more,
  portal,
  profile,
  settings,
  test,
}

class AppModel extends ChangeNotifier {
  final api = CollegeApi();
  bool signedIn = false;
  bool ready = false;
  bool urdu = false;
  String role = 'admin';
  Dest dest = Dest.dashboard;
  int? openStudent;
  Map<String, dynamic> user = {};

  String t(String en, String ur) => urdu ? ur : en;

  String get displayName => (user['name'] ?? '').toString();

void applyBrand(Map data) {
    CollegeColors.apply(data);
    notifyListeners();
  }

  Future<void> loadBrand() async {
    try {
      final data = Map<String, dynamic>.from(await api.branding());
      CollegeColors.apply(data);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> restore() async {
    await loadBrand();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('sms_token');
    urdu = prefs.getString('sms_locale') == 'ur';
    if (saved != null && saved.isNotEmpty) {
      api.token = saved;
      try {
        user = Map<String, dynamic>.from(await api.get('/me') as Map);
        role = (user['role'] ?? 'admin').toString();
        signedIn = true;
        dest = role == 'student' || role == 'parent' ? Dest.portal : Dest.dashboard;
        urdu = (user['locale'] ?? (urdu ? 'ur' : 'en')) == 'ur';
      } catch (_) {
        api.token = null;
        await prefs.remove('sms_token');
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final result = await api.login(email.trim(), password);
    api.token = result['token']?.toString();
    user = Map<String, dynamic>.from(result['user'] as Map);
    role = (user['role'] ?? 'admin').toString();
    urdu = user['locale'] == 'ur';
    signedIn = true;
    dest = role == 'student' || role == 'parent' ? Dest.portal : Dest.dashboard;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sms_token', api.token ?? '');
    await prefs.setString('sms_locale', urdu ? 'ur' : 'en');
    notifyListeners();
  }

  Future<void> signOut() async {
    await api.logout();
    api.token = null;
    signedIn = false;
    user = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sms_token');
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    urdu = !urdu;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sms_locale', urdu ? 'ur' : 'en');
    if (signedIn) {
      try {
        await api.updateLocale(urdu ? 'ur' : 'en');
      } catch (_) {}
    }
  }

  void go(Dest next, {int? student}) {
    if (student != null) openStudent = student;
    dest = next;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({required AppModel model, required super.child, super.key}) : super(notifier: model);

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!.notifier!;
  }
}

import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'shell.dart';
import 'splash.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  runApp(const SmartCollegeApp());
}

class SmartCollegeApp extends StatefulWidget {
  const SmartCollegeApp({super.key});

  @override
  State<SmartCollegeApp> createState() => _SmartCollegeAppState();
}

class _SmartCollegeAppState extends State<SmartCollegeApp> {
  final model = AppModel();
  bool splashHold = true;

  @override
  void initState() {
    super.initState();
    model.restore();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => splashHold = false);
    });
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      model: model,
      child: AnimatedBuilder(
        animation: model,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: model.urdu ? 'سمارٹ کالج' : 'Smart College',
            theme: collegeTheme(),
            home: !model.ready || splashHold
                ? const SplashScreen()
                : model.signedIn
                    ? const CollegeShell()
                    : const LoginScreen(),
          );
        },
      ),
    );
  }
}

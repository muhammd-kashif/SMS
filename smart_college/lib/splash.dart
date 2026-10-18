import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Align(alignment: Alignment.topCenter, child: TealWave(height: 210)),
          Align(alignment: Alignment.bottomCenter, child: TealWave(height: 160, flip: true)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SchoolMark(size: 148),
                  const SizedBox(height: 18),
                  Text(
                    CollegeColors.schoolName,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CollegeColors.primary, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'SCHOOL MANAGEMENT',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CollegeColors.primary, fontSize: 13, letterSpacing: 1.8, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: CollegeColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

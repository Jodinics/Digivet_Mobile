import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const DigiVetApp());
}

class DigiVetApp extends StatelessWidget {
  const DigiVetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
        home: const LandingScreen(),
    );
  }
}
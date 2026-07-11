import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://jgyjzgfczawzgauuhxeh.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpneWp6Z2ZjemF3emdhdXVoeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgyMDcyNDQsImV4cCI6MjA5Mzc4MzI0NH0.4eO1AHWhj1_8KzJVEO6pqzwR-aNXBoc85BDXAXt6XMo',
  );

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
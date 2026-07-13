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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        canvasColor: Colors.white,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        appBarTheme: const AppBarTheme(
          surfaceTintColor: Colors.transparent,
        ),
        // This removes the "gray" overlay on all buttons when pressed
        buttonTheme: const ButtonThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        // For Material 3 buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            splashFactory: NoSplash.splashFactory,
            foregroundColor: const Color(0xFF9E1B1B),
          ),
        ),
      ),
      home: const LandingScreen(),
    );
  }
}
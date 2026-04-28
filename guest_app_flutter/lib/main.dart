import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const GuestApp());
}

class GuestApp extends StatelessWidget {
  const GuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrisisSync — Emergency Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0891B2),
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      // Always start at landing — it reads the token from the URL
      home: const LandingScreen(),
    );
  }
}

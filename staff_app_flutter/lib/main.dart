import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.bgPrimary,
  ));
  runApp(const CrisisSyncStaffApp());
}

class CrisisSyncStaffApp extends StatelessWidget {
  const CrisisSyncStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrisisSync',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppTheme.bgPrimary,
        primaryColor: AppTheme.accentCyan,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.accentCyan,
          secondary: AppTheme.sosRed,
          surface: AppTheme.bgSecondary,
          error: AppTheme.criticalRed,
        ),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}


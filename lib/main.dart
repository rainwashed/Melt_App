import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'models/user_profile.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await ApiService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFEB1555),
        scaffoldBackgroundColor: const Color(0xFF111827),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEB1555),
          secondary: Color(0xFFFFAB00),
          surface: Color(0xFF1F2937),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/setup': (context) => const ProfileSetupScreen(),
        '/home': (context) => const RecordingScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}

/// Splash screen that checks if profile setup is complete
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    // Wait a moment for splash effect
    await Future.delayed(const Duration(seconds: 1));

    // Check if profile setup is complete
    final isSetupComplete = await UserProfile.isSetupComplete();

    if (mounted) {
      if (isSetupComplete) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/setup');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEB1555).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Melt',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your legal guardian',
              style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEB1555)),
            ),
          ],
        ),
      ),
    );
  }
}

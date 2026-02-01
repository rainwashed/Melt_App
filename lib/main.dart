import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models/user_profile.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/recording_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        primaryColor: const Color(0xFF00D9FF),
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00D9FF),
          secondary: const Color(0xFFEB1555),
          surface: const Color(0xFF1D1E33),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/setup': (context) => const ProfileSetupScreen(),
        '/home': (context) => const RecordingScreen(),
        '/settings': (context) => const SettingsScreen(),
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
      backgroundColor: const Color(0xFF0A0E21),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1D1E33),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D9FF).withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance,
                size: 60,
                color: Color(0xFF00D9FF),
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
              style: TextStyle(fontSize: 16, color: Color(0xFF8D8E98)),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D9FF)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// User profile model for storing user preferences and information
class UserProfile {
  final String language;
  final int age;
  final String name;

  UserProfile({required this.language, required this.age, required this.name});

  Map<String, dynamic> toJson() {
    return {'language': language, 'age': age, 'name': name};
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      language: json['language'] as String,
      age: json['age'] as int,
      name: json['name'] as String,
    );
  }

  /// Save profile to local storage
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    await prefs.setInt('age', age);
    await prefs.setString('name', name);
    await prefs.setBool('profile_setup_complete', true);
  }

  /// Load profile from local storage
  static Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isSetup = prefs.getBool('profile_setup_complete') ?? false;

    if (!isSetup) return null;

    return UserProfile(
      language: prefs.getString('language') ?? 'English',
      age: prefs.getInt('age') ?? 18,
      name: prefs.getString('name') ?? '',
    );
  }

  /// Check if profile setup is complete
  static Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('profile_setup_complete') ?? false;
  }

  /// Clear profile data
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('language');
    await prefs.remove('age');
    await prefs.remove('name');
    await prefs.remove('profile_setup_complete');
  }
}

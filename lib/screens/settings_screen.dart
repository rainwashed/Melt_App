import 'package:flutter/material.dart';
import '../api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = ApiService().baseUrl;
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await ApiService().setBaseUrl(_apiUrlController.text);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00D9FF)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              const Text(
                'API Configuration',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Configure the backend server URL',
                style: TextStyle(fontSize: 14, color: Color(0xFF8D8E98)),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: _apiUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'API Base URL',
                  labelStyle: const TextStyle(color: Color(0xFF8D8E98)),
                  hintText: 'http://localhost:3000',
                  hintStyle: const TextStyle(color: Color(0xFF8D8E98)),
                  filled: true,
                  fillColor: const Color(0xFF1D1E33),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.api, color: Color(0xFF00D9FF)),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF00D9FF),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Information',
                          style: TextStyle(
                            color: Color(0xFF00D9FF),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'The API URL should point to your backend server. '
                      'Make sure the server is running and accessible from your device.',
                      style: TextStyle(
                        color: Color(0xFF8D8E98),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFF00D9FF).withOpacity(0.5),
                ),
                child: const Text(
                  'Save Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

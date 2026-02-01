import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_profile.dart';
import '../models/incident.dart';
import '../api_service.dart';
import '../services/audio_buffer_manager.dart';
import '../services/volume_key_handler.dart';
import '../services/emergency_contact_manager.dart';
import '../services/incident_service.dart';
import './emergency_contacts_screen.dart';
import './history_screen.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AudioBufferManager _bufferManager = AudioBufferManager();
  final VolumeKeyHandler _volumeKeyHandler = VolumeKeyHandler();
  final EmergencyContactManager _emergencyContactManager =
      EmergencyContactManager();
  final IncidentService _incidentService = IncidentService();

  bool _isProcessing = false;
  String _currentTranscript = '';
  String? _legalAdvice;
  UserProfile? _userProfile;
  String? _currentAddress;
  bool _isDangerous = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _pendingSmsMessage;

  Timer? _updateTimer;
  late AnimationController _pulseController;
  late AnimationController _borderPulseController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _transcriptScrollController = ScrollController();

  // Colors matching HTML reference
  static const Color _primaryColor = Color(0xFFEB1555);
  static const Color _alertColor = Color(0xFFFFAB00);
  static const Color _backgroundDark = Color(0xFF111827);
  static const Color _cardDark = Color(0xFF1F2937);
  static const Color _textPrimaryDark = Color(0xFFF9FAFB);
  static const Color _textSecondaryDark = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initializeRecording();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _borderPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _bufferManager.isRecording) {
        setState(() {
          _recordingSeconds = _bufferManager.recordingDurationSeconds;
        });
      }
    });

    // Listen for audio completion to launch SMS
    _audioPlayer.onPlayerComplete.listen((_) {
      if (_pendingSmsMessage != null) {
        _launchSmsWithContacts(_pendingSmsMessage!);
        _pendingSmsMessage = null;
      }
    });
  }

  @override
  void dispose() {
    _bufferManager.dispose();
    _volumeKeyHandler.dispose();
    _updateTimer?.cancel();
    _recordingTimer?.cancel();
    _pulseController.dispose();
    _borderPulseController.dispose();
    _audioPlayer.dispose();
    _transcriptScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserProfile.load();
    setState(() {
      _userProfile = profile;
    });
  }

  Future<void> _initializeRecording() async {
    await _requestPermissions();

    final hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) {
      return;
    }

    try {
      final address = await _getCurrentAddress();
      setState(() {
        _currentAddress = address;
      });

      await _bufferManager.startContinuousRecording();
      await _volumeKeyHandler.initialize();
      _volumeKeyHandler.onVolumeKeyPressed = _onVolumeKeyPressed;
    } catch (e) {
      print('Failed to start recording: $e');
    }
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.location].request();
  }

  Future<String?> _getCurrentAddress() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await Permission.location.status;
      if (!permission.isGranted) return null;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String address = '';
        if (place.street != null && place.street!.isNotEmpty) {
          address += place.street!;
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          address += address.isNotEmpty
              ? ', ${place.locality}'
              : place.locality!;
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          address += address.isNotEmpty
              ? ', ${place.administrativeArea}'
              : place.administrativeArea!;
        }
        return address.isNotEmpty ? address : null;
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  Future<void> _onVolumeKeyPressed() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final address = await _getCurrentAddress();
      setState(() {
        _currentAddress = address;
      });

      final combinedAudioPath = await _bufferManager.extractBuffer();
      await _processRecording(combinedAudioPath);
    } catch (e) {
      print('Failed to process audio: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processRecording(String audioPath) async {
    try {
      final transcript = await _apiService.transcribeAudio(
        audioPath,
        streetAddress: _currentAddress,
      );

      setState(() {
        _currentTranscript = transcript;
      });

      // Auto-scroll transcript to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_transcriptScrollController.hasClients) {
          _transcriptScrollController.animateTo(
            _transcriptScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      final judgeResponse = await _apiService.judgeTranscript(transcript);
      final isDangerous = judgeResponse['dangerous'] == true;

      setState(() {
        _isDangerous = isDangerous;
      });

      String? advice;
      if (isDangerous) {
        final infoResponse = await _apiService.getInformation(transcript);
        advice = infoResponse['information'] as String?;

        setState(() {
          _legalAdvice = advice;
        });

        if (advice != null && advice.isNotEmpty) {
          try {
            // Get communicate message for SMS
            final communicateMsg = await _apiService.communicate(
              transcript: transcript,
              location: _currentAddress ?? 'Unknown Location',
              name: _userProfile?.name ?? 'User',
            );
            _pendingSmsMessage = communicateMsg;

            // Play TTS - SMS will be launched when audio completes
            final audioBytes = await _apiService.textToSpeech(advice);
            final tempDir = await getTemporaryDirectory();
            final tempFile = File(
              '${tempDir.path}/tts_response_${DateTime.now().millisecondsSinceEpoch}.mp3',
            );
            await tempFile.writeAsBytes(audioBytes);
            await _audioPlayer.setPlaybackRate(1.2);
            await _audioPlayer.play(DeviceFileSource(tempFile.path));
          } catch (e) {
            print('TTS Playback error: $e');
          }
        }
      } else {
        setState(() {
          _legalAdvice = null;
        });
      }

      // Save incident to history
      final incident = Incident(
        audioPath: audioPath,
        transcript: transcript,
        aiResponse: advice,
        location: _currentAddress,
        isDangerous: isDangerous,
      );
      await _incidentService.saveIncident(incident);
    } catch (e) {
      print('Processing failed: $e');
    }
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  /// Launch SMS app with emergency contacts and message
  Future<void> _launchSmsWithContacts(String message) async {
    try {
      // Load emergency contacts
      final contacts = await _emergencyContactManager.loadContacts();
      final enabledContacts = contacts.where((c) => c.isEnabled).toList();

      if (enabledContacts.isEmpty) {
        print('No enabled emergency contacts found');
        return;
      }

      // Get phone numbers (clean them for SMS URI)
      final phoneNumbers = enabledContacts
          .map((c) {
            return c.phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
          })
          .join(',');

      // Build SMS URI with recipients and body
      final uri = Uri(
        scheme: 'sms',
        path: phoneNumbers,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        print('Could not launch SMS app');
      }
    } catch (e) {
      print('Error launching SMS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundDark,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _borderPulseController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                border: _isDangerous
                    ? Border.all(
                        color: _primaryColor.withOpacity(
                          0.5 + 0.3 * _borderPulseController.value,
                        ),
                        width: 4,
                      )
                    : null,
              ),
              child: child,
            );
          },
          child: Column(
            children: [
              // Header with live recording indicator
              _buildHeader(),

              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Legal situation detected / Monitoring header
                      _buildStatusHeader(),

                      const SizedBox(height: 16),

                      // Warning card (shown when dangerous) - with limited height
                      if (_isDangerous && _legalAdvice != null)
                        Flexible(flex: 2, child: _buildWarningCard()),

                      if (_isDangerous && _legalAdvice != null)
                        const SizedBox(height: 12),

                      // Transcript area - takes priority
                      Flexible(flex: 3, child: _buildTranscriptArea()),

                      const SizedBox(height: 12),

                      // Action buttons
                      _buildActionButtons(),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and Live recording indicator
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              // Live recording indicator
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 12 + (_pulseController.value * 8),
                            height: 12 + (_pulseController.value * 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryColor.withOpacity(
                                0.3 * (1 - _pulseController.value),
                              ),
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE RECORDING',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          // Settings button
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: _textSecondaryDark,
            ),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isDangerous
                ? _primaryColor.withOpacity(0.15)
                : Colors.green.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isDangerous ? Icons.gavel : Icons.shield_outlined,
            color: _isDangerous ? _primaryColor : Colors.green,
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _isDangerous ? 'LEGAL SITUATION\nDETECTED' : 'MONITORING',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimaryDark,
            fontSize: _isDangerous ? 28 : 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: _alertColor, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IMMEDIATE ACTION REQUIRED',
                    style: TextStyle(
                      color: _alertColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _legalAdvice ?? 'Follow legal advice',
                    style: const TextStyle(
                      color: _textPrimaryDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AUDIO TRANSCRIPT',
                style: TextStyle(
                  color: _textSecondaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${_formatDuration(_recordingSeconds)} / 1:00',
                style: const TextStyle(
                  color: _primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF374151)),
          const SizedBox(height: 8),
          // Transcript content
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.1, 0.9, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _transcriptScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentTranscript.isNotEmpty) ...[
                      Text(
                        _currentTranscript,
                        style: const TextStyle(
                          color: _textPrimaryDark,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_isProcessing)
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              color: _textSecondaryDark,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '[Listening...]',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.contact_phone_outlined,
            label: 'Edit Contacts',
            disabled: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmergencyContactsScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            icon: Icons.history,
            label: 'History',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, color: disabled ? Colors.grey : _textSecondaryDark),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? Colors.grey : _textPrimaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Material(
            color: _cardDark,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                // Quick exit - close app immediately
                SystemNavigator.pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.power_settings_new, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    const Text(
                      'QUICK EXIT & LOCK',
                      style: TextStyle(
                        color: _textPrimaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Press volume key to analyze last 60 seconds',
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      ),
    );
  }
}

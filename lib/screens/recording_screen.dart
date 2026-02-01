import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_profile.dart';
import '../api_service.dart';
import '../services/audio_buffer_manager.dart';
import '../services/volume_key_handler.dart';
import '../services/emergency_contact_manager.dart';
import './emergency_contacts_screen.dart';

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

  bool _isProcessing = false;
  String _currentTranscript = '';
  String? _legalAdvice;
  UserProfile? _userProfile;
  String? _currentAddress;
  String? _statusMessage;
  Color _statusColor = Colors.red;
  Timer? _statusTimer;

  DateTime? _lastTriggerTime;
  int _bufferSegmentCount = 0;
  Timer? _updateTimer;

  late AnimationController _pulseController;
  late AnimationController _dangerController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  void _showStatus(String message, {Color color = Colors.red}) {
    _statusTimer?.cancel();
    setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
    _startStatusTimer();
  }

  void _startStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _statusMessage = null;
        });
      }
    });
  }

  void _handleStatusPointerDown() {
    _statusTimer?.cancel();
  }

  void _handleStatusPointerUp() {
    _startStatusTimer();
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initializeRecording();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _dangerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Update buffer status periodically
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _bufferSegmentCount = _bufferManager.segmentCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _bufferManager.dispose();
    _volumeKeyHandler.dispose();
    _updateTimer?.cancel();
    _pulseController.dispose();
    _dangerController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserProfile.load();
    setState(() {
      _userProfile = profile;
    });
  }

  Future<void> _initializeRecording() async {
    // Request permissions
    await _requestPermissions();

    final hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) {
      if (mounted) {
        _showStatus('Microphone permission is required');
      }
      return;
    }

    try {
      // Get initial address
      final address = await _getCurrentAddress();
      setState(() {
        _currentAddress = address;
      });

      // Start continuous recording
      await _bufferManager.startContinuousRecording();

      // Initialize volume key handler
      await _volumeKeyHandler.initialize();
      _volumeKeyHandler.onVolumeKeyPressed = _onVolumeKeyPressed;

      if (mounted) {
        _showStatus(
          'Continuous recording started${_currentAddress != null ? '\nLocation: $_currentAddress' : ''}',
          color: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        _showStatus('Failed to start continuous recording: $e');
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Request microphone and location permissions
    final statuses = await [
      Permission.microphone,
      Permission.location,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      if (mounted) {
        _showStatus('Microphone permission is required for recording');
      }
    }

    if (statuses[Permission.location] != PermissionStatus.granted) {
      if (mounted) {
        _showStatus(
          'Location permission helps identify your location',
          color: Colors.orange,
        );
      }
    }
  }

  /// Gets the user's current street address from GPS coordinates
  Future<String?> _getCurrentAddress() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check location permission
      final permission = await Permission.location.status;
      if (!permission.isGranted) {
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Convert coordinates to address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Format the street address
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
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          address += address.isNotEmpty
              ? ' ${place.postalCode}'
              : place.postalCode!;
        }
        if (place.country != null && place.country!.isNotEmpty) {
          address += address.isNotEmpty ? ', ${place.country}' : place.country!;
        }

        return address.isNotEmpty ? address : null;
      }

      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  /// Called when volume key is pressed
  Future<void> _onVolumeKeyPressed() async {
    if (_isProcessing) {
      print('Already processing, ignoring volume key press');
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastTriggerTime = DateTime.now();
    });

    try {
      // Get fresh location
      final address = await _getCurrentAddress();
      setState(() {
        _currentAddress = address;
      });

      // Extract buffer
      final combinedAudioPath = await _bufferManager.extractBuffer();

      // Process the audio
      await _processRecording(combinedAudioPath);
    } catch (e) {
      if (mounted) {
        _showStatus('Failed to process audio: $e');
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processRecording(String audioPath) async {
    try {
      // 1. Transcribe audio with street address
      final transcript = await _apiService.transcribeAudio(
        audioPath,
        streetAddress: _currentAddress,
      );

      setState(() {
        _currentTranscript = transcript;
      });

      // 2. Judge if dangerous
      final judgeResponse = await _apiService.judgeTranscript(transcript);
      final isDangerous = judgeResponse['dangerous'] == true;

      if (isDangerous) {
        // Trigger danger animation
        _dangerController.forward(from: 0).then((_) {
          _dangerController.reverse();
        });

        // 3. Get Information (legal advice)
        final infoResponse = await _apiService.getInformation(transcript);

        setState(() {
          _legalAdvice = infoResponse['information'] as String?;
        });

        // 4. TTS - Use legal advice for audio playback
        if (_legalAdvice != null && _legalAdvice!.isNotEmpty) {
           try {
             final audioBytes = await _apiService.textToSpeech(_legalAdvice!);
             
             // Save to temp file to play
             final tempDir = await getTemporaryDirectory();
             final tempFile = File('${tempDir.path}/tts_response_${DateTime.now().millisecondsSinceEpoch}.mp3');
             await tempFile.writeAsBytes(audioBytes);
             
             // Play audio
             await _audioPlayer.play(DeviceFileSource(tempFile.path));
           } catch (e) {
             print('TTS Playback error: $e');
             if (mounted) {
               _showStatus('TTS Error: $e');
             }
           }
        }

        // Show advice dialog
        if (mounted && _legalAdvice != null) {
          _showLegalAdviceDialog(_legalAdvice!);
        }
      } else {
        // Clear previous advice if not dangerous
        setState(() {
          _legalAdvice = null;
        });
      }
    } catch (e) {
      if (mounted) {
        _showStatus('Processing failed: $e');
      }
    }
  }

  void _showLegalAdviceDialog(String advice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Legal Advice',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            advice,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Melt',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.contacts_outlined,
              color: const Color(0xFF00D9FF).withOpacity(0.4),
            ),
            onPressed: null, // Disabled as requested
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF00D9FF)),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Status indicator
                AnimatedBuilder(
                  animation: _dangerController,
                  builder: (context, child) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: _legalAdvice != null
                          ? Colors.amber.withOpacity(
                              0.2 + _dangerController.value * 0.3,
                            )
                          : Colors.green.withOpacity(0.2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _legalAdvice != null
                                ? Icons.warning
                                : Icons.check_circle,
                            color: _legalAdvice != null
                                ? Colors.amber
                                : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _legalAdvice != null
                                ? 'Legal Situation Detected'
                                : 'Monitoring',
                            style: TextStyle(
                              color: _legalAdvice != null
                                  ? Colors.amber
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Continuous recording indicator
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = 1.0 + (_pulseController.value * 0.1);

                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFEB1555),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFEB1555,
                                      ).withOpacity(0.5),
                                      blurRadius: 30,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.mic,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          'Recording Continuously',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Press Volume Key to Send Last 60s',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24),

                        // Buffer status
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1E33),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Buffer Status',
                                    style: TextStyle(
                                      color: Color(0xFF00D9FF),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$_bufferSegmentCount/12 segments',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: _bufferSegmentCount / 12,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00D9FF),
                                ),
                              ),
                              if (_lastTriggerTime != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Last triggered: ${_formatTime(_lastTriggerTime!)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        if (_isProcessing)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Column(
                              children: const [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF00D9FF),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Processing audio...',
                                  style: TextStyle(color: Color(0xFF8D8E98)),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 40),

                        // Current transcript
                        if (_currentTranscript.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1E33),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.transcribe,
                                      color: Color(0xFF00D9FF),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Latest Transcript',
                                      style: TextStyle(
                                        color: Color(0xFF00D9FF),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _currentTranscript,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Legal advice
                        if (_legalAdvice != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.gavel, color: Colors.amber),
                                      SizedBox(width: 8),
                                      Text(
                                        'Legal Advice',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _legalAdvice!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_statusMessage != null)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Listener(
                  onPointerDown: (_) => _handleStatusPointerDown(),
                  onPointerUp: (_) => _handleStatusPointerUp(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () {
                            setState(() {
                              _statusMessage = null;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }
}

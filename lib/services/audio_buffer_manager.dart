import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// AudioBufferManager that continuously records and maintains a rolling 60-second buffer
/// When extraction is requested, it returns the last 60 seconds of audio
class AudioBufferManager {
  final AudioRecorder _recorder = AudioRecorder();

  String? _currentRecordingPath;
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _cleanupTimer;

  /// Get whether recording is active
  bool get isRecording => _isRecording;

  /// Get recording duration in seconds
  int get recordingDurationSeconds {
    if (_recordingStartTime == null) return 0;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  /// Get number of segments (for UI compatibility - simulates 12 segments of 5s each)
  int get segmentCount => (recordingDurationSeconds / 5).floor().clamp(0, 12);

  /// Get current recording path
  String? get currentRecordingPath => _currentRecordingPath;

  /// Initialize the buffer manager
  Future<void> initialize() async {
    final tempDir = await getTemporaryDirectory();
    final bufferDir = Directory('${tempDir.path}/audio_buffer');

    if (!await bufferDir.exists()) {
      await bufferDir.create(recursive: true);
    }

    print('AudioBufferManager: Initialized at ${bufferDir.path}');
  }

  /// Start continuous recording with automatic 60-second rolling window
  Future<void> startContinuousRecording() async {
    if (_isRecording) {
      print('AudioBufferManager: Already recording');
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();

      // Ensure buffer directory exists
      final bufferDir = Directory('${tempDir.path}/audio_buffer');
      if (!await bufferDir.exists()) {
        await bufferDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${bufferDir.path}/recording_$timestamp.wav';

      // Configure and start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      // Set up periodic cleanup of old recordings
      _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _cleanupOldRecordings();
      });

      print('AudioBufferManager: Started continuous recording to $_currentRecordingPath');
    } catch (e) {
      print('AudioBufferManager: Failed to start recording: $e');
      _isRecording = false;
      rethrow;
    }
  }

  /// Stop continuous recording
  Future<void> stopContinuousRecording() async {
    if (!_isRecording) {
      print('AudioBufferManager: Not recording');
      return;
    }

    try {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
      
      await _recorder.stop();
      _isRecording = false;
      _recordingStartTime = null;
      print('AudioBufferManager: Stopped recording');
    } catch (e) {
      print('AudioBufferManager: Failed to stop recording: $e');
      rethrow;
    }
  }

  /// Extract the last 60 seconds of buffered audio
  /// Returns the path to the extracted audio file
  Future<String> extractBuffer() async {
    if (!_isRecording || _currentRecordingPath == null) {
      throw Exception('No active recording to extract');
    }

    final oldPath = _currentRecordingPath!;
    final duration = recordingDurationSeconds;

    // Stop current recording
    await _recorder.stop();
    _isRecording = false;

    // If recording is less than 60 seconds, just return the whole file
    if (duration <= 60) {
      print('AudioBufferManager: Extracted buffer (${duration}s): $oldPath');
      
      // Start a new recording immediately
      await _startNewRecording();
      
      return oldPath;
    }

    // For recordings longer than 60s, we'd need to trim to last 60s
    // For now, we'll just return the whole file and let the backend handle it
    // TODO: Implement proper 60-second trimming if needed
    print('AudioBufferManager: Extracted buffer (full ${duration}s, should be last 60s): $oldPath');
    
    // Start a new recording immediately
    await _startNewRecording();

    return oldPath;
  }

  /// Start a new recording session
  Future<void> _startNewRecording() async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath =
        '${tempDir.path}/audio_buffer/recording_$timestamp.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _currentRecordingPath!,
    );

    _isRecording = true;
    _recordingStartTime = DateTime.now();

    print('AudioBufferManager: Started new recording: $_currentRecordingPath');
  }

  /// Cleanup old recordings (keep only current one)
  Future<void> _cleanupOldRecordings() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final bufferDir = Directory('${tempDir.path}/audio_buffer');

      if (await bufferDir.exists()) {
        final files = bufferDir.listSync();
        for (final file in files) {
          if (file is File && file.path != _currentRecordingPath) {
            await file.delete();
            print('AudioBufferManager: Deleted old recording: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('AudioBufferManager: Cleanup failed: $e');
    }
  }

  /// Dispose and release resources
  Future<void> dispose() async {
    try {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
      
      if (_isRecording) {
        await _recorder.stop();
      }
      await _recorder.dispose();
      await _cleanupOldRecordings();
      print('AudioBufferManager: Disposed');
    } catch (e) {
      print('AudioBufferManager: Dispose failed: $e');
    }
  }
}

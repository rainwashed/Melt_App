import 'dart:async';
import 'package:volume_watcher/volume_watcher.dart';

/// Handles volume key press events to trigger buffer extraction
class VolumeKeyHandler {
  double? _lastVolume;
  DateTime? _lastTriggerTime;
  int? _listenerId;

  /// Callback function to execute when volume key is pressed
  Function()? onVolumeKeyPressed;

  /// Initialize volume key listener
  Future<void> initialize() async {
    try {
      // Get initial volume (it's a getter, not a method)
      _lastVolume = await VolumeWatcher.getCurrentVolume;

      // Listen for volume changes (returns listener ID)
      _listenerId = VolumeWatcher.addListener((double volume) {
        _onVolumeChanged(volume);
      });

      print('VolumeKeyHandler: Initialized');
    } catch (e) {
      print('VolumeKeyHandler: Failed to initialize: $e');
    }
  }

  /// Handle volume change events
  void _onVolumeChanged(double newVolume) {
    // Check if volume actually changed (volume key was pressed)
    if (_lastVolume != null && _lastVolume != newVolume) {
      // Debounce: Ignore if last trigger was less than 1 second ago
      final now = DateTime.now();
      if (_lastTriggerTime != null &&
          now.difference(_lastTriggerTime!).inMilliseconds < 1000) {
        _lastVolume = newVolume;
        return;
      }

      // Trigger callback
      _lastTriggerTime = now;
      print(
        'VolumeKeyHandler: Volume key pressed ($_lastVolume -> $newVolume)',
      );

      if (onVolumeKeyPressed != null) {
        onVolumeKeyPressed!();
      }
    }

    _lastVolume = newVolume;
  }

  /// Dispose and cleanup
  void dispose() {
    if (_listenerId != null) {
      VolumeWatcher.removeListener(_listenerId);
      _listenerId = null;
    }
    print('VolumeKeyHandler: Disposed');
  }
}

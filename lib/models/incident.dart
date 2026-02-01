import 'package:uuid/uuid.dart';

/// Model representing an incident recording with transcript and AI response
class Incident {
  final String id;
  final DateTime timestamp;
  final String audioPath;
  final String transcript;
  final String? aiResponse;
  final String? location;
  final bool isDangerous;

  Incident({
    String? id,
    DateTime? timestamp,
    required this.audioPath,
    required this.transcript,
    this.aiResponse,
    this.location,
    this.isDangerous = false,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'audioPath': audioPath,
      'transcript': transcript,
      'aiResponse': aiResponse,
      'location': location,
      'isDangerous': isDangerous,
    };
  }

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      audioPath: json['audioPath'] as String,
      transcript: json['transcript'] as String,
      aiResponse: json['aiResponse'] as String?,
      location: json['location'] as String?,
      isDangerous: json['isDangerous'] as bool? ?? false,
    );
  }

  Incident copyWith({
    String? audioPath,
    String? transcript,
    String? aiResponse,
    String? location,
    bool? isDangerous,
  }) {
    return Incident(
      id: id,
      timestamp: timestamp,
      audioPath: audioPath ?? this.audioPath,
      transcript: transcript ?? this.transcript,
      aiResponse: aiResponse ?? this.aiResponse,
      location: location ?? this.location,
      isDangerous: isDangerous ?? this.isDangerous,
    );
  }

  /// Format timestamp for display
  String get formattedTimestamp {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) {
      // Today
      return 'Today at ${_formatTime(timestamp)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday at ${_formatTime(timestamp)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }
}

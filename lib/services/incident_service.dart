import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/incident.dart';

/// Service to persist and retrieve incident recordings
class IncidentService {
  static final IncidentService _instance = IncidentService._internal();

  factory IncidentService() {
    return _instance;
  }

  IncidentService._internal();

  static const String _incidentsFileName = 'incidents.json';

  /// Get the incidents storage directory
  Future<Directory> _getIncidentsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final incidentsDir = Directory('${appDir.path}/incidents');
    if (!await incidentsDir.exists()) {
      await incidentsDir.create(recursive: true);
    }
    return incidentsDir;
  }

  /// Get the incidents JSON file
  Future<File> _getIncidentsFile() async {
    final dir = await _getIncidentsDir();
    return File('${dir.path}/$_incidentsFileName');
  }

  /// Save an incident, copying audio to permanent storage
  Future<Incident> saveIncident(Incident incident) async {
    final incidentsDir = await _getIncidentsDir();

    // Copy audio file to permanent storage
    final audioFile = File(incident.audioPath);
    String permanentAudioPath = incident.audioPath;

    if (await audioFile.exists()) {
      final audioFileName = 'audio_${incident.id}.wav';
      final permanentAudioFile = File('${incidentsDir.path}/$audioFileName');
      await audioFile.copy(permanentAudioFile.path);
      permanentAudioPath = permanentAudioFile.path;
    }

    // Create incident with permanent audio path
    final savedIncident = Incident(
      id: incident.id,
      timestamp: incident.timestamp,
      audioPath: permanentAudioPath,
      transcript: incident.transcript,
      aiResponse: incident.aiResponse,
      location: incident.location,
      isDangerous: incident.isDangerous,
    );

    // Load existing incidents
    final incidents = await loadIncidents();

    // Add new incident at the beginning (newest first)
    incidents.insert(0, savedIncident);

    // Save to file
    await _saveIncidentsList(incidents);

    return savedIncident;
  }

  /// Load all incidents from storage
  Future<List<Incident>> loadIncidents() async {
    try {
      final file = await _getIncidentsFile();
      if (!await file.exists()) {
        return [];
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Incident.fromJson(json)).toList();
    } catch (e) {
      print('IncidentService: Failed to load incidents: $e');
      return [];
    }
  }

  /// Save the incidents list to file
  Future<void> _saveIncidentsList(List<Incident> incidents) async {
    final file = await _getIncidentsFile();
    final jsonList = incidents.map((i) => i.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  /// Delete an incident by ID
  Future<void> deleteIncident(String id) async {
    final incidents = await loadIncidents();
    final incident = incidents.firstWhere(
      (i) => i.id == id,
      orElse: () => throw Exception('Incident not found'),
    );

    // Delete audio file
    final audioFile = File(incident.audioPath);
    if (await audioFile.exists()) {
      await audioFile.delete();
    }

    // Remove from list and save
    incidents.removeWhere((i) => i.id == id);
    await _saveIncidentsList(incidents);
  }

  /// Get a single incident by ID
  Future<Incident?> getIncidentById(String id) async {
    final incidents = await loadIncidents();
    try {
      return incidents.firstWhere((i) => i.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Clear all incidents
  Future<void> clearAll() async {
    final incidentsDir = await _getIncidentsDir();
    if (await incidentsDir.exists()) {
      await incidentsDir.delete(recursive: true);
      await incidentsDir.create(recursive: true);
    }
  }
}

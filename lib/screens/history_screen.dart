import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/incident.dart';
import '../services/incident_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final IncidentService _incidentService = IncidentService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Incident> _incidents = [];
  bool _isLoading = true;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _playingId = null);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadIncidents() async {
    setState(() => _isLoading = true);
    final incidents = await _incidentService.loadIncidents();
    setState(() {
      _incidents = incidents;
      _isLoading = false;
    });
  }

  Future<void> _deleteIncident(Incident incident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Delete Recording?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete this incident recording.',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEB1555)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _incidentService.deleteIncident(incident.id);
      await _loadIncidents();
    }
  }

  Future<void> _togglePlayAudio(Incident incident) async {
    if (_playingId == incident.id) {
      await _audioPlayer.stop();
      setState(() => _playingId = null);
    } else {
      final file = File(incident.audioPath);
      if (await file.exists()) {
        await _audioPlayer.stop();
        await _audioPlayer.setPlaybackRate(1.2);
        await _audioPlayer.play(DeviceFileSource(incident.audioPath));
        setState(() => _playingId = incident.id);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio file not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showIncidentDetails(Incident incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _IncidentDetailsSheet(
        incident: incident,
        onPlayAudio: () => _togglePlayAudio(incident),
        isPlaying: _playingId == incident.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Incident History',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (_incidents.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Color(0xFF9CA3AF)),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1F2937),
                    title: const Text(
                      'Clear All History?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'This will permanently delete all incident recordings.',
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Clear All',
                          style: TextStyle(color: Color(0xFFEB1555)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _incidentService.clearAll();
                  await _loadIncidents();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEB1555)),
              ),
            )
          : _incidents.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _incidents.length,
              itemBuilder: (context, index) {
                final incident = _incidents[index];
                return _buildIncidentCard(incident);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 24),
          const Text(
            'No Incidents Recorded',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your incident recordings will appear here',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(Incident incident) {
    return Card(
      color: const Color(0xFF1F2937),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: incident.isDangerous
            ? const BorderSide(color: Color(0xFFEB1555), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showIncidentDetails(incident),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: incident.isDangerous
                          ? const Color(0xFFEB1555).withOpacity(0.2)
                          : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      incident.isDangerous ? Icons.warning : Icons.mic,
                      color: incident.isDangerous
                          ? const Color(0xFFEB1555)
                          : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incident.formattedTimestamp,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (incident.location != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  incident.location!,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _playingId == incident.id
                              ? Icons.stop
                              : Icons.play_arrow,
                          color: const Color(0xFFEB1555),
                        ),
                        onPressed: () => _togglePlayAudio(incident),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.grey[600],
                        ),
                        onPressed: () => _deleteIncident(incident),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                incident.transcript,
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (incident.isDangerous && incident.aiResponse != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFAB00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFAB00).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.gavel,
                        color: Color(0xFFFFAB00),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          incident.aiResponse!,
                          style: const TextStyle(
                            color: Color(0xFFFFAB00),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IncidentDetailsSheet extends StatelessWidget {
  final Incident incident;
  final VoidCallback onPlayAudio;
  final bool isPlaying;

  const _IncidentDetailsSheet({
    required this.incident,
    required this.onPlayAudio,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1F2937),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            incident.formattedTimestamp,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (incident.location != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    incident.location!,
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: onPlayAudio,
                      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(isPlaying ? 'Stop' : 'Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEB1555),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF374151)),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Transcript section
                    const Text(
                      'TRANSCRIPT',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      child: Text(
                        incident.transcript,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                    if (incident.aiResponse != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'LEGAL ADVICE',
                        style: TextStyle(
                          color: Color(0xFFFFAB00),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFAB00).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFAB00).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.gavel,
                                  color: Color(0xFFFFAB00),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'AI Legal Advice',
                                  style: TextStyle(
                                    color: Color(0xFFFFAB00),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              incident.aiResponse!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

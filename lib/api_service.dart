import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  
  factory ApiService() {
    return _instance;
  }
  
  ApiService._internal();

  static const String _baseUrlKey = 'api_base_url';
  static const String _defaultUrl = 'http://localhost:3000';
  
  String _baseUrl = _defaultUrl;
  
  /// Initialize by loading the base URL from preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? _defaultUrl;
  }
  
  /// Save a new base URL
  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }
  
  /// Get current base URL
  String get baseUrl => _baseUrl;

  /// Sends audio file to /elevenlabs/upload endpoint to get a transcription.
  Future<String> transcribeAudio(
    String audioPath, {
    String? streetAddress,
  }) async {
    final url = Uri.parse('$_baseUrl/elevenlabs/upload');

    var request = http.MultipartRequest('POST', url);
    
    // Add audio file with explicit content type
    request.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        audioPath,
        contentType: MediaType('audio', 'wav'),
      ),
    );

    if (streetAddress != null && streetAddress.isNotEmpty) {
      request.fields['streetAddress'] = streetAddress;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          decoded.containsKey('transcript')) {
        return decoded['transcript'] as String;
      } else {
        throw Exception(
          'Unexpected response format from /elevenlabs/upload: ${response.body}',
        );
      }
    } else {
      throw Exception(
        'Failed to transcribe audio: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Sends transcript to /gemini/judge endpoint to check if situation is dangerous.
  Future<Map<String, dynamic>> judgeTranscript(String transcript) async {
    final url = Uri.parse('$_baseUrl/gemini/judge');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'transcript': transcript}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Failed to judge transcript: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Sends transcript to /gemini/inform endpoint to get legal advice.
  Future<Map<String, dynamic>> getInformation(String transcript) async {
    final url = Uri.parse('$_baseUrl/gemini/inform');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'transcript': transcript}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Failed to get information: ${response.statusCode} ${response.body}',
      );
    }
  }
  
  /// Sends transcript to /gemini/communicate endpoint to generate a response.
  Future<String> communicate({
    required String transcript,
    required String location,
    required String name,
  }) async {
    final url = Uri.parse('$_baseUrl/gemini/communicate');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transcript': transcript,
        'location': location,
        'name': name,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded.containsKey('communicate')) {
        return decoded['communicate'] as String;
      } else {
        throw Exception('Response missing "communicate" field: ${response.body}');
      }
    } else {
      throw Exception(
        'Failed to get communication response: ${response.statusCode} ${response.body}',
      );
    }
  }
  
  /// Sends text to /elevenlabs/tts to get audio bytes.
  Future<Uint8List> textToSpeech(String text) async {
    final url = Uri.parse('$_baseUrl/elevenlabs/tts');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception(
        'Failed to generate TTS: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Orchestrates the full flow: Audio -> transcription -> judge -> (if dangerous) inform + communicate + TTS
  ///
  /// Returns a Result object or Map containing whatever the UI needs.
  /// For now returning a Map with keys: 'transcript', 'dangerous', 'advice', 'audioBytes'
  Future<Map<String, dynamic>> processAudioPipeline({
    required String audioPath,
    required String? location,
    required String userName,
  }) async {
    // 1. Transcribe audio
    final transcript = await transcribeAudio(audioPath, streetAddress: location);
    
    // 2. Judge if dangerous
    final judgeResponse = await judgeTranscript(transcript);
    final isDangerous = judgeResponse['dangerous'] == true;

    Map<String, dynamic> result = {
      'transcript': transcript,
      'dangerous': isDangerous,
    };

    if (isDangerous) {
      // 3. Parallel calls: Get Info and Generate Communication
      // We do them sequentially for simplicity or parallel to save time.
      // Let's do parallel.
      final infoFuture = getInformation(transcript);
      final commsFuture = communicate(
        transcript: transcript, 
        location: location ?? 'Unknown Location', 
        name: userName
      );
      
      final results = await Future.wait([infoFuture, commsFuture]);
      final infoResponse = results[0] as Map<String, dynamic>;
      final commsText = results[1] as String;
      
      result['advice'] = infoResponse['information'];
      result['communication'] = commsText;
      
      // 4. Transform communication text to speech
      final audioBytes = await textToSpeech(commsText);
      result['audioBytes'] = audioBytes;
    }

    return result;
  }
}

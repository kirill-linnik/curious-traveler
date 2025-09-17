import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  ApiService? _apiService;
  
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _currentLocationId;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _error;

  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get currentLocationId => _currentLocationId;
  Duration get duration => _duration;
  Duration get position => _position;
  String? get error => _error;
  double get progress => _duration.inMilliseconds > 0 
      ? _position.inMilliseconds / _duration.inMilliseconds 
      : 0.0;

  AudioProvider() {
    _initializeAudioPlayer();
  }

  void _initializeAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _position = Duration.zero;
      _currentLocationId = null;
      notifyListeners();
    });
  }

  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }

  Future<void> playNarration(String locationId, String narrationText, {String language = 'en-US'}) async {
    if (_apiService == null) {
      _error = 'API service not initialized';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Stop current playback if any
      await stopAudio();

      // Generate audio from text
      final audioData = await _apiService!.generateAudio(narrationText, language: language);
      
      // Create a temporary file-like source from bytes
      final source = BytesSource(audioData);
      await _audioPlayer.play(source);
      
      _currentLocationId = locationId;
      _error = null;
    } catch (e) {
      _error = 'Failed to play narration: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pauseAudio() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      _error = 'Failed to pause audio: $e';
      notifyListeners();
    }
  }

  Future<void> resumeAudio() async {
    try {
      await _audioPlayer.resume();
    } catch (e) {
      _error = 'Failed to resume audio: $e';
      notifyListeners();
    }
  }

  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      _position = Duration.zero;
      _currentLocationId = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to stop audio: $e';
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      _error = 'Failed to seek audio: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
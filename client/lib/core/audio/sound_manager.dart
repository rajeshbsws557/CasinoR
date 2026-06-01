import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;

  final AudioPlayer _betPlayer = AudioPlayer();
  final AudioPlayer _cashoutPlayer = AudioPlayer();
  final AudioPlayer _crashPlayer = AudioPlayer();

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  SoundManager._internal();

  Future<void> init() async {
    // Set to local assets (placeholders for now)
    await _betPlayer.setSourceAsset('sounds/bet.mp3').catchError((_) => null);
    await _cashoutPlayer.setSourceAsset('sounds/cashout.mp3').catchError((_) => null);
    await _crashPlayer.setSourceAsset('sounds/crash.mp3').catchError((_) => null);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  void playBet() {
    if (_isMuted || kIsWeb) return;
    _betPlayer.resume().catchError((_) => null);
  }

  void playCashout() {
    if (_isMuted || kIsWeb) return;
    _cashoutPlayer.resume().catchError((_) => null);
  }

  void playCrash() {
    if (_isMuted || kIsWeb) return;
    _crashPlayer.resume().catchError((_) => null);
  }
}

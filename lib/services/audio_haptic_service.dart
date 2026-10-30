import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioHapticService {
  AudioHapticService._();
  static final AudioHapticService instance = AudioHapticService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  static const _soundEnabledKey = 'wordrise_sound_effects';
  static const _hapticEnabledKey = 'wordrise_haptics';

  bool _isSoundEnabled = true;
  bool _isHapticEnabled = true;

  bool get isSoundEnabled => _isSoundEnabled;
  bool get isHapticEnabled => _isHapticEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isSoundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    _isHapticEnabled = prefs.getBool(_hapticEnabledKey) ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _isSoundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }

  Future<void> setHapticEnabled(bool enabled) async {
    _isHapticEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticEnabledKey, enabled);
  }

  Future<void> playSuccess() async {
    if (_isHapticEnabled) {
      await HapticFeedback.mediumImpact();
    }
    if (_isSoundEnabled) {
      try {
        // Plays from assets/audio/success.wav
        await _audioPlayer.play(AssetSource('audio/success.wav'));
      } catch (e) {
        // Ignore if file doesn't exist yet
      }
    }
  }

  Future<void> playFail() async {
    if (_isHapticEnabled) {
      await HapticFeedback.heavyImpact();
    }
    if (_isSoundEnabled) {
      try {
        // Plays from assets/audio/fail.wav
        await _audioPlayer.play(AssetSource('audio/fail.wav'));
      } catch (e) {
        // Ignore if file doesn't exist yet
      }
    }
  }

  Future<void> lightImpact() async {
    if (_isHapticEnabled) await HapticFeedback.lightImpact();
  }

  Future<void> mediumImpact() async {
    if (_isHapticEnabled) await HapticFeedback.mediumImpact();
  }

  Future<void> heavyImpact() async {
    if (_isHapticEnabled) await HapticFeedback.heavyImpact();
  }

  Future<void> selectionClick() async {
    if (_isHapticEnabled) await HapticFeedback.selectionClick();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';

enum FocusGoalType { time, words }

class FocusProvider extends ChangeNotifier {
  bool _isActive = false;
  
  FocusGoalType _goalType = FocusGoalType.time;
  
  // For time-based goals
  int _targetMinutes = 30;
  int _secondsRemaining = 0;
  Timer? _timer;

  // For word-based goals
  int _targetWords = 50;
  int _wordsLearned = 0;

  bool get isActive => _isActive;
  FocusGoalType get goalType => _goalType;
  int get targetMinutes => _targetMinutes;
  int get secondsRemaining => _secondsRemaining;
  int get targetWords => _targetWords;
  int get wordsLearned => _wordsLearned;

  bool get isGoalReached {
    if (!_isActive) return false;
    if (_goalType == FocusGoalType.time) {
      return _secondsRemaining <= 0;
    } else {
      return _wordsLearned >= _targetWords;
    }
  }

  void setGoalType(FocusGoalType type) {
    if (_isActive) return;
    _goalType = type;
    notifyListeners();
  }

  void setTargetMinutes(int minutes) {
    if (_isActive) return;
    _targetMinutes = minutes;
    notifyListeners();
  }

  void setTargetWords(int count) {
    if (_isActive) return;
    _targetWords = count;
    notifyListeners();
  }

  void startFocus() {
    if (_isActive) return;
    _isActive = true;
    _wordsLearned = 0;
    
    if (_goalType == FocusGoalType.time) {
      _secondsRemaining = _targetMinutes * 60;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
          notifyListeners();
        } else {
          _timer?.cancel();
          notifyListeners();
        }
      });
    }
    
    notifyListeners();
  }

  void incrementWordsLearned(int count) {
    if (!_isActive || _goalType != FocusGoalType.words) return;
    _wordsLearned += count;
    notifyListeners();
  }

  void stopFocus() {
    _isActive = false;
    _timer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

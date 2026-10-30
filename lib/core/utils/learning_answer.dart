String normalizeLearningAnswer(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp("[‘’`´]"), "'")
      .replaceAll(RegExp(r'[.!?]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool learningAnswersMatch(String left, String right) {
  return normalizeLearningAnswer(left) == normalizeLearningAnswer(right);
}

bool canRevealQuizAudio({required String direction, required bool answered}) {
  return direction != 'uz_to_eng' || answered;
}

String buildTypingHint(String answer, {int revealLetters = 1}) {
  var remaining = revealLetters.clamp(1, answer.length);
  var startsWord = true;
  final output = StringBuffer();
  for (final rune in answer.runes) {
    final character = String.fromCharCode(rune);
    final isLetterOrDigit = RegExp(r'[A-Za-z0-9]').hasMatch(character);
    if (!isLetterOrDigit) {
      output.write(character);
      startsWord = character.trim().isEmpty || character == '-';
      continue;
    }
    if (startsWord || remaining > 0) {
      output.write(character);
      if (!startsWord) remaining--;
    } else {
      output.write('•');
    }
    startsWord = false;
  }
  return output.toString();
}

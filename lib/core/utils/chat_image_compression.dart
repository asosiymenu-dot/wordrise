class ChatImageCompressionPreset {
  const ChatImageCompressionPreset({
    required this.maxSide,
    required this.quality,
  });

  final int maxSide;
  final int quality;
}

const chatImageMaxBytes = 1536 * 1024;

const chatImageCompressionPresets = [
  ChatImageCompressionPreset(maxSide: 1280, quality: 87),
  ChatImageCompressionPreset(maxSide: 1280, quality: 84),
  ChatImageCompressionPreset(maxSide: 1120, quality: 84),
  ChatImageCompressionPreset(maxSide: 960, quality: 82),
  ChatImageCompressionPreset(maxSide: 800, quality: 80),
];

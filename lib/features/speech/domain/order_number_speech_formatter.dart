class OrderNumberSpeechFormatter {
  const OrderNumberSpeechFormatter();

  static const Map<String, String> _digits = {
    '0': 'không',
    '1': 'một',
    '2': 'hai',
    '3': 'ba',
    '4': 'bốn',
    '5': 'năm',
    '6': 'sáu',
    '7': 'bảy',
    '8': 'tám',
    '9': 'chín',
  };

  static const Map<String, String> _letters = {
    'A': 'a',
    'B': 'bê',
    'C': 'xê',
    'D': 'đê',
    'E': 'e',
    'F': 'ép',
    'G': 'giê',
    'H': 'hát',
    'I': 'i',
    'J': 'giây',
    'K': 'ca',
    'L': 'e-lờ',
    'M': 'em-mờ',
    'N': 'en-nờ',
    'O': 'ô',
    'P': 'pê',
    'Q': 'quy',
    'R': 'e-rờ',
    'S': 'ét',
    'T': 'tê',
    'U': 'u',
    'V': 'vê',
    'W': 'vê kép',
    'X': 'ích',
    'Y': 'i dài',
    'Z': 'dét',
  };

  String format(String orderNumber) {
    final normalized = orderNumber.trim().toUpperCase();
    if (normalized.isEmpty) {
      return '';
    }

    final trailingDigits = RegExp(r'(\d+)$').firstMatch(normalized)?.group(1);
    if (trailingDigits != null && trailingDigits.isNotEmpty) {
      return _speakCharacters(trailingDigits);
    }

    return _speakCharacters(normalized);
  }

  String _speakCharacters(String value) {
    final words = <String>[];
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final spoken = _digits[character] ?? _letters[character];
      if (spoken != null) {
        words.add(spoken);
      }
    }
    return words.join(', ');
  }
}

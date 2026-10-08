import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result of running OCR over an image.
class ScanResult {
  const ScanResult({
    required this.fullText,
    required this.numbers,
    this.error,
  });

  /// The complete recognized text, line by line.
  final String fullText;

  /// All numeric tokens found in the image, in order of appearance.
  final List<String> numbers;

  /// Non-null when reading failed.
  final String? error;

  bool get hasNumbers => numbers.isNotEmpty;
  bool get isEmpty => fullText.trim().isEmpty;
}

/// Wraps on-device ML Kit text recognition and extracts numbers.
///
/// ML Kit only ships native implementations for Android, iOS and macOS. On
/// other platforms [isSupported] is false and callers should offer manual
/// entry instead.
class OcrService {
  OcrService();

  TextRecognizer? _recognizer;

  /// Whether on-device OCR is available on the current platform.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  TextRecognizer _recognizerFor() {
    return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Recognizes text in the image at [path] and extracts numbers.
  Future<ScanResult> scanFile(String path) async {
    if (!isSupported) {
      return const ScanResult(
        fullText: '',
        numbers: [],
        error: 'Text recognition is not supported on this platform.',
      );
    }
    try {
      final input = InputImage.fromFilePath(path);
      final recognized = await _recognizerFor().processImage(input);
      return ScanResult(
        fullText: recognized.text,
        numbers: extractNumbers(recognized.text),
      );
    } catch (e) {
      return ScanResult(fullText: '', numbers: [], error: 'Failed to read: $e');
    }
  }

  /// Extracts numeric tokens (including decimals, signs and separators).
  static List<String> extractNumbers(String text) {
    // Matches optional sign, digits with optional grouping/decimals, or a
    // leading decimal such as ".5".
    final regex = RegExp(r'-?\d{1,3}(?:[,\s]\d{3})+(?:\.\d+)?|-?\d*\.?\d+');
    final matches = regex.allMatches(text);
    final results = <String>[];
    for (final m in matches) {
      var token = m.group(0)!.trim();
      // Normalize thousands separators to a plain number.
      token = token.replaceAll(RegExp(r'[,\s](?=\d{3}\b)'), '');
      if (token.isEmpty || token == '-' || token == '.') continue;
      results.add(token);
    }
    return results;
  }

  /// Releases native resources.
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}

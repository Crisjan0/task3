import 'dart:convert';

/// The kind of activity a record represents.
enum RecordType {
  /// A calculation performed on the calculator page.
  calculation,

  /// Numbers captured from a photo on the scan page.
  scan,
}

/// A single persisted activity: either a calculation or a photo scan.
class AppRecord {
  AppRecord({
    required this.id,
    required this.type,
    required this.input,
    required this.output,
    required this.timestamp,
    this.detail,
  });

  /// Unique identifier (used for de-duplication and dismissal).
  final String id;

  /// Kind of record.
  final RecordType type;

  /// For calculations: the entered expression.
  /// For scans: the full recognized text.
  final String input;

  /// For calculations: the formatted result.
  /// For scans: a comma separated list of captured numbers.
  final String output;

  /// When the record was created.
  final DateTime timestamp;

  /// Optional extra information (e.g. source image path).
  final String? detail;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'input': input,
    'output': output,
    'timestamp': timestamp.toIso8601String(),
    'detail': detail,
  };

  factory AppRecord.fromJson(Map<String, dynamic> json) {
    return AppRecord(
      id: json['id'] as String,
      type: RecordType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => RecordType.calculation,
      ),
      input: json['input'] as String? ?? '',
      output: json['output'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      detail: json['detail'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static AppRecord decode(String source) =>
      AppRecord.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_record.dart';

/// Persists history of calculations and scans on the device.
///
/// Records are stored as a JSON list of encoded [AppRecord]s under a single
/// key. The repository is a [ChangeNotifier] so any page can rebuild when the
/// history changes.
class RecordRepository extends ChangeNotifier {
  RecordRepository({SharedPreferences? prefs}) {
    if (prefs != null) {
      _prefs = prefs;
      _load();
    }
  }

  static const String _storageKey = 'task3.records.v1';
  static const int _maxRecords = 500;

  SharedPreferences? _prefs;
  final List<AppRecord> _records = [];

  /// All records, newest first.
  List<AppRecord> get records => List.unmodifiable(_records);

  bool get isEmpty => _records.isEmpty;

  /// Loads persisted records. Safe to call multiple times.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    final raw = _prefs?.getStringList(_storageKey) ?? const <String>[];
    _records
      ..clear()
      ..addAll(
        raw.map((e) {
          try {
            return AppRecord.decode(e);
          } catch (_) {
            return null;
          }
        }).whereType<AppRecord>(),
      );
    _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
  }

  Future<void> add(AppRecord record) async {
    _records.insert(0, record);
    if (_records.length > _maxRecords) {
      _records.removeRange(_maxRecords, _records.length);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _records.removeWhere((r) => r.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _records.clear();
    notifyListeners();
    await _persist();
  }

  /// Removes all records of a given type.
  Future<void> clearType(RecordType type) async {
    _records.removeWhere((r) => r.type == type);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _records.map((r) => r.encode()).toList(growable: false),
    );
  }
}

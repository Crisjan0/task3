import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_record.dart';
import '../services/ocr_service.dart';
import '../services/record_repository.dart';

/// Page 2: capture a photo and extract the numbers it contains.
class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.repository,
    this.onUseInCalculator,
  });

  final RecordRepository repository;

  /// Called with the captured numbers when the user taps "Use in calculator".
  final ValueChanged<List<String>>? onUseInCalculator;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocr = OcrService();

  XFile? _image;
  ScanResult? _result;
  bool _busy = false;
  String? _statusMessage;

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (!OcrService.isSupported) {
      setState(() {
        _statusMessage =
            'Text recognition is only available on Android, iOS and macOS. '
            'You can still enter numbers manually below.';
      });
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 2400,
      );
      if (file == null) return;
      setState(() {
        _image = file;
        _result = null;
        _busy = true;
        _statusMessage = null;
      });
      final result = await _ocr.scanFile(file.path);
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
        if (result.error != null) {
          _statusMessage = result.error;
        } else if (result.isEmpty) {
          _statusMessage = 'No text was found in the image.';
        } else if (!result.hasNumbers) {
          _statusMessage = 'Text found, but no numbers were detected.';
        }
      });
      if (result.hasNumbers) {
        _saveRecord(result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusMessage = 'Could not pick image: $e';
      });
    }
  }

  Future<void> _saveRecord(ScanResult result) async {
    await widget.repository.add(
      AppRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: RecordType.scan,
        input: result.fullText.trim(),
        output: result.numbers.join(', '),
        timestamp: DateTime.now(),
        detail: _image?.path,
      ),
    );
  }

  void _copyToCalculator() {
    final numbers = _result?.numbers ?? const <String>[];
    if (numbers.isEmpty) return;
    if (widget.onUseInCalculator != null) {
      widget.onUseInCalculator!(numbers);
    } else {
      Navigator.of(context).pop('CAPTURE:${numbers.join(',')}');
    }
  }

  void _openManualEntry() async {
    final controller = TextEditingController(
      text: _result?.numbers.join(', ') ?? '',
    );
    final numbers = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter numbers'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            hintText: 'e.g. 12, 45.5, -8',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = OcrService.extractNumbers(controller.text);
              Navigator.pop(context, parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (numbers == null || numbers.isEmpty) return;
    final result = ScanResult(
      fullText: numbers.join(' '),
      numbers: numbers,
    );
    setState(() {
      _result = result;
      _statusMessage = null;
    });
    await _saveRecord(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan numbers')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSourceButtons(),
          const SizedBox(height: 16),
          _buildImagePreview(),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            _buildMessage(_statusMessage!),
          ],
          if (_result != null && _result!.hasNumbers) ...[
            const SizedBox(height: 16),
            _buildNumbersCard(_result!),
          ],
          if (_result != null && !_result!.isEmpty) ...[
            const SizedBox(height: 16),
            _buildTextCard(_result!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSourceButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _openManualEntry,
            icon: const Icon(Icons.keyboard),
            label: const Text('Enter numbers manually'),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    final image = _image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 240,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: image == null
            ? _buildEmptyPreview()
            : Image.file(
                File(image.path),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _buildEmptyPreview(),
              ),
      ),
    );
  }

  Widget _buildEmptyPreview() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 56,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo of numbers to capture them',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumbersCard(ScanResult result) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.numbers, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Captured numbers (${result.numbers.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in result.numbers)
                  Chip(
                    label: Text(n),
                    backgroundColor: scheme.primaryContainer,
                    labelStyle: TextStyle(color: scheme.onPrimaryContainer),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _copyToCalculator,
                  icon: const Icon(Icons.calculate),
                  label: const Text('Use in calculator'),
                ),
                OutlinedButton.icon(
                  onPressed: _openManualEntry,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextCard(ScanResult result) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.text_fields, color: scheme.primary),
        title: const Text('Recognized text'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(result.fullText.trim()),
          ),
        ],
      ),
    );
  }
}

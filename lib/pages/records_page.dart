import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_record.dart';
import '../services/record_repository.dart';

/// Page 3: a searchable, filterable history of all calculations and scans.
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, required this.repository});

  final RecordRepository repository;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  RecordType? _filter; // null == all
  String _query = '';

  List<AppRecord> get _visibleRecords {
    final q = _query.trim().toLowerCase();
    return widget.repository.records.where((r) {
      if (_filter != null && r.type != _filter) return false;
      if (q.isEmpty) return true;
      return r.input.toLowerCase().contains(q) ||
          r.output.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final records = _visibleRecords;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Records'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'calc') {
                    await widget.repository.clearType(RecordType.calculation);
                  } else if (value == 'scan') {
                    await widget.repository.clearType(RecordType.scan);
                  } else if (value == 'all') {
                    final confirmed = await _confirmClear();
                    if (confirmed) await widget.repository.clear();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'calc', child: Text('Clear calculations')),
                  PopupMenuItem(value: 'scan', child: Text('Clear scans')),
                  PopupMenuItem(value: 'all', child: Text('Clear everything')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search records',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              _buildFilterChips(),
              const Divider(height: 1),
              Expanded(
                child: records.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        itemCount: records.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _buildTile(records[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _filter == null,
            onSelected: (_) => setState(() => _filter = null),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Calculations'),
            selected: _filter == RecordType.calculation,
            onSelected: (_) => setState(() => _filter = RecordType.calculation),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Scans'),
            selected: _filter == RecordType.scan,
            onSelected: (_) => setState(() => _filter = RecordType.scan),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(AppRecord record) {
    final theme = Theme.of(context);
    final isCalc = record.type == RecordType.calculation;
    final dateFormat = DateFormat('MMM d, y • h:mm a');
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) => widget.repository.remove(record.id),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCalc
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.tertiaryContainer,
          child: Icon(
            isCalc ? Icons.calculate_outlined : Icons.document_scanner_outlined,
            color: isCalc
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onTertiaryContainer,
          ),
        ),
        title: Text(
          isCalc ? record.input : 'Captured: ${record.output}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCalc)
              Text(
                '= ${record.output}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (!isCalc && record.input.isNotEmpty)
              Text(
                record.input,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              dateFormat.format(record.timestamp),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showDetails(record),
      ),
    );
  }

  Widget _buildEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No records yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Calculations and scans will appear here.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(AppRecord record) async {
    final dateFormat = DateFormat('MMMM d, y • h:mm:ss a');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.type == RecordType.calculation
                  ? 'Calculation'
                  : 'Scan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _detailRow('Input', record.input.isEmpty ? '—' : record.input),
            _detailRow(
              record.type == RecordType.calculation ? 'Result' : 'Numbers',
              record.output.isEmpty ? '—' : record.output,
            ),
            _detailRow('Date', dateFormat.format(record.timestamp)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.repository.remove(record.id);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Future<bool> _confirmClear() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all records?'),
        content: const Text('This permanently removes all history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

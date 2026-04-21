import 'package:flutter/material.dart';

import '../models/study_snapshot.dart';
import '../services/history_storage.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.snapshot,
  });

  final StudySnapshot snapshot;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await HistoryStorage.loadAll();
    if (!mounted) return;
    setState(() {
      _records = list;
      _loading = false;
    });
  }

  Future<void> _saveCurrent() async {
    await HistoryStorage.saveSnapshot(widget.snapshot);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved current status')),
    );
    await _load();
  }

  Future<void> _deleteRecord(int index) async {
    await HistoryStorage.deleteAt(index);
    if (!mounted) return;
    setState(() {
      _records.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record deleted')),
    );
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  String _formatTime(DateTime t) {
    return '${t.year}-${_pad2(t.month)}-${_pad2(t.day)} ${_pad2(t.hour)}:${_pad2(t.minute)}';
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'bright':
        return Icons.wb_sunny_rounded;
      case 'moderate':
        return Icons.wb_twilight_rounded;
      case 'dim':
        return Icons.dark_mode_rounded;
      default:
        return Icons.light_mode_outlined;
    }
  }

  Color _statusColor(ColorScheme cs, String status) {
    switch (status.toLowerCase()) {
      case 'bright':
        return Colors.green.shade700;
      case 'moderate':
        return Colors.orange.shade700;
      case 'dim':
        return cs.error;
      default:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _saveCurrent,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  '📝 Record current status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? Center(
                        child: Text(
                          'No records yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: _records.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final r = _records[index];
                          return Material(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.65,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: cs.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    cs,
                                    r.lightStatus,
                                  ).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _statusIcon(r.lightStatus),
                                  color: _statusColor(cs, r.lightStatus),
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: 'Delete',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: cs.error,
                                ),
                                onPressed: () => _deleteRecord(index),
                              ),
                              title: Text(
                                _formatTime(r.time),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.wb_sunny_outlined,
                                          size: 16,
                                          color: cs.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Light: ${r.lux} lx (${r.lightStatus})',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.cloud_outlined,
                                          size: 16,
                                          color: cs.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Weather: ${r.weather}',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline_rounded,
                                          size: 16,
                                          color: cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Advice: ${r.suggestion}',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

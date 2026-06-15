import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangePickerWidget extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final void Function(DateTime start, DateTime end) onChanged;

  const DateRangePickerWidget({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onChanged,
  });

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
    );
    if (picked != null) {
      onChanged(picked.start, picked.end);
    }
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    switch (preset) {
      case 'this_month':
        onChanged(DateTime(now.year, now.month, 1), now);
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        onChanged(
          lastMonth,
          DateTime(now.year, now.month, 0),
        );
      case 'this_year':
        onChanged(DateTime(now.year, 1, 1), now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat.yMMMd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _pickRange(context),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date range',
              prefixIcon: Icon(Icons.date_range),
              contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 14),
            ),
            child: Text(
              '${format.format(startDate)} – ${format.format(endDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _presetChip(context, 'This month', 'this_month'),
            _presetChip(context, 'Last month', 'last_month'),
            _presetChip(context, 'This year', 'this_year'),
          ],
        ),
      ],
    );
  }

  Widget _presetChip(BuildContext context, String label, String preset) {
    return ActionChip(
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () => _setPreset(preset),
    );
  }
}

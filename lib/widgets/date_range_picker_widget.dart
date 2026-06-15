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
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date range',
              prefixIcon: Icon(Icons.date_range),
            ),
            child: Text('${format.format(startDate)} – ${format.format(endDate)}'),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('This month'),
              onPressed: () => _setPreset('this_month'),
            ),
            ActionChip(
              label: const Text('Last month'),
              onPressed: () => _setPreset('last_month'),
            ),
            ActionChip(
              label: const Text('This year'),
              onPressed: () => _setPreset('this_year'),
            ),
          ],
        ),
      ],
    );
  }
}

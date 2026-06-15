import 'dart:io';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/constants.dart';
import '../models/expense.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/date_range_picker_widget.dart';
import '../widgets/expense_list_tile.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _category = 'All';
  String? _registeredByFilter;
  List<Expense> _expenses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  Future<void> _loadReport() async {
    final auth = context.read<AuthProvider>();
    if (auth.accountId == null) return;

    setState(() => _isLoading = true);

    final expenses = await context.read<ExpenseProvider>().fetchExpensesForReport(
          accountId: auth.accountId!,
          isOwner: auth.isOwner,
          userId: auth.user?.uid,
          startDate: _startDate,
          endDate: _endDate,
          category: _category == 'All' ? null : _category,
        );

    var filtered = expenses;
    if (auth.isOwner && _registeredByFilter != null) {
      filtered = expenses
          .where((e) => e.registeredBy == _registeredByFilter)
          .toList();
    }

    if (mounted) {
      setState(() {
        _expenses = filtered;
        _isLoading = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    if (_expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export')),
      );
      return;
    }

    final dateFormat = DateFormat('yyyy-MM-dd');
    final rows = <List<String>>[
      [
        'Date',
        'Amount',
        'Currency',
        'Merchant',
        'Category',
        'Registered By',
        'Notes',
      ],
      ..._expenses.map((e) => [
            dateFormat.format(e.expenseDate),
            e.amount.toStringAsFixed(2),
            e.currency,
            e.merchant,
            e.category,
            e.registeredByName,
            e.description,
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final fileName =
        'molly_expenses_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Molly Expenses Report',
        text: 'Expense report export',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'nb_NO', symbol: 'kr');
    final expenseProvider = context.read<ExpenseProvider>();
    final total = expenseProvider.calculateTotal(_expenses);
    final categoryTotals = expenseProvider.totalsByCategory(_expenses);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DateRangePickerWidget(
                    startDate: _startDate,
                    endDate: _endDate,
                    onChanged: (start, end) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                      });
                      _loadReport();
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: ['All', ...AppConstants.expenseCategories]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _category = value);
                      _loadReport();
                    },
                  ),
                  if (auth.isOwner) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: _registeredByFilter,
                      decoration: const InputDecoration(
                        labelText: 'Registered by',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All users'),
                        ),
                        ...auth.members.map(
                          (m) => DropdownMenuItem(
                            value: m.userId,
                            child: Text(m.displayName),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _registeredByFilter = value);
                        _loadReport();
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(total),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                          ),
                          Text(
                            '${_expenses.length} expenses',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white54,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (categoryTotals.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'By category',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: _CategoryPieChart(totals: categoryTotals),
                    ),
                    const SizedBox(height: 16),
                    ...categoryTotals.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(e.key)),
                            Text(currencyFormat.format(e.value)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Expenses',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No expenses in this period')),
                    )
                  else
                    ..._expenses.map(
                      (e) => ExpenseListTile(expense: e, showRegisteredBy: auth.isOwner),
                    ),
                ],
              ),
            ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final Map<String, double> totals;

  const _CategoryPieChart({required this.totals});

  static const _colors = [
    Color(0xFF00897B),
    Color(0xFF6A1B9A),
    Color(0xFF26A69A),
    Color(0xFF5C6BC0),
    Color(0xFFEF5350),
    Color(0xFFFFA726),
    Color(0xFF78909C),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList();
    final total = totals.values.fold(0.0, (a, b) => a + b);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: List.generate(entries.length, (i) {
          final entry = entries[i];
          final percent = total > 0 ? (entry.value / total * 100) : 0.0;
          return PieChartSectionData(
            value: entry.value,
            title: '${percent.toStringAsFixed(0)}%',
            color: _colors[i % _colors.length],
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }
}

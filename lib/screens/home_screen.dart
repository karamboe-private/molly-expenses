import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../screens/add_expense_screen.dart';
import '../widgets/expense_list_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initExpenses());
  }

  void _initExpenses() {
    _refreshDashboard();
  }

  void _refreshDashboard() {
    final auth = context.read<AuthProvider>();
    final expenseProvider = context.read<ExpenseProvider>();
    final accountId = auth.accountId;
    if (accountId == null) return;

    expenseProvider.refreshDashboard(
      accountId: accountId,
      isOwner: auth.isOwner,
      userId: auth.user?.uid,
    );
  }

  Future<void> _openManualEntry(AuthProvider auth) async {
    if (auth.accountId == null || auth.user == null) return;

    await Navigator.of(context).pushNamed(
      AppRoutes.addExpense,
      arguments: AddExpenseScreenArgs(
        accountId: auth.accountId!,
        registeredBy: auth.user!.uid,
        registeredByName: auth.userProfile?.displayName ?? '',
      ),
    );

    if (mounted) _refreshDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'nb_NO', symbol: 'kr');

    return Scaffold(
      appBar: AppBar(
        title: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final name = auth.account?.beneficiaryName ?? 'Molly';
            return Text('$name\'s Expenses');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Reports',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.reports);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.profile);
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, ExpenseProvider>(
        builder: (context, auth, expenses, _) {
          if (auth.accountId == null) {
            return const Center(child: Text('No account linked'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _DashboardAmount(
                        label: 'Today',
                        amount: currencyFormat.format(expenses.todayTotal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardAmount(
                        label: 'This week',
                        amount: currencyFormat.format(expenses.weekTotal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashboardAmount(
                        label: 'This month',
                        amount: currencyFormat.format(expenses.monthTotal),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${expenses.monthExpenses.length} expense${expenses.monthExpenses.length == 1 ? '' : 's'} this month',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Recent expenses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (auth.isOwner)
                      Text(
                        'All users',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: expenses.monthExpenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 64,
                              color: Colors.white24,
                            ),
                            const SizedBox(height: 16),
                            const Text('No expenses yet'),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add an expense or scan a receipt',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white54,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: expenses.monthExpenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses.monthExpenses[index];
                          return ExpenseListTile(
                            expense: expense,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.expenseDetail,
                                arguments: expense,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer2<AuthProvider, ExpenseProvider>(
        builder: (context, auth, expenseProvider, _) {
          return _AddExpenseFab(
            isAnalyzing: expenseProvider.isAnalyzing,
            onManual: () => _openManualEntry(auth),
            onScan: () => _scanReceipt(context, auth, expenseProvider),
          );
        },
      ),
    );
  }

  Future<void> _scanReceipt(
    BuildContext context,
    AuthProvider auth,
    ExpenseProvider expenseProvider,
  ) async {
    if (auth.accountId == null) return;

    final result = await expenseProvider.scanReceipt(
      accountId: auth.accountId!,
    );
    if (!context.mounted) return;

    if (result != null) {
      await Navigator.of(context).pushNamed(
        AppRoutes.addExpense,
        arguments: AddExpenseScreenArgs.fromScan(
          scanResult: result,
          accountId: auth.accountId!,
          registeredBy: auth.user!.uid,
          registeredByName: auth.userProfile?.displayName ?? '',
        ),
      );

      if (context.mounted) {
        _refreshDashboard();

        if (result.analysis == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Receipt uploaded, but could not auto-read it. Please fill in the details.',
              ),
            ),
          );
        }
      }
    } else if (expenseProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(expenseProvider.errorMessage!)),
      );
    }
  }
}

class _DashboardAmount extends StatelessWidget {
  final String label;
  final String amount;

  const _DashboardAmount({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.secondary,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(amount, style: amountStyle),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AddExpenseAction { scan, manual }

class _AddExpenseFab extends StatelessWidget {
  final bool isAnalyzing;
  final VoidCallback onManual;
  final Future<void> Function() onScan;

  const _AddExpenseFab({
    required this.isAnalyzing,
    required this.onManual,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    if (isAnalyzing) {
      return FloatingActionButton(
        heroTag: 'add',
        tooltip: 'Analyzing receipt',
        onPressed: null,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return PopupMenuButton<_AddExpenseAction>(
      tooltip: 'Add expense',
      position: PopupMenuPosition.over,
      offset: const Offset(0, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surface,
      onSelected: (action) async {
        switch (action) {
          case _AddExpenseAction.scan:
            await onScan();
          case _AddExpenseAction.manual:
            onManual();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _AddExpenseAction.scan,
          child: Row(
            children: [
              Icon(
                Icons.document_scanner,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              const Text('Scan receipt'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _AddExpenseAction.manual,
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              const Text('Enter manually'),
            ],
          ),
        ),
      ],
      child: AbsorbPointer(
        child: FloatingActionButton(
          heroTag: 'add',
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

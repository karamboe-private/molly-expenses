import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/routes.dart';
import '../models/expense.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../screens/add_expense_screen.dart';
import '../widgets/receipt_preview.dart';

class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final provider = context.read<ExpenseProvider>();
    final success =
        await provider.deleteExpense(expense.accountId, expense.id);

    if (context.mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to delete'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'nb_NO', symbol: 'kr');
    final dateFormat = DateFormat.yMMMd().add_jm();
    final auth = context.watch<AuthProvider>();
    final canEdit = auth.isOwner || expense.registeredBy == auth.user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.addExpense,
                  arguments: AddExpenseScreenArgs(
                    accountId: expense.accountId,
                    registeredBy: expense.registeredBy,
                    registeredByName: expense.registeredByName,
                    expense: expense,
                  ),
                );
              },
            ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currencyFormat.format(expense.amount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (expense.merchant.isNotEmpty)
                    Text(
                      expense.merchant,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(expense.expenseDate),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Category', value: expense.category),
          _DetailRow(label: 'Currency', value: expense.currency),
          if (expense.registeredByName.isNotEmpty)
            _DetailRow(label: 'Registered by', value: expense.registeredByName),
          if (expense.description.isNotEmpty)
            _DetailRow(label: 'Notes', value: expense.description),
          if (expense.receiptUrl != null) ...[
            const SizedBox(height: 16),
            ReceiptPreview(imageUrl: expense.receiptUrl),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

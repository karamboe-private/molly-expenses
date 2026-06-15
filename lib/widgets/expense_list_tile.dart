import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';

class ExpenseListTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final bool showRegisteredBy;

  const ExpenseListTile({
    super.key,
    required this.expense,
    this.onTap,
    this.showRegisteredBy = false,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'nb_NO', symbol: 'kr');
    final dateFormat = DateFormat.MMMd();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
          child: Icon(
            Icons.receipt,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
        ),
        title: Text(
          expense.merchant.isNotEmpty ? expense.merchant : expense.category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${dateFormat.format(expense.expenseDate)} · ${expense.category}'),
            if (showRegisteredBy && expense.registeredByName.isNotEmpty)
              Text(
                'By ${expense.registeredByName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
          ],
        ),
        trailing: Text(
          currencyFormat.format(expense.amount),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

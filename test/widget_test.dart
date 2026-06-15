import 'package:flutter_test/flutter_test.dart';
import 'package:molly_expenses/config/constants.dart';
import 'package:molly_expenses/models/expense.dart';

void main() {
  test('Expense fromMap parses amount correctly', () {
    final expense = Expense.fromMap('test-id', {
      'accountId': 'acc1',
      'registeredBy': 'user1',
      'amount': 199.5,
      'currency': 'NOK',
      'merchant': 'Rema 1000',
      'category': 'Groceries',
      'status': 'confirmed',
    });

    expect(expense.amount, 199.5);
    expect(expense.currency, 'NOK');
    expect(expense.category, 'Groceries');
  });

  test('expense categories include Other', () {
    expect(AppConstants.expenseCategories, contains('Other'));
  });
}

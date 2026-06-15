import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/expense.dart';
import '../models/account.dart';
import 'logger_service.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  CollectionReference<Map<String, dynamic>> _expensesRef(String accountId) {
    return _firestore
        .collection(AppConstants.accountsCollection)
        .doc(accountId)
        .collection(AppConstants.expensesSubcollection);
  }

  Stream<List<Expense>> streamExpenses({
    required String accountId,
    String? registeredBy,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    Query<Map<String, dynamic>> query =
        _expensesRef(accountId).orderBy('expenseDate', descending: true);

    if (registeredBy != null) {
      query = query.where('registeredBy', isEqualTo: registeredBy);
    }

    return query.snapshots().map((snap) {
      var expenses = snap.docs
          .map((d) => Expense.fromMap(d.id, d.data()))
          .toList();

      if (startDate != null) {
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        expenses = expenses
            .where((e) => !_dateOnly(e.expenseDate).isBefore(start))
            .toList();
      }
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day);
        expenses = expenses
            .where((e) => !_dateOnly(e.expenseDate).isAfter(end))
            .toList();
      }
      if (category != null && category.isNotEmpty && category != 'All') {
        expenses = expenses.where((e) => e.category == category).toList();
      }

      return expenses;
    });
  }

  Future<List<Expense>> getExpenses({
    required String accountId,
    String? registeredBy,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    Query<Map<String, dynamic>> query =
        _expensesRef(accountId).orderBy('expenseDate', descending: true);

    if (registeredBy != null) {
      query = query.where('registeredBy', isEqualTo: registeredBy);
    }

    final snap = await query.get();
    var expenses =
        snap.docs.map((d) => Expense.fromMap(d.id, d.data())).toList();

    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      expenses = expenses
          .where((e) => !_dateOnly(e.expenseDate).isBefore(start))
          .toList();
    }
    if (endDate != null) {
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      expenses = expenses
          .where((e) => !_dateOnly(e.expenseDate).isAfter(end))
          .toList();
    }
    if (category != null && category.isNotEmpty && category != 'All') {
      expenses = expenses.where((e) => e.category == category).toList();
    }

    return expenses;
  }

  Future<String> addExpense(Expense expense) async {
    try {
      final id = expense.id.isEmpty ? _uuid.v4() : expense.id;
      await _expensesRef(expense.accountId).doc(id).set(expense.toMap());
      return id;
    } catch (e) {
      LoggerService.error('Error adding expense', e);
      rethrow;
    }
  }

  Future<void> updateExpense(Expense expense) async {
    try {
      await _expensesRef(expense.accountId)
          .doc(expense.id)
          .update(expense.copyWith().toMap());
    } catch (e) {
      LoggerService.error('Error updating expense', e);
      rethrow;
    }
  }

  Future<void> deleteExpense(String accountId, String expenseId) async {
    try {
      await _expensesRef(accountId).doc(expenseId).delete();
    } catch (e) {
      LoggerService.error('Error deleting expense', e);
      rethrow;
    }
  }

  double calculateTotal(List<Expense> expenses) {
    return expenses.fold(0.0, (total, e) => total + e.amount);
  }

  Map<String, double> totalsByCategory(List<Expense> expenses) {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  Map<String, double> totalsByRegisteredBy(List<Expense> expenses) {
    final map = <String, double>{};
    for (final e in expenses) {
      final key = e.registeredByName.isNotEmpty
          ? e.registeredByName
          : e.registeredBy;
      map[key] = (map[key] ?? 0) + e.amount;
    }
    return map;
  }
}

class InviteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    var seed = random;
    for (var i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buffer.write(chars[seed % chars.length]);
    }
    return buffer.toString();
  }

  Future<InviteCode> createInviteCode({
    required String accountId,
    required String createdBy,
    Duration validity = const Duration(days: 7),
  }) async {
    final code = _generateCode();
    final invite = InviteCode(
      code: code,
      accountId: accountId,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(validity),
    );

    await _firestore
        .collection(AppConstants.inviteCodesCollection)
        .doc(code)
        .set(invite.toMap());

    return invite;
  }

  Future<InviteCode?> getInviteCode(String code) async {
    final doc = await _firestore
        .collection(AppConstants.inviteCodesCollection)
        .doc(code.toUpperCase())
        .get();
    if (doc.exists) {
      return InviteCode.fromMap(doc.id, doc.data()!);
    }
    return null;
  }
}

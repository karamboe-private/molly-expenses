import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import '../models/expense.dart';
import '../models/account.dart';
import '../services/expense_service.dart';
import '../services/storage_service.dart';
import '../services/receipt_service.dart';
import '../services/logger_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _expenseService = ExpenseService();
  final StorageService _storageService = StorageService();
  final ReceiptService _receiptService = ReceiptService();
  final InviteService _inviteService = InviteService();
  final _uuid = const Uuid();
  final _picker = ImagePicker();

  List<Expense> _expenses = [];
  bool _isLoading = false;
  bool _isAnalyzing = false;
  String? _errorMessage;
  StreamSubscription<List<Expense>>? _subscription;

  String? _accountId;
  String? _registeredByFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _categoryFilter;
  final Set<String> _pendingExpenseIds = {};

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;

  double get totalAmount => _expenseService.calculateTotal(_expenses);

  double get todayTotal => _sumForDateRange(_startOfToday(), _startOfToday());

  double get weekTotal =>
      _sumForDateRange(_startOfWeek(DateTime.now()), _startOfToday());

  double get monthTotal => _sumForDateRange(_startOfMonth(), _startOfToday());

  List<Expense> get monthExpenses {
    final monthStart = _startOfMonth();
    return _expenses
        .where((e) => !_dateOnly(e.expenseDate).isBefore(monthStart))
        .toList();
  }

  Map<String, double> get categoryTotals =>
      _expenseService.totalsByCategory(_expenses);
  Map<String, double> get registeredByTotals =>
      _expenseService.totalsByRegisteredBy(_expenses);

  double calculateTotal(List<Expense> expenses) =>
      _expenseService.calculateTotal(expenses);

  Map<String, double> totalsByCategory(List<Expense> expenses) =>
      _expenseService.totalsByCategory(expenses);

  void subscribe({
    required String accountId,
    bool isOwner = false,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    _accountId = accountId;
    _registeredByFilter = isOwner ? null : userId;
    _startDate = startDate;
    _endDate = endDate;
    _categoryFilter = category;

    _subscription?.cancel();
    _subscription = _expenseService
        .streamExpenses(
          accountId: accountId,
          registeredBy: _registeredByFilter,
          startDate: startDate,
          endDate: endDate,
          category: category,
        )
        .listen(
          (expenses) {
            _applyStreamExpenses(expenses);
          },
          onError: (e) {
            LoggerService.error('Expense stream error', e);
            _errorMessage = 'Failed to load expenses';
            notifyListeners();
          },
        );
  }

  void refreshDashboard({
    required String accountId,
    bool isOwner = false,
    String? userId,
  }) {
    final now = DateTime.now();
    final monthStart = _startOfMonth(now);
    final weekStart = _startOfWeek(now);
    final startDate = weekStart.isBefore(monthStart) ? weekStart : monthStart;

    subscribe(
      accountId: accountId,
      isOwner: isOwner,
      userId: userId,
      startDate: startDate,
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  void updateFilters({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    if (_accountId == null) return;
    subscribe(
      accountId: _accountId!,
      isOwner: _registeredByFilter == null,
      userId: _registeredByFilter,
      startDate: startDate,
      endDate: endDate,
      category: category,
    );
  }

  Future<List<Expense>> fetchExpensesForReport({
    required String accountId,
    bool isOwner = false,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    return _expenseService.getExpenses(
      accountId: accountId,
      registeredBy: isOwner ? null : userId,
      startDate: startDate,
      endDate: endDate,
      category: category,
    );
  }

  Future<bool> saveExpense({
    required Expense expense,
    XFile? receiptImage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      var expenseToSave = expense;
      final expenseId =
          expense.id.isEmpty ? _uuid.v4() : expense.id;

      if (receiptImage != null &&
          (expenseToSave.receiptUrl == null || expenseToSave.receiptUrl!.isEmpty)) {
        final upload = await _storageService.uploadReceipt(
          accountId: expense.accountId,
          expenseId: expenseId,
          imageFile: receiptImage,
        );
        expenseToSave = expenseToSave.copyWith(receiptUrl: upload.downloadUrl);
      }

      if (expense.id.isEmpty) {
        final newExpense = Expense(
          id: expenseId,
          accountId: expenseToSave.accountId,
          registeredBy: expenseToSave.registeredBy,
          registeredByName: expenseToSave.registeredByName,
          amount: expenseToSave.amount,
          currency: expenseToSave.currency,
          expenseDate: expenseToSave.expenseDate,
          merchant: expenseToSave.merchant,
          category: expenseToSave.category,
          description: expenseToSave.description,
          receiptUrl: expenseToSave.receiptUrl,
          receiptAnalysis: expenseToSave.receiptAnalysis,
          status: AppConstants.statusConfirmed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _expenseService.addExpense(newExpense);
        _pendingExpenseIds.add(newExpense.id);
        _upsertExpense(newExpense);
      } else {
        await _expenseService.updateExpense(expenseToSave);
        _pendingExpenseIds.add(expenseToSave.id);
        _upsertExpense(expenseToSave);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on StorageUploadException catch (e) {
      LoggerService.error('Receipt upload failed', e);
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      LoggerService.error('Error saving expense', e);
      _isLoading = false;
      _errorMessage = 'Failed to save expense';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExpense(String accountId, String expenseId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _expenseService.deleteExpense(accountId, expenseId);
      _pendingExpenseIds.remove(expenseId);
      _expenses.removeWhere((expense) => expense.id == expenseId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      LoggerService.error('Error deleting expense', e);
      _isLoading = false;
      _errorMessage = 'Failed to delete expense';
      notifyListeners();
      return false;
    }
  }

  Future<ReceiptScanResult?> scanReceipt({
    required String accountId,
    ImageSource source = ImageSource.camera,
  }) async {
    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (image == null) {
        _isAnalyzing = false;
        notifyListeners();
        return null;
      }

      final tempId = _uuid.v4();
      final upload = await _storageService.uploadReceipt(
        accountId: accountId,
        expenseId: tempId,
        imageFile: image,
      );

      final analysis = await _receiptService.analyzeReceipt(
        storagePath: upload.storagePath,
      );

      _isAnalyzing = false;
      notifyListeners();

      return ReceiptScanResult(
        image: image,
        receiptUrl: upload.downloadUrl,
        analysis: analysis,
        receiptAnalysisRaw: analysis?.raw,
      );
    } on StorageUploadException catch (e) {
      LoggerService.error('Receipt upload failed during scan', e);
      _isAnalyzing = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      LoggerService.error('Error scanning receipt', e);
      _isAnalyzing = false;
      _errorMessage = 'Failed to scan receipt';
      notifyListeners();
      return null;
    }
  }

  Future<InviteCode?> createInviteCode({
    required String accountId,
    required String createdBy,
  }) async {
    try {
      return await _inviteService.createInviteCode(
        accountId: accountId,
        createdBy: createdBy,
      );
    } catch (e) {
      LoggerService.error('Error creating invite code', e);
      _errorMessage = 'Failed to create invite code';
      notifyListeners();
      return null;
    }
  }

  bool _matchesCurrentFilters(Expense expense) {
    if (_accountId != expense.accountId) return false;
    if (_registeredByFilter != null &&
        expense.registeredBy != _registeredByFilter) {
      return false;
    }
    if (_startDate != null &&
        _dateOnly(expense.expenseDate).isBefore(_dateOnly(_startDate!))) {
      return false;
    }
    if (_endDate != null &&
        _dateOnly(expense.expenseDate).isAfter(_dateOnly(_endDate!))) {
      return false;
    }
    if (_categoryFilter != null &&
        _categoryFilter!.isNotEmpty &&
        _categoryFilter != 'All' &&
        expense.category != _categoryFilter) {
      return false;
    }
    return true;
  }

  void _applyStreamExpenses(List<Expense> streamExpenses) {
    final streamIds = streamExpenses.map((expense) => expense.id).toSet();
    _pendingExpenseIds.removeWhere(streamIds.contains);

    final merged = {for (final expense in streamExpenses) expense.id: expense};

    for (final pendingId in _pendingExpenseIds) {
      final pending = _expenses.where((expense) => expense.id == pendingId);
      for (final expense in pending) {
        if (_matchesCurrentFilters(expense)) {
          merged[expense.id] = expense;
        }
      }
    }

    _expenses = merged.values.toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    notifyListeners();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _startOfToday([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _startOfMonth([DateTime? reference]) {
    final now = reference ?? DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  DateTime _startOfWeek(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  double _sumForDateRange(DateTime start, DateTime end) {
    final rangeStart = _dateOnly(start);
    final rangeEnd = _dateOnly(end);
    final filtered = _expenses.where((expense) {
      final expenseDay = _dateOnly(expense.expenseDate);
      return !expenseDay.isBefore(rangeStart) && !expenseDay.isAfter(rangeEnd);
    });
    return _expenseService.calculateTotal(filtered.toList());
  }

  void _upsertExpense(Expense expense) {
    _expenses.removeWhere((existing) => existing.id == expense.id);
    if (_matchesCurrentFilters(expense)) {
      _expenses.add(expense);
      _expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class ReceiptScanResult {
  final XFile image;
  final String? receiptUrl;
  final ReceiptAnalysisResult? analysis;
  final Map<String, dynamic>? receiptAnalysisRaw;

  ReceiptScanResult({
    required this.image,
    this.receiptUrl,
    this.analysis,
    this.receiptAnalysisRaw,
  });
}

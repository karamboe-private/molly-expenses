import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/constants.dart';

class Expense {
  final String id;
  final String accountId;
  final String registeredBy;
  final String registeredByName;
  final double amount;
  final String currency;
  final DateTime expenseDate;
  final String merchant;
  final String category;
  final String description;
  final String? receiptUrl;
  final Map<String, dynamic>? receiptAnalysis;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.accountId,
    required this.registeredBy,
    this.registeredByName = '',
    required this.amount,
    this.currency = 'NOK',
    required this.expenseDate,
    this.merchant = '',
    this.category = 'Other',
    this.description = '',
    this.receiptUrl,
    this.receiptAnalysis,
    this.status = 'confirmed',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDraft => status == 'draft';
  bool get isConfirmed => status == 'confirmed';

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'registeredBy': registeredBy,
      'registeredByName': registeredByName,
      'amount': amount,
      'currency': currency,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'merchant': merchant,
      'category': category,
      'description': description,
      'receiptUrl': receiptUrl,
      'receiptAnalysis': receiptAnalysis,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      accountId: map['accountId'] ?? '',
      registeredBy: map['registeredBy'] ?? '',
      registeredByName: map['registeredByName'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] ?? 'NOK',
      expenseDate:
          (map['expenseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      merchant: map['merchant'] ?? '',
      category: map['category'] ?? 'Other',
      description: map['description'] ?? '',
      receiptUrl: map['receiptUrl'],
      receiptAnalysis: map['receiptAnalysis'] != null
          ? Map<String, dynamic>.from(map['receiptAnalysis'])
          : null,
      status: map['status'] ?? 'confirmed',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Expense copyWith({
    String? registeredByName,
    double? amount,
    String? currency,
    DateTime? expenseDate,
    String? merchant,
    String? category,
    String? description,
    String? receiptUrl,
    Map<String, dynamic>? receiptAnalysis,
    String? status,
  }) {
    return Expense(
      id: id,
      accountId: accountId,
      registeredBy: registeredBy,
      registeredByName: registeredByName ?? this.registeredByName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      expenseDate: expenseDate ?? this.expenseDate,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptAnalysis: receiptAnalysis ?? this.receiptAnalysis,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class ReceiptAnalysisResult {
  final double? amount;
  final String? currency;
  final DateTime? date;
  final String? merchant;
  final String? suggestedCategory;
  final String? description;
  final Map<String, dynamic>? raw;

  ReceiptAnalysisResult({
    this.amount,
    this.currency,
    this.date,
    this.merchant,
    this.suggestedCategory,
    this.description,
    this.raw,
  });

  factory ReceiptAnalysisResult.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    final dateStr = map['date'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      parsedDate = DateTime.tryParse(dateStr);
    }

    return ReceiptAnalysisResult(
      amount: _parseAmount(map['amount']),
      currency: map['currency'] as String?,
      date: parsedDate,
      merchant: _parseString(map['merchant']),
      suggestedCategory: _normalizeCategory(map['suggestedCategory'] as String?),
      description: _parseString(map['description']),
      raw: map,
    );
  }

  static double? _parseAmount(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d,.\-]'), '').replaceAll(',', '.');
      return double.tryParse(cleaned);
    }
    return null;
  }

  static String? _parseString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeCategory(String? category) {
    if (category == null || category.trim().isEmpty) return null;
    final normalized = category.trim();
    if (AppConstants.expenseCategories.contains(normalized)) {
      return normalized;
    }
    return 'Other';
  }
}

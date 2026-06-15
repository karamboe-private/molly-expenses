import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/constants.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../widgets/receipt_preview.dart';

class AddExpenseScreenArgs {
  final String accountId;
  final String registeredBy;
  final String registeredByName;
  final Expense? expense;
  final ReceiptScanResult? scanResult;

  AddExpenseScreenArgs({
    required this.accountId,
    required this.registeredBy,
    required this.registeredByName,
    this.expense,
    this.scanResult,
  });

  factory AddExpenseScreenArgs.fromScan({
    required ReceiptScanResult scanResult,
    required String accountId,
    required String registeredBy,
    required String registeredByName,
  }) {
    return AddExpenseScreenArgs(
      accountId: accountId,
      registeredBy: registeredBy,
      registeredByName: registeredByName,
      scanResult: scanResult,
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  final AddExpenseScreenArgs? args;

  const AddExpenseScreen({super.key, this.args});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _descriptionController;
  late DateTime _expenseDate;
  late String _category;
  late String _currency;
  XFile? _receiptImage;
  String? _receiptUrl;
  Map<String, dynamic>? _receiptAnalysisRaw;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    final expense = args?.expense;
    final analysis = args?.scanResult?.analysis;

    _isEditing = expense != null;
    _amountController = TextEditingController(
      text: expense?.amount.toStringAsFixed(2) ??
          analysis?.amount?.toStringAsFixed(2) ??
          '',
    );
    _merchantController = TextEditingController(
      text: expense?.merchant ?? analysis?.merchant ?? '',
    );
    _descriptionController = TextEditingController(
      text: expense?.description ?? analysis?.description ?? '',
    );
    _expenseDate = expense?.expenseDate ?? analysis?.date ?? DateTime.now();
    _category = expense?.category ??
        analysis?.suggestedCategory ??
        'Other';
    _currency = expense?.currency ?? analysis?.currency ?? AppConstants.defaultCurrency;
    _receiptImage = args?.scanResult?.image;
    _receiptUrl = expense?.receiptUrl ?? args?.scanResult?.receiptUrl;
    _receiptAnalysisRaw =
        expense?.receiptAnalysis ?? args?.scanResult?.receiptAnalysisRaw;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  bool get _hasAttachment => _receiptImage != null || _receiptUrl != null;

  Future<void> _showAttachmentOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from library'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      await _pickReceiptImage(source);
    }
  }

  Future<void> _pickReceiptImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
    );

    if (image != null && mounted) {
      setState(() {
        _receiptImage = image;
        _receiptUrl = null;
        _receiptAnalysisRaw = null;
      });
    }
  }

  void _removeAttachment() {
    setState(() {
      _receiptImage = null;
      _receiptUrl = null;
      _receiptAnalysisRaw = null;
    });
  }

  Widget _buildAttachmentSection() {
    if (_hasAttachment) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ReceiptPreview(
                imageFile: _receiptImage,
                imageUrl: _receiptUrl,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _removeAttachment,
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove attachment',
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _showAttachmentOptions,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Replace attachment'),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _showAttachmentOptions,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add receipt or documentation',
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Optional photo of receipt, invoice, or other proof',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final args = widget.args;
    if (args == null) return;

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null) return;

    final expense = Expense(
      id: args.expense?.id ?? '',
      accountId: args.accountId,
      registeredBy: args.registeredBy,
      registeredByName: args.registeredByName,
      amount: amount,
      currency: _currency,
      expenseDate: _expenseDate,
      merchant: _merchantController.text.trim(),
      category: _category,
      description: _descriptionController.text.trim(),
      receiptUrl: _receiptUrl,
      receiptAnalysis: _receiptAnalysisRaw,
      status: AppConstants.statusConfirmed,
      createdAt: args.expense?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final provider = context.read<ExpenseProvider>();
    final success = await provider.saveExpense(
      expense: expense,
      receiptImage: _receiptImage,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Expense updated' : 'Expense saved'),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to save'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAttachmentSection(),
              if (_receiptAnalysisRaw != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Fields pre-filled from receipt scan. Please verify before saving.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$_currency ',
                  prefixIcon: const Icon(Icons.payments),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Amount is required';
                  }
                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(dateFormat.format(_expenseDate)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Store',
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: AppConstants.expenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Update Expense' : 'Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

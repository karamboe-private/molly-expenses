import 'package:cloud_functions/cloud_functions.dart';
import '../models/expense.dart';
import 'logger_service.dart';

class ReceiptService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<ReceiptAnalysisResult?> analyzeReceipt({
    required String storagePath,
  }) async {
    try {
      final callable = _functions.httpsCallable('analyzeReceipt');
      final result = await callable.call<Map<String, dynamic>>({
        'storagePath': storagePath,
      });

      final data = Map<String, dynamic>.from(result.data);
      if (data['success'] == false) {
        LoggerService.error('Receipt analysis failed: ${data['error']}');
        return null;
      }

      final analysis = data['analysis'] != null
          ? Map<String, dynamic>.from(data['analysis'] as Map)
          : data;

      return ReceiptAnalysisResult.fromMap(analysis);
    } catch (e) {
      LoggerService.error('Error calling analyzeReceipt', e);
      return null;
    }
  }
}

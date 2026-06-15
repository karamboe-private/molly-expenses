import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class StorageUploadException implements Exception {
  final String message;

  StorageUploadException(this.message);

  @override
  String toString() => message;
}

class ReceiptUploadResult {
  final String downloadUrl;
  final String storagePath;

  const ReceiptUploadResult({
    required this.downloadUrl,
    required this.storagePath,
  });
}

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<ReceiptUploadResult> uploadReceipt({
    required String accountId,
    required String expenseId,
    required XFile imageFile,
  }) async {
    try {
      await _ensureAuthenticatedUpload(accountId);

      final ext = _resolveExtension(imageFile);
      final fileName = '$expenseId$ext';
      final storagePath = 'receipts/$accountId/$fileName';
      final ref = _storage.ref().child(storagePath);
      final fileBytes = await imageFile.readAsBytes();
      final contentType = _resolveContentType(imageFile, ext);

      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = ref.putData(fileBytes, metadata);
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw StorageUploadException(
            'Receipt upload timed out. Check your connection and try again.',
          );
        },
      );

      if (snapshot.state == TaskState.success) {
        return ReceiptUploadResult(
          downloadUrl: await snapshot.ref.getDownloadURL(),
          storagePath: storagePath,
        );
      }

      throw StorageUploadException('Receipt upload did not complete.');
    } on StorageUploadException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('StorageService uploadReceipt Firebase error: ${e.code} ${e.message}');
      throw StorageUploadException(_messageForFirebaseError(e));
    } catch (e) {
      debugPrint('StorageService uploadReceipt error: $e');
      throw StorageUploadException(
        'Could not upload receipt. Please try again.',
      );
    }
  }

  Future<String?> uploadReceiptBytes({
    required String accountId,
    required String expenseId,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async {
    try {
      final fileName = '$expenseId$extension';
      final ref = _storage.ref().child('receipts/$accountId/$fileName');
      final contentType =
          extension.contains('png') ? 'image/png' : 'image/jpeg';
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      if (snapshot.state == TaskState.success) {
        return await snapshot.ref.getDownloadURL();
      }
      return null;
    } catch (e) {
      debugPrint('StorageService uploadReceiptBytes error: $e');
      return null;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('StorageService delete error: $e');
    }
  }

  Future<void> _ensureAuthenticatedUpload(String accountId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StorageUploadException(
        'Please sign in again before uploading a receipt.',
      );
    }

    await user.getIdToken(true);

    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final profileAccountId = profile.data()?['accountId'] as String?;
    if (profileAccountId != accountId) {
      throw StorageUploadException(
        'Account mismatch. Please sign out and sign in again.',
      );
    }
  }

  String _resolveExtension(XFile imageFile) {
    final ext = path.extension(imageFile.name).toLowerCase();
    if (ext.isNotEmpty) return ext;

    final mimeType = imageFile.mimeType?.toLowerCase();
    if (mimeType == 'image/png') return '.png';
    if (mimeType == 'image/webp') return '.webp';
    if (mimeType == 'image/gif') return '.gif';
    return '.jpg';
  }

  String _resolveContentType(XFile imageFile, String ext) {
    final mimeType = imageFile.mimeType?.toLowerCase();
    if (mimeType == 'image/png') return 'image/png';
    if (mimeType == 'image/webp') return 'image/webp';
    if (mimeType == 'image/gif') return 'image/gif';
    if (mimeType == 'image/heic' || mimeType == 'image/heif') {
      return mimeType!;
    }
    if (mimeType == 'image/jpeg' || mimeType == 'image/jpg') {
      return 'image/jpeg';
    }

    switch (ext.replaceAll('.', '')) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  String _messageForFirebaseError(FirebaseException error) {
    switch (error.code) {
      case 'unauthorized':
      case 'permission-denied':
        return 'You do not have permission to upload receipts.';
      case 'unauthenticated':
        return 'Please sign in again before uploading a receipt.';
      case 'canceled':
        return 'Receipt upload was cancelled.';
      case 'retry-limit-exceeded':
        return 'Receipt upload failed after several attempts. Please try again.';
      default:
        return error.message ?? 'Could not upload receipt. Please try again.';
    }
  }
}

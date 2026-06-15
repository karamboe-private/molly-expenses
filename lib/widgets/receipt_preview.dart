import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptPreview extends StatelessWidget {
  final XFile? imageFile;
  final String? imageUrl;

  const ReceiptPreview({
    super.key,
    this.imageFile,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (imageFile != null && !kIsWeb) {
      return Image.file(
        File(imageFile!.path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image, size: 48),
        ),
      );
    }

    if (imageFile != null && kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: imageFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        },
      );
    }

    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image, size: 48),
        ),
      );
    }

    return const Center(child: Icon(Icons.receipt, size: 48));
  }
}

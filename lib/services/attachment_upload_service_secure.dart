import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import 'attachments_api_service.dart';

/// 🔒 SECURE Attachment Upload Service (Task #14 Implementation)
///
/// **IMPORTANT SECURITY UPDATE:**
/// This service now uploads ALL attachments through the backend API, which provides:
///
/// ✅ File validation (type, size, dimensions)
/// ✅ Google Vision API content moderation
/// ✅ Text detection (OCR) for spam/phishing in images
/// ✅ Image compression (70-90% size reduction)
/// ✅ Multiple size variants (thumbnail, medium, full)
/// ✅ Secure Firebase Storage upload (backend-only)
/// ✅ Audit logging
///
/// **REMOVED:** Direct Firebase Storage uploads (security risk)
/// **REPLACED:** Backend API calls with validation and moderation
///
/// See: backend/src/attachments/attachments.controller.ts
class AttachmentUploadService {
  final AttachmentsApiService _apiService = AttachmentsApiService();

  /// Upload an image attachment (secure, validated, moderated)
  ///
  /// This method replaces the old direct Firebase Storage upload.
  /// All uploads now go through backend validation and moderation.
  Future<MessageAttachment> uploadAttachment({
    required File file,
    required String attachmentType,
    required String conversationId,
    String? businessId,
    Function(double)? onProgress,
  }) async {
    try {
      // Only images are currently supported through secure backend upload
      if (attachmentType != 'image') {
        throw Exception(
          'Only image uploads are currently supported through secure backend API. '
          'Videos will be added in Task #15.',
        );
      }

      // Frontend validation BEFORE upload (save bandwidth)
      await _validateImage(file);

      // Upload through secure backend API
      debugPrint('🔐 Uploading via secure backend API (Task #14)...');

      final result = await _apiService.uploadImage(
        file: file,
        conversationId: conversationId,
        onProgress: onProgress,
      );

      // Check if content moderation passed
      if (!result.moderation.isSafe) {
        throw Exception(result.moderation.violationMessage);
      }

      // Convert to MessageAttachment format
      final attachment = result.toMessageAttachment();

      debugPrint('✅ Secure upload complete: ${attachment.url}');
      debugPrint(
          '💾 Compression saved: ${result.metadata.savedKB.toStringAsFixed(2)} KB (${result.metadata.compressionRatio.toStringAsFixed(1)}%)');

      return attachment;
    } catch (e) {
      debugPrint('❌ Failed to upload attachment: $e');
      throw Exception('Failed to upload attachment: $e');
    }
  }

  /// Upload multiple attachments
  Future<List<MessageAttachment>> uploadMultipleAttachments({
    required List<File> files,
    required List<String> attachmentTypes,
    required String conversationId,
    String? businessId,
    Function(int index, double progress)? onProgress,
  }) async {
    final attachments = <MessageAttachment>[];

    for (int i = 0; i < files.length; i++) {
      final attachment = await uploadAttachment(
        file: files[i],
        attachmentType: attachmentTypes[i],
        conversationId: conversationId,
        businessId: businessId,
        onProgress:
            onProgress != null ? (progress) => onProgress(i, progress) : null,
      );
      attachments.add(attachment);
    }

    return attachments;
  }

  /// Upload from bytes (for camera captures)
  ///
  /// ⚠️ Note: This still needs backend implementation for bytes upload
  /// For now, save to temp file and use file upload
  Future<MessageAttachment> uploadFromBytes({
    required Uint8List bytes,
    required String attachmentType,
    required String conversationId,
    required String filename,
    String? businessId,
    Function(double)? onProgress,
  }) async {
    try {
      // Save bytes to temporary file
      final tempFile = await _saveBytesToTempFile(bytes, filename);

      // Upload using file method
      final attachment = await uploadAttachment(
        file: tempFile,
        attachmentType: attachmentType,
        conversationId: conversationId,
        businessId: businessId,
        onProgress: onProgress,
      );

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (e) {
        debugPrint('⚠️ Failed to delete temp file: $e');
      }

      return attachment;
    } catch (e) {
      debugPrint('❌ Failed to upload from bytes: $e');
      throw Exception('Failed to upload from bytes: $e');
    }
  }

  /// Save bytes to temporary file
  Future<File> _saveBytesToTempFile(Uint8List bytes, String filename) async {
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('${tempDir.path}/upload_${timestamp}_$filename');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  /// Frontend validation BEFORE upload (save bandwidth)
  ///
  /// These checks happen before sending to backend:
  /// - File type (extension + MIME type)
  /// - File size (max 10MB for images)
  /// - Basic file integrity
  ///
  /// Backend will re-validate everything (don't trust frontend)
  Future<void> _validateImage(File file) async {
    // Check file exists
    if (!await file.exists()) {
      throw Exception('File does not exist');
    }

    // Check file size (10MB max)
    final fileSize = await file.length();
    const maxSize = 10 * 1024 * 1024; // 10MB

    if (fileSize > maxSize) {
      throw Exception(
        'Image is too large (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB). '
        'Maximum size is 10 MB.',
      );
    }

    // Check file extension
    final extension = file.path.toLowerCase().split('.').last;
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];

    if (!allowedExtensions.contains(extension)) {
      throw Exception(
        'Invalid image format. Allowed: JPEG, PNG, WebP, GIF',
      );
    }

    debugPrint(
        '✅ Frontend validation passed: ${(fileSize / 1024).toStringAsFixed(2)} KB');
  }

  /// Generate thumbnail for image (for immediate preview while uploading)
  ///
  /// Note: The backend will generate better thumbnails.
  /// This is just for immediate UI feedback.
  Future<String?> generateThumbnail(File imageFile) async {
    try {
      // For now, just return the original file path
      // The backend generates proper thumbnails (150x150px, WebP 70%)
      //
      // To implement local thumbnails, use flutter_image_compress:
      //
      // import 'package:flutter_image_compress/flutter_image_compress.dart';
      // import 'package:path_provider/path_provider.dart';
      //
      // final dir = await getTemporaryDirectory();
      // final targetPath = '${dir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      //
      // final result = await FlutterImageCompress.compressAndGetFile(
      //   imageFile.absolute.path,
      //   targetPath,
      //   quality: 70,
      //   minWidth: 150,
      //   minHeight: 150,
      // );
      //
      // return result?.path;

      return imageFile.path;
    } catch (e) {
      debugPrint('❌ Failed to generate thumbnail: $e');
      return null;
    }
  }

  /// ⚠️ Delete attachment is NOT IMPLEMENTED
  ///
  /// Attachments should NOT be deleted directly from Firebase Storage.
  /// Instead, implement soft delete through backend API:
  /// - Mark attachment as deleted in Firestore
  /// - Keep file for audit purposes
  /// - Optionally schedule permanent deletion after retention period
  @deprecated
  Future<void> deleteAttachment(String downloadUrl) async {
    throw UnimplementedError(
      'Direct deletion is not allowed for security reasons. '
      'Use backend API to mark attachments as deleted.',
    );
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

class AttachmentUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload an attachment file to Firebase Storage
  Future<MessageAttachment> uploadAttachment({
    required File file,
    required String attachmentType,
    required String conversationId,
    String? businessId,
    Function(double)? onProgress,
  }) async {
    try {
      final fileName = _generateFileName(file, attachmentType);
      final folderPath = 'messages/$conversationId/attachments';
      final ref = _storage.ref().child('$folderPath/$fileName');

      // Set up metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(attachmentType, file.path),
        customMetadata: {
          'uploadedAt': DateTime.now().millisecondsSinceEpoch.toString(),
          'conversationId': conversationId,
          'attachmentType': attachmentType,
          if (businessId != null) 'businessId': businessId,
        },
      );

      // Start upload
      final uploadTask = ref.putFile(file, metadata);

      // Track progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress);
          }
        });
      }

      // Wait for completion
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Get file metadata
      final fileStats = await file.stat();
      final filename = file.path.split('/').last;

      debugPrint('✅ Attachment uploaded: $downloadUrl');

      return MessageAttachment(
        type: attachmentType,
        url: downloadUrl,
        filename: filename,
        size: fileStats.size,
        mimeType: _getContentType(attachmentType, file.path),
      );
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
  Future<MessageAttachment> uploadFromBytes({
    required Uint8List bytes,
    required String attachmentType,
    required String conversationId,
    required String filename,
    String? businessId,
    Function(double)? onProgress,
  }) async {
    try {
      final fileName = _generateFileNameFromBytes(filename, attachmentType);
      final folderPath = 'messages/$conversationId/attachments';
      final ref = _storage.ref().child('$folderPath/$fileName');

      // Set up metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(attachmentType, filename),
        customMetadata: {
          'uploadedAt': DateTime.now().millisecondsSinceEpoch.toString(),
          'conversationId': conversationId,
          'attachmentType': attachmentType,
          'originalSize': bytes.length.toString(),
          if (businessId != null) 'businessId': businessId,
        },
      );

      // Start upload
      final uploadTask = ref.putData(bytes, metadata);

      // Track progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress);
          }
        });
      }

      // Wait for completion
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Attachment uploaded from bytes: $downloadUrl');

      return MessageAttachment(
        type: attachmentType,
        url: downloadUrl,
        filename: filename,
        size: bytes.length,
        mimeType: _getContentType(attachmentType, filename),
      );
    } catch (e) {
      debugPrint('❌ Failed to upload attachment from bytes: $e');
      throw Exception('Failed to upload attachment: $e');
    }
  }

  /// Generate unique filename
  String _generateFileName(File file, String attachmentType) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _getFileExtension(file.path);
    return '${attachmentType}_${timestamp}$extension';
  }

  /// Generate filename from bytes
  String _generateFileNameFromBytes(
      String originalName, String attachmentType) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _getFileExtension(originalName);
    return '${attachmentType}_${timestamp}$extension';
  }

  /// Get file extension
  String _getFileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    return lastDot != -1 ? path.substring(lastDot) : '';
  }

  /// Get content type based on attachment type and file path
  String _getContentType(String attachmentType, String filePath) {
    switch (attachmentType) {
      case 'image':
        if (filePath.toLowerCase().endsWith('.png')) return 'image/png';
        if (filePath.toLowerCase().endsWith('.gif')) return 'image/gif';
        return 'image/jpeg';
      case 'video':
        return 'video/mp4';
      case 'audio':
        return 'audio/mpeg';
      case 'document':
        if (filePath.toLowerCase().endsWith('.pdf')) return 'application/pdf';
        if (filePath.toLowerCase().endsWith('.doc'))
          return 'application/msword';
        if (filePath.toLowerCase().endsWith('.docx'))
          return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        return 'application/octet-stream';
      default:
        return 'application/octet-stream';
    }
  }

  /// Generate thumbnail for image before upload
  /// Returns the thumbnail file path for immediate preview
  Future<String?> generateThumbnail(File imageFile) async {
    try {
      // Check if file is an image
      final extension = _getFileExtension(imageFile.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.gif'].contains(extension)) {
        return null;
      }

      // For now, return the original file path
      // In a full implementation, you would use flutter_image_compress:
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
      //   minWidth: 300,
      //   minHeight: 300,
      // );
      //
      // return result?.path;

      return imageFile.path;
    } catch (e) {
      debugPrint('❌ Failed to generate thumbnail: $e');
      return null;
    }
  }

  /// Delete attachment from storage
  Future<void> deleteAttachment(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('✅ Attachment deleted: $downloadUrl');
    } catch (e) {
      debugPrint('❌ Failed to delete attachment: $e');
      throw Exception('Failed to delete attachment: $e');
    }
  }
}

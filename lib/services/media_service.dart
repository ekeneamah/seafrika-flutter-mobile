import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:vendor_app/models/media.dart';
import 'package:vendor_app/services/firestore_service.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class MediaService extends ChangeNotifier {
  final FirestoreService _firestore;
  final FirebaseStorage _storage;
  List<Media> _media = [];
  bool _isLoading = false;

  MediaService({
    FirestoreService? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirestoreService(),
        _storage = storage ?? FirebaseStorage.instance;

  List<Media> get media => _media;
  bool get isLoading => _isLoading;

  Future<void> fetchMedia() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.getCollection(
        'media',
        queryBuilder: (query) => query
            .where('vendorId', isEqualTo: _firestore.currentUserId)
            .orderBy('timestamp', descending: true),
      );

      _media = snapshot.docs
          .map((doc) => Media.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Fetch media error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Media?> getMedia(String id) async {
    try {
      final doc = await _firestore.getDocument('media', id);
      return Media.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Get media error: $e');
      return null;
    }
  }

  Future<bool> uploadMedia(File file, String type) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final ref =
          _storage.ref().child('media/${_firestore.currentUserId}/$fileName');

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final mediaData = {
        'type': type,
        'url': downloadUrl,
        'thumbnail': type == 'video' ? null : downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'vendorId': _firestore.currentUserId,
        'metadata': {
          'fileName': fileName,
          'fileSize': file.lengthSync(),
          'mimeType': type == 'video' ? 'video/mp4' : 'image/jpeg',
        },
      };

      final docRef = await _firestore.addDocument('media', mediaData);
      final newMedia = Media.fromJson({
        ...mediaData,
        'id': docRef.id,
        'timestamp': DateTime.now(),
      });

      _media.add(newMedia);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Upload media error: $e');
      return false;
    }
  }

  /// Compress image to target size (default 1MB)
  Future<Uint8List> _compressImage(
    Uint8List imageBytes, {
    int maxSizeBytes = 1024 * 1024, // 1MB default
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
  }) async {
    try {
      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('Failed to decode image, returning original');
        return imageBytes;
      }

      // Resize if image is too large
      if (image.width > maxWidth || image.height > maxHeight) {
        // Calculate the scaling factor to maintain aspect ratio
        final double scaleWidth = maxWidth / image.width;
        final double scaleHeight = maxHeight / image.height;
        final double scale = math.min(scaleWidth, scaleHeight);

        final int newWidth = (image.width * scale).round();
        final int newHeight = (image.height * scale).round();

        image = img.copyResize(image, width: newWidth, height: newHeight);
        debugPrint(
            'Resized image from ${imageBytes.length} bytes to ${newWidth}x${newHeight}');
      }

      // First try WebP encoding for better compression
      int currentQuality = quality;
      Uint8List compressedBytes;
      bool useWebP = true;

      try {
        // Try WebP encoding - async operation
        compressedBytes = await _tryWebPEncoding(imageBytes, currentQuality);
        debugPrint(
            'WebP compression: ${compressedBytes.length} bytes at quality $currentQuality');
      } catch (e) {
        // Fallback to optimized JPEG
        useWebP = false;
        compressedBytes =
            Uint8List.fromList(img.encodeJpg(image, quality: currentQuality));
        debugPrint(
            'JPEG compression (WebP fallback): ${compressedBytes.length} bytes at quality $currentQuality');
      }

      // Reduce quality progressively if still too large
      while (compressedBytes.length > maxSizeBytes && currentQuality > 20) {
        currentQuality -= 10;
        if (useWebP) {
          try {
            compressedBytes =
                await _tryWebPEncoding(imageBytes, currentQuality);
            debugPrint(
                'WebP compressed to quality $currentQuality: ${compressedBytes.length} bytes');
          } catch (e) {
            useWebP = false;
            compressedBytes = Uint8List.fromList(
                img.encodeJpg(image, quality: currentQuality));
            debugPrint(
                'Switched to JPEG at quality $currentQuality: ${compressedBytes.length} bytes');
          }
        } else {
          compressedBytes =
              Uint8List.fromList(img.encodeJpg(image, quality: currentQuality));
          debugPrint(
              'JPEG compressed to quality $currentQuality: ${compressedBytes.length} bytes');
        }
      }

      // If still too large after quality reduction, try further resizing
      if (compressedBytes.length > maxSizeBytes) {
        while (compressedBytes.length > maxSizeBytes && image!.width > 800) {
          final double scale = math.sqrt(maxSizeBytes / compressedBytes.length);
          final int newWidth = (image.width * scale).round();
          final int newHeight = (image.height * scale).round();

          image = img.copyResize(image, width: newWidth, height: newHeight);

          // Re-encode the resized image
          final resizedBytes = Uint8List.fromList(img.encodePng(image));

          if (useWebP) {
            try {
              compressedBytes =
                  await _tryWebPEncoding(resizedBytes, currentQuality);
            } catch (e) {
              useWebP = false;
              compressedBytes = Uint8List.fromList(
                  img.encodeJpg(image, quality: currentQuality));
            }
          } else {
            compressedBytes = Uint8List.fromList(
                img.encodeJpg(image, quality: currentQuality));
          }
          debugPrint(
              'Further resized to ${newWidth}x${newHeight}: ${compressedBytes.length} bytes');
        }
      }

      final compressionRatio =
          (imageBytes.length / compressedBytes.length).toStringAsFixed(2);
      debugPrint(
          'Image compression completed: ${imageBytes.length} → ${compressedBytes.length} bytes (${compressionRatio}x smaller)');

      return compressedBytes;
    } catch (e) {
      debugPrint('Image compression failed: $e');
      // Return original if compression fails
      return imageBytes;
    }
  }

  /// Check if file needs compression based on size and type
  bool _shouldCompressMedia(Uint8List bytes, String type) {
    const int maxSize = 1024 * 1024; // 1MB
    return type == 'image' && bytes.length > maxSize;
  }

  /// Detect image format from bytes to set correct MIME type
  String _detectImageMimeType(Uint8List bytes) {
    // Check WebP signature
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    // Check JPEG signature
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    // Check PNG signature
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    // Default fallback
    return 'image/jpeg';
  }

  /// Try WebP encoding using flutter_image_compress for better compression
  Future<Uint8List> _tryWebPEncoding(Uint8List imageBytes, int quality) async {
    try {
      // Use flutter_image_compress for WebP conversion
      final webpBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        quality: quality,
        format: CompressFormat.webp,
      );

      if (webpBytes.isNotEmpty) {
        debugPrint('WebP compression successful: ${webpBytes.length} bytes');
        return webpBytes;
      } else {
        throw Exception('WebP compression returned empty bytes');
      }
    } catch (e) {
      debugPrint('WebP encoding failed: $e, falling back to JPEG');
      // Fallback to JPEG using the image package
      img.Image? image = img.decodeImage(imageBytes);
      if (image != null) {
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      } else {
        throw Exception('Failed to decode image for JPEG fallback');
      }
    }
  }

  /// Upload media from bytes data with customizable compression settings
  Future<String?> uploadMediaFromBytesWithCompression({
    required Uint8List bytes,
    required String fileName,
    required String type, // 'image' or 'video'
    String? vendorId,
    String? productId,
    // Compression settings
    int maxSizeBytes = 1024 * 1024, // 1MB default
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
    bool forceCompression = false,
  }) async {
    try {
      // Compress image if needed or forced
      Uint8List finalBytes = bytes;
      if (type == 'image' &&
          (forceCompression || bytes.length > maxSizeBytes)) {
        debugPrint('Compressing image before upload...');
        finalBytes = await _compressImage(
          bytes,
          maxSizeBytes: maxSizeBytes,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          quality: quality,
        );
        debugPrint(
            'Original size: ${bytes.length} bytes, Compressed size: ${finalBytes.length} bytes');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = fileName.replaceAll(RegExp(r'[^\w\-_\.]'), '_');
      final fullFileName = '${timestamp}_$safeName';

      final folderPath = productId != null
          ? 'products/$productId/media'
          : 'media/${vendorId ?? _firestore.currentUserId ?? 'unknown'}';

      final ref = _storage.ref().child('$folderPath/$fullFileName');

      // Upload the processed bytes with proper MIME type detection
      final uploadTask = ref.putData(
        finalBytes,
        SettableMetadata(
          contentType:
              type == 'video' ? 'video/mp4' : _detectImageMimeType(finalBytes),
          customMetadata: {
            'uploadedBy': vendorId ?? _firestore.currentUserId ?? 'unknown',
            'uploadedAt': timestamp.toString(),
            'originalFileName': fileName,
            'originalSize': bytes.length.toString(),
            'finalSize': finalBytes.length.toString(),
            'compressed': (type == 'image' && finalBytes.length != bytes.length)
                .toString(),
            'compressionSettings':
                'maxSize:$maxSizeBytes,quality:$quality,maxRes:${maxWidth}x$maxHeight',
            if (productId != null) 'productId': productId,
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint(
          'Media uploaded successfully: $downloadUrl (Final size: ${finalBytes.length} bytes)');
      return downloadUrl;
    } catch (e) {
      debugPrint('Upload media from bytes with compression error: $e');
      return null;
    }
  }

  /// Upload media from bytes data (for AssetEntity integration)
  Future<String?> uploadMediaFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String type, // 'image' or 'video'
    String? vendorId,
    String? productId,
  }) async {
    try {
      // Compress image if needed
      Uint8List finalBytes = bytes;
      if (_shouldCompressMedia(bytes, type)) {
        debugPrint('Compressing image before upload...');
        finalBytes = await _compressImage(bytes);
        debugPrint(
            'Original size: ${bytes.length} bytes, Compressed size: ${finalBytes.length} bytes');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = fileName.replaceAll(RegExp(r'[^\w\-_\.]'), '_');
      final fullFileName = '${timestamp}_$safeName';

      final folderPath = productId != null
          ? 'products/$productId/media'
          : 'media/${vendorId ?? _firestore.currentUserId ?? 'unknown'}';

      final ref = _storage.ref().child('$folderPath/$fullFileName');

      // Upload the processed bytes
      final uploadTask = ref.putData(
        finalBytes,
        SettableMetadata(
          contentType: type == 'video' ? 'video/mp4' : 'image/jpeg',
          customMetadata: {
            'uploadedBy': vendorId ?? _firestore.currentUserId ?? 'unknown',
            'uploadedAt': timestamp.toString(),
            'originalFileName': fileName,
            'originalSize': bytes.length.toString(),
            'finalSize': finalBytes.length.toString(),
            'compressed': _shouldCompressMedia(bytes, type).toString(),
            if (productId != null) 'productId': productId,
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint(
          'Media uploaded successfully: $downloadUrl (Final size: ${finalBytes.length} bytes)');
      return downloadUrl;
    } catch (e) {
      debugPrint('Upload media from bytes error: $e');
      return null;
    }
  }

  Future<bool> deleteMedia(String id) async {
    try {
      final media = await getMedia(id);
      if (media != null) {
        // Delete from Storage
        final ref = _storage.refFromURL(media.url);
        await ref.delete();

        // Delete from Firestore
        await _firestore.deleteDocument('media', id);
        _media.removeWhere((m) => m.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete media error: $e');
      return false;
    }
  }

  Future<List<Media>> getMediaByType(String type) async {
    try {
      final snapshot = await _firestore.getCollection(
        'media',
        queryBuilder: (query) => query
            .where('vendorId', isEqualTo: _firestore.currentUserId)
            .where('type', isEqualTo: type)
            .orderBy('timestamp', descending: true),
      );

      return snapshot.docs
          .map((doc) => Media.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get media by type error: $e');
      return [];
    }
  }

  Future<List<Media>> getMediaByProduct(String productId) async {
    try {
      final snapshot = await _firestore.getCollection(
        'media',
        queryBuilder: (query) => query
            .where('vendorId', isEqualTo: _firestore.currentUserId)
            .where('productId', isEqualTo: productId)
            .orderBy('timestamp', descending: true),
      );

      return snapshot.docs
          .map((doc) => Media.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get media by product error: $e');
      return [];
    }
  }

  Future<bool> updateMediaMetadata(
      String id, Map<String, dynamic> metadata) async {
    try {
      await _firestore.updateDocument(
        'media',
        id,
        {'metadata': metadata, 'updatedAt': FieldValue.serverTimestamp()},
      );

      final index = _media.indexWhere((m) => m.id == id);
      if (index != -1) {
        final updatedMedia = _media[index].copyWith(
          metadata: metadata,
          timestamp: DateTime.now(),
        );
        _media[index] = updatedMedia;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Update media metadata error: $e');
      return false;
    }
  }

  // Real-time listeners
  Stream<List<Media>> streamMedia() {
    return _firestore
        .streamCollection(
          'media',
          queryBuilder: (query) => query
              .where('vendorId', isEqualTo: _firestore.currentUserId)
              .orderBy('timestamp', descending: true),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) => Media.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<Media?> streamMediaItem(String id) {
    return _firestore.streamDocument('media', id).map((doc) =>
        doc.exists ? Media.fromJson(doc.data() as Map<String, dynamic>) : null);
  }
}

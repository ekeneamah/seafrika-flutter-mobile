import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/message.dart';
import '../config/api_config.dart';

/// Secure attachment upload via backend API (Task #14)
///
/// This service uploads images/videos through the backend API which provides:
/// - File validation (type, size, dimensions)
/// - Google Vision API content moderation
/// - Text detection (OCR) for spam/phishing
/// - Image compression with Sharp
/// - Multiple size variants (thumbnail, medium, full)
/// - Secure Firebase Storage upload
///
/// ⚠️ NEVER upload directly to Firebase Storage from frontend!
class AttachmentsApiService {
  final _storage = const FlutterSecureStorage();
  final http.Client _client;
  final String baseUrl;

  AttachmentsApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  /// Get auth token from storage
  Future<String?> _getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }

  /// Upload image with backend validation and moderation
  ///
  /// Returns URLs for 3 image variants:
  /// - thumbnail (150x150px) for lists
  /// - medium (800px width) for chat bubbles
  /// - full (1920px max) for full-screen view
  Future<ImageUploadResult> uploadImage({
    required File file,
    required String conversationId,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('🔐 Uploading image via secure backend API...');

      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Create multipart request
      final uri = Uri.parse('$baseUrl/attachments/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      request.headers['Authorization'] = 'Bearer $token';

      // Add file
      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        file.path,
        contentType: MediaType('image', _getImageExtension(file.path)),
      );
      request.files.add(multipartFile);

      // Add conversation ID
      request.fields['conversationId'] = conversationId;

      debugPrint(
          '📤 Sending image (${(file.lengthSync() / 1024).toStringAsFixed(2)} KB)...');

      // Send request with progress tracking
      final streamedResponse = await request.send();

      // Track upload progress
      if (onProgress != null) {
        var received = 0;
        final total = file.lengthSync();

        streamedResponse.stream.listen(
          (chunk) {
            received += chunk.length;
            onProgress(received / total);
          },
        );
      }

      // Get response
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Image uploaded successfully');
        debugPrint(
            '📊 Compression: ${data['metadata']['originalSize']} → ${data['metadata']['compressedSize']} bytes');
        debugPrint(
            '🛡️ Moderation: ${data['moderation']['isSafe'] ? 'SAFE' : 'UNSAFE'}');

        return ImageUploadResult.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        final message = error['message'] ?? 'Upload failed';
        debugPrint('❌ Upload failed: $message');
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('❌ Image upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Moderate existing image URL (without uploading)
  Future<ModerationResult> moderateImage(String imageUrl) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/attachments/moderate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ModerationResult.fromJson(data);
      } else {
        throw Exception('Moderation failed');
      }
    } catch (e) {
      debugPrint('❌ Moderation error: $e');
      throw Exception('Failed to moderate image: $e');
    }
  }

  /// Detect text in image (OCR)
  Future<String> detectTextInImage(String imageUrl) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/attachments/detect-text'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'imageUrl': imageUrl}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] ?? '';
      } else {
        throw Exception('Text detection failed');
      }
    } catch (e) {
      debugPrint('❌ Text detection error: $e');
      return '';
    }
  }

  /// Get image file extension
  String _getImageExtension(String path) {
    final extension = path.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      case 'gif':
        return 'gif';
      default:
        return 'jpeg';
    }
  }

  /// Upload document (PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT, RTF)
  Future<DocumentUploadResult> uploadDocument({
    required File file,
    required String conversationId,
    Function(double)? onProgress,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      debugPrint('📄 Uploading document: ${file.path}');

      final uri = Uri.parse('$baseUrl/attachments/document/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add document file
      final multipartFile = await http.MultipartFile.fromPath(
        'document',
        file.path,
        contentType: MediaType(
          _getDocumentMimeType(file.path).split('/')[0],
          _getDocumentMimeType(file.path).split('/')[1],
        ),
      );

      request.files.add(multipartFile);
      request.fields['conversationId'] = conversationId;

      // Send request with progress tracking
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        final data = jsonDecode(responseBody);

        debugPrint('✅ Document uploaded successfully');

        return DocumentUploadResult.fromJson(data);
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        debugPrint('❌ Upload failed: $errorBody');
        throw Exception(
            'Document upload failed: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Get document MIME type
  String _getDocumentMimeType(String path) {
    final extension = path.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'rtf':
        return 'application/rtf';
      default:
        return 'application/octet-stream';
    }
  }

  /// Upload video with frontend thumbnail generation (Task #15 - Option A)
  ///
  /// Constraints:
  /// - Max duration: 10 seconds
  /// - Max file size: 50MB
  /// - Formats: MP4, MOV, AVI
  ///
  /// Process:
  /// 1. Validate video duration using video_player
  /// 2. Generate thumbnail using video_thumbnail package
  /// 3. Upload video + thumbnail + metadata to backend
  /// 4. Backend validates, moderates, and uploads to Firebase
  Future<VideoUploadResult> uploadVideo({
    required File file,
    required String conversationId,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('🎥 Uploading video via secure backend API...');

      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Validate file size (50MB max)
      final fileSize = file.lengthSync();
      const maxSize = 50 * 1024 * 1024; // 50MB
      if (fileSize > maxSize) {
        throw Exception(
            'Video file is too large. Maximum size is 50MB (${(fileSize / (1024 * 1024)).toStringAsFixed(2)}MB)');
      }

      debugPrint(
          '📊 Video size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');

      // Validate duration and get video dimensions
      final videoController = VideoPlayerController.file(file);
      await videoController.initialize();

      final duration = videoController.value.duration.inSeconds;
      final width = videoController.value.size.width.toInt();
      final height = videoController.value.size.height.toInt();

      debugPrint('⏱️ Video duration: ${duration}s');
      debugPrint('📐 Video dimensions: ${width}x${height}');

      // Dispose controller
      await videoController.dispose();

      // Validate duration (10 seconds max)
      if (duration > 10) {
        throw Exception(
            'Video is too long. Maximum duration is 10 seconds (${duration}s)');
      }

      // Generate thumbnail
      debugPrint('🖼️ Generating thumbnail...');
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 640, // Match backend expectations
        quality: 85,
      );

      if (thumbnailData == null) {
        throw Exception('Failed to generate video thumbnail');
      }

      debugPrint(
          '✅ Thumbnail generated (${(thumbnailData.length / 1024).toStringAsFixed(2)} KB)');

      // Save thumbnail to temporary file
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = path.join(tempDir.path,
          'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(thumbnailData);

      // Create multipart request
      final uri = Uri.parse('$baseUrl/attachments/video/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      request.headers['Authorization'] = 'Bearer $token';

      // Add video file
      final videoMultipartFile = await http.MultipartFile.fromPath(
        'video',
        file.path,
        contentType: MediaType('video', _getVideoExtension(file.path)),
      );
      request.files.add(videoMultipartFile);

      // Add thumbnail file
      final thumbnailMultipartFile = await http.MultipartFile.fromPath(
        'thumbnail',
        thumbnailPath,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(thumbnailMultipartFile);

      // Add metadata fields
      request.fields['conversationId'] = conversationId;
      request.fields['duration'] = duration.toString();
      request.fields['width'] = width.toString();
      request.fields['height'] = height.toString();

      debugPrint('📤 Uploading video and thumbnail...');

      // Send request
      final streamedResponse = await request.send();

      // Track upload progress
      if (onProgress != null) {
        var received = 0;
        final total = fileSize;

        streamedResponse.stream.listen(
          (chunk) {
            received += chunk.length;
            onProgress(received / total);
          },
        );
      }

      // Get response
      final response = await http.Response.fromStream(streamedResponse);

      // Clean up temporary thumbnail file
      try {
        await thumbnailFile.delete();
      } catch (e) {
        debugPrint('⚠️ Failed to delete temp thumbnail: $e');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Video uploaded successfully');
        debugPrint('🎬 Video URL: ${data['video']['url']}');
        debugPrint('🖼️ Thumbnail URL: ${data['video']['thumbnailUrl']}');
        debugPrint(
            '🛡️ Moderation: ${data['moderation']['isSafe'] ? 'SAFE' : 'UNSAFE'}');

        return VideoUploadResult.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        final message = error['message'] ?? 'Video upload failed';
        debugPrint('❌ Upload failed: $message');
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('❌ Video upload error: $e');
      throw Exception('Failed to upload video: $e');
    }
  }

  /// Get video file extension
  String _getVideoExtension(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'mp4':
        return 'mp4';
      case 'mov':
        return 'quicktime';
      case 'avi':
        return 'x-msvideo';
      default:
        return 'mp4';
    }
  }
}

/// Result from image upload
class ImageUploadResult {
  final bool success;
  final String attachmentId;
  final ImageUrls urls;
  final ImageMetadata metadata;
  final ModerationResult moderation;

  ImageUploadResult({
    required this.success,
    required this.attachmentId,
    required this.urls,
    required this.metadata,
    required this.moderation,
  });

  factory ImageUploadResult.fromJson(Map<String, dynamic> json) {
    return ImageUploadResult(
      success: json['success'] ?? false,
      attachmentId: json['attachmentId'] ?? '',
      urls: ImageUrls.fromJson(json['urls'] ?? {}),
      metadata: ImageMetadata.fromJson(json['metadata'] ?? {}),
      moderation: ModerationResult.fromJson(json['moderation'] ?? {}),
    );
  }

  /// Convert to MessageAttachment for backward compatibility
  MessageAttachment toMessageAttachment() {
    return MessageAttachment(
      type: 'image',
      url: urls.full, // Use full resolution for Meta API
      thumbnailUrl: urls.thumbnail,
      filename: 'image_$attachmentId.webp',
      size: metadata.compressedSize,
      mimeType: 'image/webp',
      metadata: {
        'attachmentId': attachmentId,
        'originalSize': metadata.originalSize,
        'width': metadata.originalWidth,
        'height': metadata.originalHeight,
        'variants': {
          'thumbnail': urls.thumbnail,
          'medium': urls.medium,
          'full': urls.full,
        },
      },
    );
  }
}

/// Image URLs for different sizes
class ImageUrls {
  final String thumbnail; // 150x150px for lists
  final String medium; // 800px width for chat bubbles
  final String full; // 1920px max for full view

  ImageUrls({
    required this.thumbnail,
    required this.medium,
    required this.full,
  });

  factory ImageUrls.fromJson(Map<String, dynamic> json) {
    return ImageUrls(
      thumbnail: json['thumbnail'] ?? '',
      medium: json['medium'] ?? '',
      full: json['full'] ?? '',
    );
  }
}

/// Image metadata
class ImageMetadata {
  final int originalSize;
  final int compressedSize;
  final int originalWidth;
  final int originalHeight;
  final String format;

  ImageMetadata({
    required this.originalSize,
    required this.compressedSize,
    required this.originalWidth,
    required this.originalHeight,
    required this.format,
  });

  factory ImageMetadata.fromJson(Map<String, dynamic> json) {
    return ImageMetadata(
      originalSize: json['originalSize'] ?? 0,
      compressedSize: json['compressedSize'] ?? 0,
      originalWidth: json['originalWidth'] ?? 0,
      originalHeight: json['originalHeight'] ?? 0,
      format: json['format'] ?? 'webp',
    );
  }

  /// Get compression ratio as percentage
  double get compressionRatio {
    if (originalSize == 0) return 0;
    return ((originalSize - compressedSize) / originalSize) * 100;
  }

  /// Get compression savings in KB
  double get savedKB {
    return (originalSize - compressedSize) / 1024;
  }
}

/// Content moderation result
class ModerationResult {
  final bool isSafe;
  final List<String> reasons;
  final Map<String, dynamic> scores;
  final String? scannedAt;

  ModerationResult({
    required this.isSafe,
    required this.reasons,
    required this.scores,
    this.scannedAt,
  });

  factory ModerationResult.fromJson(Map<String, dynamic> json) {
    return ModerationResult(
      isSafe: json['isSafe'] ?? true,
      reasons: List<String>.from(json['reasons'] ?? []),
      scores: Map<String, dynamic>.from(json['scores'] ?? {}),
      scannedAt: json['scannedAt'],
    );
  }

  /// Get human-readable violation message
  String get violationMessage {
    if (isSafe) return 'Content is safe';

    final violations = reasons.map((reason) {
      switch (reason) {
        case 'adult_content':
          return 'Adult content detected';
        case 'violence':
          return 'Violence detected';
        case 'racy_content':
          return 'Racy content detected';
        case 'manipulated_image':
          return 'Manipulated image detected';
        default:
          return reason;
      }
    }).join(', ');

    return 'Content policy violation: $violations';
  }
}

/// Result from document upload
class DocumentUploadResult {
  final bool success;
  final String documentId;
  final String url;
  final DocumentMetadata metadata;

  DocumentUploadResult({
    required this.success,
    required this.documentId,
    required this.url,
    required this.metadata,
  });

  factory DocumentUploadResult.fromJson(Map<String, dynamic> json) {
    return DocumentUploadResult(
      success: json['success'] ?? false,
      documentId: json['documentId'] ?? '',
      url: json['url'] ?? '',
      metadata: DocumentMetadata.fromJson(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'documentId': documentId,
      'url': url,
      'metadata': metadata.toJson(),
    };
  }
}

/// Document metadata
class DocumentMetadata {
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String extension;
  final int? pages;
  final bool? isEncrypted;

  DocumentMetadata({
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.extension,
    this.pages,
    this.isEncrypted,
  });

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    return DocumentMetadata(
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      mimeType: json['mimeType'] ?? '',
      extension: json['extension'] ?? '',
      pages: json['pages'],
      isEncrypted: json['isEncrypted'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'extension': extension,
      if (pages != null) 'pages': pages,
      if (isEncrypted != null) 'isEncrypted': isEncrypted,
    };
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024)
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Result from video upload
class VideoUploadResult {
  final bool success;
  final VideoData video;
  final ModerationResult moderation;

  VideoUploadResult({
    required this.success,
    required this.video,
    required this.moderation,
  });

  factory VideoUploadResult.fromJson(Map<String, dynamic> json) {
    return VideoUploadResult(
      success: json['success'] ?? false,
      video: VideoData.fromJson(json['video'] ?? {}),
      moderation: ModerationResult.fromJson(json['moderation'] ?? {}),
    );
  }

  /// Convert to MessageAttachment
  MessageAttachment toMessageAttachment() {
    return MessageAttachment(
      type: 'video',
      url: video.url,
      thumbnailUrl: video.thumbnailUrl,
      filename:
          'video_${DateTime.now().millisecondsSinceEpoch}.${video.metadata.format}',
      size: video.metadata.size,
      mimeType: 'video/${video.metadata.format}',
      metadata: {
        'duration': video.metadata.duration,
        'width': video.metadata.width,
        'height': video.metadata.height,
        'format': video.metadata.format,
      },
    );
  }
}

/// Video data
class VideoData {
  final String url;
  final String thumbnailUrl;
  final VideoMetadata metadata;

  VideoData({
    required this.url,
    required this.thumbnailUrl,
    required this.metadata,
  });

  factory VideoData.fromJson(Map<String, dynamic> json) {
    return VideoData(
      url: json['url'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      metadata: VideoMetadata.fromJson(json['metadata'] ?? {}),
    );
  }
}

/// Video metadata
class VideoMetadata {
  final int duration; // seconds
  final int width;
  final int height;
  final int size; // bytes
  final String format;

  VideoMetadata({
    required this.duration,
    required this.width,
    required this.height,
    required this.size,
    required this.format,
  });

  factory VideoMetadata.fromJson(Map<String, dynamic> json) {
    return VideoMetadata(
      duration: json['duration'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      size: json['size'] ?? 0,
      format: json['format'] ?? 'mp4',
    );
  }

  String get formattedDuration {
    if (duration < 60) return '0:${duration.toString().padLeft(2, '0')}';
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

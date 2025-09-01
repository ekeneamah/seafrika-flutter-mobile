import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:vendor_app/models/media.dart';
import 'package:vendor_app/services/firestore_service.dart';
import 'package:path/path.dart' as path;

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

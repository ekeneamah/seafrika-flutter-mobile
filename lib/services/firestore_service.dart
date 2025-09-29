import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vendor_app/config/collection_names.dart';
import '../models/user.dart' as app_user;

class FirestoreService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // Collection references
  CollectionReference get usersCollection =>
      _firestore.collection(CollectionNames.users);
  CollectionReference get vendorsCollection =>
      _firestore.collection('vendors'); // Keep legacy vendor collection
  CollectionReference get productsCollection =>
      _firestore.collection(CollectionNames.products);
  CollectionReference get mediaCollection =>
      _firestore.collection(CollectionNames.media);
  CollectionReference collection(String path) {
    return _firestore.collection(path);
  }

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Generic CRUD operations
  Future<DocumentSnapshot> getDocument(String collection, String id) async {
    try {
      return await _firestore.collection(collection).doc(id).get();
    } catch (e) {
      debugPrint('Error getting document: $e');
      rethrow;
    }
  }

  Future<QuerySnapshot> getCollection(
    String collection, {
    Query<Object?> Function(Query<Object?> query)? queryBuilder,
  }) async {
    try {
      Query query = _firestore.collection(collection);
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      return await query.get();
    } catch (e) {
      debugPrint('Error getting collection: $e');
      rethrow;
    }
  }

  Future<DocumentReference> addDocument(
      String collection, Map<String, dynamic> data) async {
    try {
      return await _firestore.collection(collection).add(data);
    } catch (e) {
      debugPrint('Error adding document: $e');
      rethrow;
    }
  }

  Future<void> updateDocument(
      String collection, String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(id).update(data);
    } catch (e) {
      debugPrint('Error updating document: $e');
      rethrow;
    }
  }

  Future<void> deleteDocument(String collection, String id) async {
    try {
      await _firestore.collection(collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }

  // Batch operations
  Future<void> batchWrite(List<BatchOperation> operations) async {
    try {
      final batch = _firestore.batch();

      for (final operation in operations) {
        final docRef =
            _firestore.collection(operation.collection).doc(operation.id);

        switch (operation.type) {
          case BatchOperationType.create:
            batch.set(docRef, operation.data!);
            break;
          case BatchOperationType.update:
            batch.update(docRef, operation.data!);
            break;
          case BatchOperationType.delete:
            batch.delete(docRef);
            break;
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error in batch write: $e');
      rethrow;
    }
  }

  // Real-time listeners
  Stream<QuerySnapshot> streamCollection(
    String collection, {
    Query<Object?> Function(Query<Object?> query)? queryBuilder,
  }) {
    Query query = _firestore.collection(collection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return query.snapshots();
  }

  Stream<DocumentSnapshot> streamDocument(String collection, String id) {
    return _firestore.collection(collection).doc(id).snapshots();
  }

  // Get a user by ID
  Future<app_user.User> getUser(String userId) async {
    final userDoc = await usersCollection.doc(userId).get();
    return app_user.User.fromFirestore(userDoc);
  }
}

enum BatchOperationType { create, update, delete }

class BatchOperation {
  final String collection;
  final String id;
  final BatchOperationType type;
  final Map<String, dynamic>? data;

  BatchOperation({
    required this.collection,
    required this.id,
    required this.type,
    this.data,
  });
}

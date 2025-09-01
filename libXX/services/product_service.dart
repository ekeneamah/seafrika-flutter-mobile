import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vendor_app/models/product.dart';
import 'package:vendor_app/services/firestore_service.dart';
import 'package:vendor_app/models/product_listing.dart';

class ProductService extends ChangeNotifier {
  final FirestoreService _firestore;
  List<Product> _products = [];
  bool _isLoading = false;

  ProductService({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.getCollection(
        'products',
        queryBuilder: (query) => query
            .where('vendorId', isEqualTo: _firestore.currentUserId)
            .orderBy('createdAt', descending: true),
      );

      _products = snapshot.docs
          .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Fetch products error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Product?> getProduct(String id) async {
    try {
      final doc = await _firestore.getDocument('products', id);
      return Product.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Get product error: $e');
      return null;
    }
  }

  Future<String?> createProduct(Product product) async {
    try {
      final vendorId = _firestore.currentUserId;
      if (vendorId == null || vendorId.isEmpty) {
        throw Exception(
            'Cannot create product: vendorId is missing. Please log in again.');
      }
      final productData = product.toJson();
      productData['vendorId'] = vendorId;
      productData.remove('id');
      productData['createdAt'] = FieldValue.serverTimestamp();
      productData['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _firestore.addDocument('products', productData);

      await _firestore.updateDocument('products', docRef.id, {'id': docRef.id});

      final newProduct = product.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _products.add(newProduct);
      notifyListeners();
      return docRef.id;
    } catch (e) {
      debugPrint('Create product error: $e');
      return null;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      final productData = product.toJson();
      productData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.updateDocument('products', product.id, productData);
      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Update product error: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _firestore.deleteDocument('products', id);
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete product error: $e');
      return false;
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      final searchEnd = '$query\uf8ff';
      final snapshot = await _firestore.getCollection(
        'products',
        queryBuilder: (query) => query
            .where('vendorId', isEqualTo: _firestore.currentUserId)
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: searchEnd)
            .orderBy('name')
            .limit(20),
      );

      return snapshot.docs
          .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Search products error: $e');
      return [];
    }
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final snapshot = await _firestore.getCollection(
        'products',
        queryBuilder: (query) => query
            .where('vendorId', isEqualTo: _firestore.currentUserId)
            .where('category', isEqualTo: category)
            .orderBy('createdAt', descending: true),
      );

      return snapshot.docs
          .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get products by category error: $e');
      return [];
    }
  }

  // Real-time listeners
  Stream<List<Product>> streamProducts() {
    return _firestore
        .streamCollection(
          'products',
          queryBuilder: (query) => query
              .where('vendorId', isEqualTo: _firestore.currentUserId)
              .orderBy('createdAt', descending: true),
        )
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<Product?> streamProduct(String id) {
    return _firestore.streamDocument('products', id).map((doc) => doc.exists
        ? Product.fromJson(doc.data() as Map<String, dynamic>)
        : null);
  }

  Future<List<ExternalListing>> getExternalListings(String productId) async {
    try {
      final snapshot = await _firestore.getCollection(
        'vendors/${_firestore.currentUserId}/products/$productId/external_listings',
      );

      return snapshot.docs
          .map((doc) => ExternalListing.fromMap(
              {...(doc.data() as Map<String, dynamic>), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch external listings: $e');
    }
  }

  Future<void> updateExternalListing({
    required String productId,
    required String listingId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _firestore.updateDocument(
        'vendors/$_firestore.currentUserId/products/$productId/external_listings',
        listingId,
        {
          ...updates,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      );
    } catch (e) {
      throw Exception('Failed to update external listing: $e');
    }
  }

  Future<void> removeExternalListing({
    required String productId,
    required String listingId,
  }) async {
    try {
      await _firestore.deleteDocument(
        'vendors/$_firestore.currentUserId/products/$productId/external_listings',
        listingId,
      );
    } catch (e) {
      throw Exception('Failed to remove external listing: $e');
    }
  }

  Future<ProductAnalytics> getProductAnalytics(String productId) async {
    try {
      final doc = await _firestore.getDocument(
        'vendors/$_firestore.currentUserId/products/$productId/analytics',
        'current',
      );

      if (!doc.exists) {
        return ProductAnalytics(
          views: 0,
          favorites: 0,
          shares: 0,
          sales: 0,
          rating: 0.0,
          reviewCount: 0,
          viewsByDay: {},
          salesByDay: {},
        );
      }

      return ProductAnalytics.fromMap(doc.data()! as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch product analytics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTopReviews(String productId,
      {int limit = 2}) async {
    try {
      final snapshot = await _firestore.getCollection(
        'vendors/${_firestore.currentUserId}/products/${productId}/reviews',
        queryBuilder: (query) =>
            query.orderBy('rating', descending: true).limit(limit),
      );

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch top reviews: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTopComplaints(String productId,
      {int limit = 2}) async {
    try {
      final snapshot = await _firestore.getCollection(
        'vendors/${_firestore.currentUserId}/products/${productId}/complaints',
        queryBuilder: (query) =>
            query.orderBy('createdAt', descending: true).limit(limit),
      );

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch top complaints: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getProductTasks(String productId) async {
    try {
      final snapshot = await _firestore.getCollection(
        'vendors/${_firestore.currentUserId}/products/${productId}/tasks',
        queryBuilder: (query) => query.orderBy('dueDate'),
      );

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch product tasks: $e');
    }
  }
}

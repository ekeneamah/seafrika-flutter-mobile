import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vendor_app/models/product.dart';
import 'package:vendor_app/services/firestore_service.dart';
import 'package:vendor_app/services/business_inventory_service.dart';
import 'package:vendor_app/models/product_listing.dart';
import '../config/collection_references.dart';

class ProductService extends ChangeNotifier {
  final FirestoreService _firestore;
  List<Product> _products = [];
  bool _isLoading = false;

  ProductService({FirestoreService? firestore})
      : _firestore = firestore ?? FirestoreService();

  List<Product> get products => _products;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts({String? businessId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      Query query;
      
      if (businessId != null) {
        // Use business products query without status filter (Product model doesn't have status)
        query = CollectionReferences.productsForBusiness(businessId);
      } else {
        // Fallback to vendorId query for backward compatibility
        query = CollectionReferences.products
            .where('vendorId', isEqualTo: _firestore.currentUserId)
            .orderBy('createdAt', descending: true);
      }
      
      final snapshot = await query.get();
      
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
      final doc = await CollectionReferences.products.doc(id).get();
      if (!doc.exists) {
        debugPrint('Product with ID $id does not exist');
        return null;
      }
      final data = doc.data();
      if (data == null) {
        debugPrint('Product document data is null for ID $id');
        return null;
      }
      return Product.fromJson({...data, 'id': doc.id});
    } catch (e) {
      debugPrint('Get product error: $e');
      return null;
    }
  }

  /// Stream products for business (real-time updates)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamProductsForBusiness({
    String? businessId,
    String? searchQuery,
    String? category,
  }) {
    Query query;

    if (businessId != null) {
      if (searchQuery != null && searchQuery.isNotEmpty) {
        // Use centralized search reference
        query = CollectionReferences.searchProductsByName(businessId, searchQuery);
      } else if (category != null && category != 'All') {
        // Use centralized category reference
        query = CollectionReferences.productsForCategory(businessId, category);
      } else {
        // Use business products reference without status filter
        query = CollectionReferences.productsForBusiness(businessId)
            .orderBy('name');
      }
    } else {
      // Fallback to vendorId for backward compatibility
      query = CollectionReferences.products
          .where('vendorId', isEqualTo: _firestore.currentUserId)
          .orderBy('name');
    }

    return (query as Query<Map<String, dynamic>>).limit(50).snapshots();
  }

  /// Create a new product with business ID and add to business inventory
  Future<String?> createProduct(Product product, {
    required String businessId,
    int initialQuantity = 0,
    double costPrice = 0.0,
    double sellingPrice = 0.0,
  }) async {
    try {
      final vendorId = _firestore.currentUserId;
      if (vendorId == null || vendorId.isEmpty) {
        throw Exception(
            'Cannot create product: vendorId is missing. Please log in again.');
      }

      // Ensure product has businessId
      final updatedProduct = product.copyWith(
        vendorId: vendorId,
        businessId: businessId,
      );

      final productData = updatedProduct.toJson();
      productData.remove('id');
      productData['createdAt'] = FieldValue.serverTimestamp();
      productData['updatedAt'] = FieldValue.serverTimestamp();
      productData['status'] = 'active'; // Add status field for compatibility with queries

      // Create product in products collection using centralized reference
      final docRef = CollectionReferences.products.doc();
      final productDataWithId = {...productData, 'id': docRef.id};
      await docRef.set(productDataWithId);

      // If initial quantity is provided, create business inventory entry
      if (initialQuantity > 0) {
        final businessInventoryService = BusinessInventoryService();
        await businessInventoryService.createBusinessInventory(
          businessId: businessId,
          productId: docRef.id,
          productName: product.name,
          category: product.category,
          totalQuantity: initialQuantity,
          costPrice: costPrice,
          sellingPrice: sellingPrice > 0 ? sellingPrice : product.price,
          supplierId: null, // Optional supplier info
          purchaseOrderId: null, // Optional PO info
          displayImageUrl: product.displayImageUrl, // Add product image URL
        );
      }

      final newProduct = updatedProduct.copyWith(
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
      productData['status'] = 'active';

      await CollectionReferences.products.doc(product.id).update(productData);
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
      await CollectionReferences.products.doc(id).delete();
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
      final snapshot = await CollectionReferences.products
          .where('vendorId', isEqualTo: _firestore.currentUserId)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: searchEnd)
          .orderBy('name')
          .limit(20)
          .get();

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
      final snapshot = await CollectionReferences.products
          .where('vendorId', isEqualTo: _firestore.currentUserId)
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get products by category error: $e');
      return [];
    }
  }

  /// Fetch products with stock level filters to reduce read costs
  Future<List<Product>> getProductsByStockLevel({
    required String businessId,
    required String stockLevel, // 'inStock', 'lowStock', 'outOfStock'
    int limit = 20,
  }) async {
    try {
      Query query = CollectionReferences.productsForBusiness(businessId);
      
      switch (stockLevel) {
        case 'inStock':
          query = query.where('stock', isGreaterThan: 10);
          break;
        case 'lowStock':
          query = query
              .where('stock', isGreaterThan: 0)
              .where('stock', isLessThanOrEqualTo: 10);
          break;
        case 'outOfStock':
          query = query.where('stock', isEqualTo: 0);
          break;
      }

      query = query.orderBy('stock', descending: true).limit(limit);
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get products by stock level error: $e');
      return [];
    }
  }

  /// Search products with pagination to reduce read costs
  Future<List<Product>> searchProductsPaginated({
    required String businessId,
    required String query,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final searchEnd = '$query\uf8ff';
      Query firestoreQuery = CollectionReferences.productsForBusiness(businessId)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: searchEnd)
          .orderBy('name')
          .limit(limit);

      if (lastDocument != null) {
        firestoreQuery = firestoreQuery.startAfterDocument(lastDocument);
      }

      final snapshot = await firestoreQuery.get();
      return snapshot.docs
          .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Search products paginated error: $e');
      return [];
    }
  }

  // Real-time listeners
  Stream<List<Product>> streamProducts() {
    return CollectionReferences.products
        .where('vendorId', isEqualTo: _firestore.currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Product.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<Product?> streamProduct(String id) {
    return CollectionReferences.products.doc(id).snapshots().map((doc) => doc.exists
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

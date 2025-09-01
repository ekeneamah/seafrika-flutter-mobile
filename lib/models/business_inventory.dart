import 'package:cloud_firestore/cloud_firestore.dart';

/// Store distribution details for business inventory
class StoreDistribution {
  final String storeId;
  final String storeName;
  final int allocatedQuantity;
  final DateTime lastAllocated;

  StoreDistribution({
    required this.storeId,
    required this.storeName,
    required this.allocatedQuantity,
    required this.lastAllocated,
  });

  factory StoreDistribution.fromMap(Map<String, dynamic> data) {
    return StoreDistribution(
      storeId: data['storeId'] ?? '',
      storeName: data['storeName'] ?? '',
      allocatedQuantity: data['allocatedQuantity'] ?? 0,
      lastAllocated: (data['lastAllocated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'storeName': storeName,
      'allocatedQuantity': allocatedQuantity,
      'lastAllocated': Timestamp.fromDate(lastAllocated),
    };
  }
}

class BusinessInventory {
  final String id;
  final String businessId;
  final String productId;
  final String productName;
  final String category;
  final int totalQuantity;
  final int availableQuantity; // For store allocation tracking
  final double costPrice;
  final double sellingPrice;
  final double totalValue;
  final String? supplierId;
  final String? purchaseOrderId;
  final String? invoiceId;
  final Map<String, dynamic>? purchaseDetails;
  final String? displayImageUrl;
  final String? notes;
  final Map<String, StoreDistribution>? storeDistribution; // Store allocation details
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;

  BusinessInventory({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalQuantity,
    required this.availableQuantity,
    required this.costPrice,
    required this.sellingPrice,
    required this.totalValue,
    this.supplierId,
    this.purchaseOrderId,
    this.invoiceId,
    this.purchaseDetails,
    this.displayImageUrl,
    this.notes,
    this.storeDistribution,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  factory BusinessInventory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    
    // Parse store distribution
    Map<String, StoreDistribution>? storeDistribution;
    if (data['storeDistribution'] != null) {
      final storeData = data['storeDistribution'] as Map<String, dynamic>;
      storeDistribution = storeData.map(
        (key, value) => MapEntry(
          key,
          StoreDistribution.fromMap(value as Map<String, dynamic>),
        ),
      );
    }
    
    return BusinessInventory(
      id: doc.id,
      businessId: data['businessId'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      category: data['category'] ?? 'Uncategorized',
      totalQuantity: data['totalQuantity'] ?? 0,
      availableQuantity: data['availableQuantity'] ?? 0,
      costPrice: (data['costPrice'] ?? 0).toDouble(),
      sellingPrice: (data['sellingPrice'] ?? 0).toDouble(),
      totalValue: (data['totalValue'] ?? 0).toDouble(),
      supplierId: data['supplierId'],
      purchaseOrderId: data['purchaseOrderId'],
      invoiceId: data['invoiceId'],
      purchaseDetails: data['purchaseDetails'],
      displayImageUrl: data['displayImageUrl'],
      notes: data['notes'],
      storeDistribution: storeDistribution,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    // Convert store distribution to map
    Map<String, dynamic>? storeDistributionMap;
    if (storeDistribution != null) {
      storeDistributionMap = storeDistribution!.map(
        (key, value) => MapEntry(key, value.toMap()),
      );
    }
    
    return {
      'businessId': businessId,
      'productId': productId,
      'productName': productName,
      'category': category,
      'totalQuantity': totalQuantity,
      'availableQuantity': availableQuantity,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'totalValue': totalValue,
      'supplierId': supplierId,
      'purchaseOrderId': purchaseOrderId,
      'invoiceId': invoiceId,
      'purchaseDetails': purchaseDetails,
      'displayImageUrl': displayImageUrl,
      'notes': notes,
      'storeDistribution': storeDistributionMap,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status,
    };
  }

  BusinessInventory copyWith({
    String? businessId,
    String? productId,
    String? productName,
    String? category,
    int? totalQuantity,
    int? availableQuantity,
    double? costPrice,
    double? sellingPrice,
    double? totalValue,
    String? supplierId,
    String? purchaseOrderId,
    String? invoiceId,
    Map<String, dynamic>? purchaseDetails,
    String? displayImageUrl,
    String? notes,
    Map<String, StoreDistribution>? storeDistribution,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return BusinessInventory(
      id: id,
      businessId: businessId ?? this.businessId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      totalValue: totalValue ?? this.totalValue,
      supplierId: supplierId ?? this.supplierId,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      invoiceId: invoiceId ?? this.invoiceId,
      purchaseDetails: purchaseDetails ?? this.purchaseDetails,
      displayImageUrl: displayImageUrl ?? this.displayImageUrl,
      notes: notes ?? this.notes,
      storeDistribution: storeDistribution ?? this.storeDistribution,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  bool get isLowStock => availableQuantity <= 10; // Configurable threshold
  bool get isOutOfStock => availableQuantity <= 0;
  
  /// Get total quantity allocated to stores
  int get totalAllocatedQuantity {
    if (storeDistribution == null) return 0;
    return storeDistribution!.values
        .fold(0, (sum, distribution) => sum + distribution.allocatedQuantity);
  }
  
  /// Get number of stores this item is distributed to
  int get numberOfStores => storeDistribution?.length ?? 0;
  
  /// Get list of store names where this item is available
  List<String> get storeNames {
    if (storeDistribution == null) return [];
    return storeDistribution!.values
        .map((distribution) => distribution.storeName)
        .toList();
  }
  
  /// Check if item is available in a specific store
  bool isAvailableInStore(String storeId) {
    return storeDistribution?.containsKey(storeId) ?? false;
  }
  
  /// Get quantity in a specific store
  int getQuantityInStore(String storeId) {
    return storeDistribution?[storeId]?.allocatedQuantity ?? 0;
  }
}

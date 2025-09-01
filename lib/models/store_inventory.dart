import 'package:cloud_firestore/cloud_firestore.dart';

class StoreInventory {
  final String id;
  final String businessId;
  final String businessName; // Denormalized for efficient queries
  final String vendorId;     // Owner/Vendor ID
  final String storeId;
  final String productId;
  final String? inventoryId; // Deprecated, keeping for backward compatibility
  final String? businessInventoryId; // Link to business inventory
  final String productName;
  final int quantity;
  final int minimumQuantity;
  final double unitPrice;
  final String? location;
  final String? notes;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? displayImageUrl;
  
  // Pre-computed fields to avoid client-side calculations
  final bool isLowStock;
  final double totalValue;
  final String status; // active, inactive, outOfStock

  StoreInventory({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.vendorId,
    required this.storeId,
    required this.productId,
    this.inventoryId, // Deprecated
    this.businessInventoryId, // New field
    required this.productName,
    required this.quantity,
    required this.minimumQuantity,
    required this.unitPrice,
    this.location,
    this.notes,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.displayImageUrl,
    required this.isLowStock,
    required this.totalValue,
    required this.status,
  });

  factory StoreInventory.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return StoreInventory(
      id: doc.id,
      storeId: data['storeId'] as String,
      productId: data['productId'] as String,
      inventoryId: data['inventoryId'] as String?, // Nullable for backward compatibility
      businessInventoryId: data['businessInventoryId'] as String?, // New field
      productName: data['productName'] as String,
      quantity: data['quantity'] as int,
      minimumQuantity: data['minimumQuantity'] as int,
      unitPrice: (data['unitPrice'] as num).toDouble(),
      location: data['location'] as String?,
      notes: data['notes'] as String?,
      category: data['category'] as String? ?? 'Uncategorized',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      displayImageUrl: data['displayImageUrl'] as String?,
      isLowStock: data['isLowStock'] as bool? ?? false,
      totalValue: (data['totalValue'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'active',
      businessId: data['businessId'] as String,
      businessName: data['businessName'] as String,
      vendorId: data['vendorId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'productId': productId,
      'inventoryId': inventoryId, // Deprecated field for backward compatibility
      'businessInventoryId': businessInventoryId, // New field
      'productName': productName,
      'quantity': quantity,
      'minimumQuantity': minimumQuantity,
      'unitPrice': unitPrice,
      'location': location,
      'notes': notes,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'displayImageUrl': displayImageUrl,
      'isLowStock': isLowStock,
      'totalValue': totalValue,
      'status': status,
      'businessId': businessId,
      'businessName': businessName,
      'vendorId': vendorId,
    };
  }

  StoreInventory copyWith({
    String? id,
    String? storeId,
    String? productId,
    String? inventoryId,
    String? businessInventoryId,
    String? productName,
    int? quantity,
    int? minimumQuantity,
    double? unitPrice,
    String? location,
    String? notes,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? displayImageUrl,
    bool? isLowStock,
    double? totalValue,
    String? status,
    String? businessId,
    String? businessName,
    String? vendorId,
  }) {
    return StoreInventory(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      productId: productId ?? this.productId,
      inventoryId: inventoryId ?? this.inventoryId,
      businessInventoryId: businessInventoryId ?? this.businessInventoryId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      minimumQuantity: minimumQuantity ?? this.minimumQuantity,
      unitPrice: unitPrice ?? this.unitPrice,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      displayImageUrl: displayImageUrl ?? this.displayImageUrl,
      isLowStock: isLowStock ?? this.isLowStock,
      totalValue: totalValue ?? this.totalValue,
      status: status ?? this.status,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      vendorId: vendorId ?? this.vendorId,
    );
  }
}

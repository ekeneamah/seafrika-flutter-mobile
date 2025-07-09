import 'package:cloud_firestore/cloud_firestore.dart';

class StoreInventory {
  final String id;
  final String storeId;
  final String productId;
  final String inventoryId;
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

  StoreInventory({
    required this.id,
    required this.storeId,
    required this.productId,
    required this.inventoryId,
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
  });

  factory StoreInventory.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return StoreInventory(
      id: doc.id,
      storeId: data['storeId'] as String,
      productId: data['productId'] as String,
      inventoryId: data['inventoryId'] as String,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'productId': productId,
      'inventoryId': inventoryId,
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
    };
  }

  StoreInventory copyWith({
    String? id,
    String? storeId,
    String? productId,
    String? inventoryId,
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
  }) {
    return StoreInventory(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      productId: productId ?? this.productId,
      inventoryId: inventoryId ?? this.inventoryId,
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
    );
  }
}

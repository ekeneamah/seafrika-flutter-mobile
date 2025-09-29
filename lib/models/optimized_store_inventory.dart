import 'package:cloud_firestore/cloud_firestore.dart';

/// Optimized for Firestore read cost efficiency
/// Denormalizes frequently accessed product data to minimize reads
class OptimizedStoreInventory {
  final String id;
  final String businessId;
  final String storeId;

  // Product Reference (minimal reads)
  final String productId;

  // Denormalized Product Data (avoid product collection reads)
  final String productName;
  final String? productImage;
  final String category;
  final String? productDescription; // Short version only

  // Stock Information (single read gets all stock data)
  final StockLevels stock;
  final StockThresholds thresholds;

  // Pricing (denormalized for quick access)
  final PricingInfo pricing;

  // Location (single field for efficiency)
  final String location; // "Aisle-3/Shelf-B/Bin-12"

  // Batch Info (optional, only when relevant)
  final BatchInfo? batch;

  // Status & Metadata
  final InventoryStatus status;
  final DateTime lastUpdated;

  // Computed Fields (to avoid calculations on read)
  final bool isLowStock;
  final double totalValue;
  final int daysUntilReorder;

  OptimizedStoreInventory({
    required this.id,
    required this.businessId,
    required this.storeId,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.category,
    this.productDescription,
    required this.stock,
    required this.thresholds,
    required this.pricing,
    required this.location,
    this.batch,
    required this.status,
    required this.lastUpdated,
    required this.isLowStock,
    required this.totalValue,
    required this.daysUntilReorder,
  });

  factory OptimizedStoreInventory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;

    return OptimizedStoreInventory(
      id: doc.id,
      businessId: data['businessId'] as String,
      storeId: data['storeId'] as String,
      productId: data['productId'] as String,
      productName: data['productName'] as String,
      productImage: data['productImage'] as String?,
      category: data['category'] as String,
      productDescription: data['productDescription'] as String?,
      stock: StockLevels.fromMap(data['stock'] as Map<String, dynamic>),
      thresholds:
          StockThresholds.fromMap(data['thresholds'] as Map<String, dynamic>),
      pricing: PricingInfo.fromMap(data['pricing'] as Map<String, dynamic>),
      location: data['location'] as String,
      batch: data['batch'] != null
          ? BatchInfo.fromMap(data['batch'] as Map<String, dynamic>)
          : null,
      status: InventoryStatus.values.byName(data['status'] as String),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
      isLowStock: data['isLowStock'] as bool,
      totalValue: (data['totalValue'] as num).toDouble(),
      daysUntilReorder: data['daysUntilReorder'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'storeId': storeId,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'category': category,
      'productDescription': productDescription,
      'stock': stock.toMap(),
      'thresholds': thresholds.toMap(),
      'pricing': pricing.toMap(),
      'location': location,
      'batch': batch?.toMap(),
      'status': status.name,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'isLowStock': isLowStock,
      'totalValue': totalValue,
      'daysUntilReorder': daysUntilReorder,
    };
  }
}

/// Nested in single document to minimize reads
class StockLevels {
  final int current;
  final int reserved;
  final int available; // current - reserved
  final int damaged;

  StockLevels({
    required this.current,
    required this.reserved,
    required this.available,
    this.damaged = 0,
  });

  factory StockLevels.fromMap(Map<String, dynamic> map) {
    return StockLevels(
      current: map['current'] as int,
      reserved: map['reserved'] as int,
      available: map['available'] as int,
      damaged: map['damaged'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'current': current,
      'reserved': reserved,
      'available': available,
      'damaged': damaged,
    };
  }
}

class StockThresholds {
  final int minimum;
  final int maximum;
  final int reorderLevel;
  final int reorderQuantity;

  StockThresholds({
    required this.minimum,
    required this.maximum,
    required this.reorderLevel,
    required this.reorderQuantity,
  });

  factory StockThresholds.fromMap(Map<String, dynamic> map) {
    return StockThresholds(
      minimum: map['minimum'] as int,
      maximum: map['maximum'] as int,
      reorderLevel: map['reorderLevel'] as int,
      reorderQuantity: map['reorderQuantity'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minimum': minimum,
      'maximum': maximum,
      'reorderLevel': reorderLevel,
      'reorderQuantity': reorderQuantity,
    };
  }
}

class PricingInfo {
  final double costPrice;
  final double sellingPrice;
  final double? discountPrice;
  final int maxDiscountPercent;

  PricingInfo({
    required this.costPrice,
    required this.sellingPrice,
    this.discountPrice,
    required this.maxDiscountPercent,
  });

  factory PricingInfo.fromMap(Map<String, dynamic> map) {
    return PricingInfo(
      costPrice: (map['costPrice'] as num).toDouble(),
      sellingPrice: (map['sellingPrice'] as num).toDouble(),
      discountPrice: (map['discountPrice'] as num?)?.toDouble(),
      maxDiscountPercent: map['maxDiscountPercent'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'discountPrice': discountPrice,
      'maxDiscountPercent': maxDiscountPercent,
    };
  }
}

class BatchInfo {
  final String number;
  final DateTime? expiry;
  final DateTime received;

  BatchInfo({
    required this.number,
    this.expiry,
    required this.received,
  });

  factory BatchInfo.fromMap(Map<String, dynamic> map) {
    return BatchInfo(
      number: map['number'] as String,
      expiry:
          map['expiry'] != null ? (map['expiry'] as Timestamp).toDate() : null,
      received: (map['received'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'expiry': expiry != null ? Timestamp.fromDate(expiry!) : null,
      'received': Timestamp.fromDate(received),
    };
  }
}

enum InventoryStatus {
  active,
  lowStock,
  outOfStock,
  discontinued,
  damaged,
}

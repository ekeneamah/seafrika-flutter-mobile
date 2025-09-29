import 'package:cloud_firestore/cloud_firestore.dart';

class ExternalListing {
  final String id;
  final String storeId;
  final String storeName;
  final String storeIcon;
  final String productUrl;
  final DateTime createdAt;
  final DateTime? lastUpdated;
  final Map<String, dynamic> storeSpecificData;

  ExternalListing({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.storeIcon,
    required this.productUrl,
    required this.createdAt,
    this.lastUpdated,
    required this.storeSpecificData,
  });

  factory ExternalListing.fromMap(Map<String, dynamic> map) {
    return ExternalListing(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      storeName: map['storeName'] as String,
      storeIcon: map['storeIcon'] as String,
      productUrl: map['productUrl'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : null,
      storeSpecificData: map['storeSpecificData'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'storeName': storeName,
      'storeIcon': storeIcon,
      'productUrl': productUrl,
      'createdAt': createdAt,
      'lastUpdated': lastUpdated,
      'storeSpecificData': storeSpecificData,
    };
  }
}

class ProductAnalytics {
  final int views;
  final int favorites;
  final int shares;
  final int sales;
  final double rating;
  final int reviewCount;
  final Map<String, int> viewsByDay;
  final Map<String, int> salesByDay;

  ProductAnalytics({
    required this.views,
    required this.favorites,
    required this.shares,
    required this.sales,
    required this.rating,
    required this.reviewCount,
    required this.viewsByDay,
    required this.salesByDay,
  });

  factory ProductAnalytics.fromMap(Map<String, dynamic> map) {
    return ProductAnalytics(
      views: map['views'] as int,
      favorites: map['favorites'] as int,
      shares: map['shares'] as int,
      sales: map['sales'] as int,
      rating: (map['rating'] as num).toDouble(),
      reviewCount: map['reviewCount'] as int,
      viewsByDay: Map<String, int>.from(map['viewsByDay'] as Map),
      salesByDay: Map<String, int>.from(map['salesByDay'] as Map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'views': views,
      'favorites': favorites,
      'shares': shares,
      'sales': sales,
      'rating': rating,
      'reviewCount': reviewCount,
      'viewsByDay': viewsByDay,
      'salesByDay': salesByDay,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum ReviewType {
  review,
  complaint,
}

enum ReviewStatus {
  pending,
  responded,
  resolved,
  archived,
}

class Review {
  final String id;
  final String platformId;
  final String platformName;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final String content;
  final double rating;
  final ReviewType type;
  final ReviewStatus status;
  final String? response;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? productId;
  final String? productName;
  final Map<String, dynamic>? metadata;

  Review({
    required this.id,
    required this.platformId,
    required this.platformName,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    required this.content,
    required this.rating,
    required this.type,
    required this.status,
    this.response,
    required this.createdAt,
    this.respondedAt,
    this.productId,
    this.productName,
    this.metadata,
  });

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] as String,
      platformId: map['platformId'] as String,
      platformName: map['platformName'] as String,
      customerName: map['customerName'] as String,
      customerEmail: map['customerEmail'] as String,
      customerPhone: map['customerPhone'] as String?,
      content: map['content'] as String,
      rating: (map['rating'] as num).toDouble(),
      type: ReviewType.values.firstWhere(
        (e) => e.toString() == 'ReviewType.${map['type']}',
      ),
      status: ReviewStatus.values.firstWhere(
        (e) => e.toString() == 'ReviewStatus.${map['status']}',
      ),
      response: map['response'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      respondedAt: map['respondedAt'] != null
          ? (map['respondedAt'] as Timestamp).toDate()
          : null,
      productId: map['productId'] as String?,
      productName: map['productName'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'platformId': platformId,
      'platformName': platformName,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'content': content,
      'rating': rating,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'response': response,
      'createdAt': createdAt,
      'respondedAt': respondedAt,
      'productId': productId,
      'productName': productName,
      'metadata': metadata,
    };
  }

  Review copyWith({
    String? id,
    String? platformId,
    String? platformName,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? content,
    double? rating,
    ReviewType? type,
    ReviewStatus? status,
    String? response,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? productId,
    String? productName,
    Map<String, dynamic>? metadata,
  }) {
    return Review(
      id: id ?? this.id,
      platformId: platformId ?? this.platformId,
      platformName: platformName ?? this.platformName,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      content: content ?? this.content,
      rating: rating ?? this.rating,
      type: type ?? this.type,
      status: status ?? this.status,
      response: response ?? this.response,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ReviewPlatform {
  final String id;
  final String name;
  final String icon;
  final String status;
  final DateTime connectedAt;
  final Map<String, dynamic> credentials;
  final Map<String, dynamic>? settings;

  ReviewPlatform({
    required this.id,
    required this.name,
    required this.icon,
    required this.status,
    required this.connectedAt,
    required this.credentials,
    this.settings,
  });

  factory ReviewPlatform.fromMap(Map<String, dynamic> map) {
    return ReviewPlatform(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      status: map['status'] as String,
      connectedAt: (map['connectedAt'] as Timestamp).toDate(),
      credentials: map['credentials'] as Map<String, dynamic>,
      settings: map['settings'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'status': status,
      'connectedAt': connectedAt,
      'credentials': credentials,
      'settings': settings,
    };
  }
} 
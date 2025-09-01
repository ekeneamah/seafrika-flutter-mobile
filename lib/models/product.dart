import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> images;
  final int stock;
  final int minQuantity; // Minimum stock threshold for low stock alerts
  final double rating;
  final int reviews;
  final String category;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String vendorId;
  final String businessId; // Added for flat design
  final String? unit;
  final String? displayImageUrl;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    required this.stock,
    required this.minQuantity,
    required this.rating,
    required this.reviews,
    required this.category,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.vendorId,
    required this.businessId, // Added for flat design
    this.unit,
    this.displayImageUrl,
  });

  // Check if product is low stock
  bool get isLowStock => stock < minQuantity;

  factory Product.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.parse(value);
      throw Exception('Invalid date value');
    }

    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      images: List<String>.from(json['images'] as List),
      stock: json['stock'] as int,
      minQuantity: json['minQuantity'] as int? ?? 1, // Default to 1 if not provided
      rating: (json['rating'] as num).toDouble(),
      reviews: json['reviews'] as int,
      category: json['category'] as String,
      tags: List<String>.from(json['tags'] as List),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      vendorId: json['vendorId'] as String? ?? '',
      businessId: json['businessId'] as String? ?? '',
      unit: json['unit'] as String?,
      displayImageUrl: json['displayImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'images': images,
      'stock': stock,
      'minQuantity': minQuantity,
      'rating': rating,
      'reviews': reviews,
      'category': category,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'vendorId': vendorId,
      'businessId': businessId,
      'unit': unit,
      'displayImageUrl': displayImageUrl,
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    List<String>? images,
    int? stock,
    int? minQuantity,
    double? rating,
    int? reviews,
    String? category,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? vendorId,
    String? businessId,
    String? unit,
    String? displayImageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      images: images ?? this.images,
      stock: stock ?? this.stock,
      minQuantity: minQuantity ?? this.minQuantity,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vendorId: vendorId ?? this.vendorId,
      businessId: businessId ?? this.businessId,
      unit: unit ?? this.unit,
      displayImageUrl: displayImageUrl ?? this.displayImageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.price == price &&
        listEquals(other.images, images) &&
        other.stock == stock &&
        other.minQuantity == minQuantity &&
        other.rating == rating &&
        other.reviews == reviews &&
        other.category == category &&
        listEquals(other.tags, tags) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.vendorId == vendorId &&
        other.businessId == businessId &&
        other.unit == unit &&
        other.displayImageUrl == displayImageUrl;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      price,
      Object.hashAll(images),
      stock,
      minQuantity,
      rating,
      reviews,
      category,
      Object.hashAll(tags),
      createdAt,
      updatedAt,
      vendorId,
      businessId,
      unit,
      displayImageUrl,
    );
  }
}

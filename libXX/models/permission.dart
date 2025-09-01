import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum PermissionCategory {
  users,
  teams,
  inventory,
  suppliers,
  orders,
  reports,
  settings,
  admin,
  stores,
  auth,
  notifications,
  bookings,
  expenses,
  customers, analytics, product, user, order,
}

class Permission {
  final String id;
  final String name;
  final String description;
  final PermissionCategory category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;

  Permission({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.isActive,
    required this.createdAt,
    this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.toString().split('.').last,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
    };
  }

  factory Permission.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      if (value is Timestamp) return value.toDate();
      throw Exception('Invalid date type');
    }

    return Permission(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: PermissionCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => PermissionCategory.settings,
      ),
      isActive: map['isActive'] ?? true,
      createdAt: parseDate(map['createdAt']),
      lastUpdatedAt:
          map['lastUpdatedAt'] != null ? parseDate(map['lastUpdatedAt']) : null,
    );
  }
factory Permission.fromDoc(DocumentSnapshot doc) {
  final map = doc.data() as Map<String, dynamic>;
  return Permission.fromMap({
    ...map,
    'id': doc.id,
  });
}
  Permission copyWith({
    String? id,
    String? name,
    String? description,
    PermissionCategory? category,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) {
    return Permission(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Permission &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.category == category &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.lastUpdatedAt == lastUpdatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      category,
      isActive,
      createdAt,
      lastUpdatedAt,
    );
  }
}

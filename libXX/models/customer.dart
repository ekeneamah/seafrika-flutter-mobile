import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String vendorId;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? notes;
  final Map<String, dynamic> analytics;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.notes,
    required this.analytics,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'notes': notes,
      'analytics': analytics,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    return Customer(
      id: id,
      vendorId: map['vendorId'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      analytics: map['analytics'] as Map<String, dynamic>,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Customer copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? notes,
    Map<String, dynamic>? analytics,
  }) {
    return Customer(
      id: id,
      vendorId: vendorId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      analytics: analytics ?? this.analytics,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

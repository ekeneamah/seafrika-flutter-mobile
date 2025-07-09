import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/supplier_performance_metrics.dart';

class Supplier {
  final String id;
  final String vendorId;
  final String companyName;
  final String contactPerson;
  final String contactPhone;
  final String email;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final SupplierPerformanceMetrics performanceMetrics;

  Supplier({
    required this.id,
    required this.vendorId,
    required this.companyName,
    required this.contactPerson,
    required this.contactPhone,
    required this.email,
    this.address,
    this.notes,
    required this.createdAt,
    required this.performanceMetrics,
  });

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'companyName': companyName,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'email': email,
      'address': address,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'performanceMetrics': performanceMetrics.toMap(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] ?? '',
      vendorId: map['vendorId'] ?? '',
      companyName: map['companyName'] ?? '',
      contactPerson: map['contactPerson'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      performanceMetrics: SupplierPerformanceMetrics.fromMap(
        map['performanceMetrics'] ?? {},
      ),
    );
  }

  Supplier copyWith({
    String? id,
    String? vendorId,
    String? companyName,
    String? contactPerson,
    String? contactPhone,
    String? email,
    String? address,
    String? notes,
    DateTime? createdAt,
    SupplierPerformanceMetrics? performanceMetrics,
  }) {
    return Supplier(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      companyName: companyName ?? this.companyName,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      performanceMetrics: performanceMetrics ?? this.performanceMetrics,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  rent,
  utilities,
  supplies,
  marketing,
  payroll,
  maintenance,
  insurance,
  taxes,
  other,
}

enum ExpenseStatus {
  pending,
  approved,
  rejected,
}

class Expense {
  final String id;
  final String vendorId;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String description;
  final String? receiptUrl;
  final ExpenseStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final Map<String, dynamic>? metadata;

  Expense({
    required this.id,
    required this.vendorId,
    required this.amount,
    required this.category,
    required this.date,
    required this.description,
    this.receiptUrl,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.metadata,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      vendorId: map['vendorId'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.toString() == 'ExpenseCategory.${map['category']}',
      ),
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'] as String,
      receiptUrl: map['receiptUrl'] as String?,
      status: ExpenseStatus.values.firstWhere(
        (e) => e.toString() == 'ExpenseStatus.${map['status']}',
      ),
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      approvedBy: map['approvedBy'] as String?,
      approvedAt: map['approvedAt'] != null
          ? (map['approvedAt'] as Timestamp).toDate()
          : null,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'amount': amount,
      'category': category.toString().split('.').last,
      'date': date,
      'description': description,
      'receiptUrl': receiptUrl,
      'status': status.toString().split('.').last,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'metadata': metadata,
    };
  }

  Expense copyWith({
    String? id,
    String? vendorId,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    String? description,
    String? receiptUrl,
    ExpenseStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? approvedBy,
    DateTime? approvedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Expense(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

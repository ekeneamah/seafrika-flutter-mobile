import 'package:cloud_firestore/cloud_firestore.dart';

class BookingRequest {
  final String id;
  final String customerId;
  final String serviceId;
  final DateTime requestedDate;
  final String status;
  final String? notes;

  BookingRequest({
    required this.id,
    required this.customerId,
    required this.serviceId,
    required this.requestedDate,
    required this.status,
    this.notes,
  });

  factory BookingRequest.fromJson(Map<String, dynamic> json) {
    return BookingRequest(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      serviceId: json['serviceId'] as String,
      requestedDate: DateTime.parse(json['requestedDate'] as String),
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'serviceId': serviceId,
      'requestedDate': requestedDate.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }
}

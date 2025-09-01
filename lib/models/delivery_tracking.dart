import 'package:cloud_firestore/cloud_firestore.dart';

enum DeliveryStatus {
  pending,
  pickedUp,
  inTransit,
  outForDelivery,
  delivered,
  failed,
  returned,
  cancelled
}

enum DeliveryType {
  standard,
  express,
  overnight,
  scheduled,
  pickup
}

class DeliveryTracking {
  final String id;
  final String orderId;
  final String vendorId;
  final String? courierId;
  final String? courierName;
  final String? courierPhone;
  final String trackingNumber;
  final DeliveryStatus status;
  final DeliveryType type;
  final DateTime estimatedDelivery;
  final DateTime? actualDelivery;
  final String pickupAddress;
  final String deliveryAddress;
  final double? latitude;
  final double? longitude;
  final String? deliveryInstructions;
  final String? recipientName;
  final String? recipientPhone;
  final List<DeliveryUpdate> updates;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DeliveryTracking({
    required this.id,
    required this.orderId,
    required this.vendorId,
    this.courierId,
    this.courierName,
    this.courierPhone,
    required this.trackingNumber,
    required this.status,
    required this.type,
    required this.estimatedDelivery,
    this.actualDelivery,
    required this.pickupAddress,
    required this.deliveryAddress,
    this.latitude,
    this.longitude,
    this.deliveryInstructions,
    this.recipientName,
    this.recipientPhone,
    required this.updates,
    required this.createdAt,
    this.updatedAt,
  });

  factory DeliveryTracking.fromMap(Map<String, dynamic> map) {
    return DeliveryTracking(
      id: map['id'] as String,
      orderId: map['orderId'] as String,
      vendorId: map['vendorId'] as String,
      courierId: map['courierId'] as String?,
      courierName: map['courierName'] as String?,
      courierPhone: map['courierPhone'] as String?,
      trackingNumber: map['trackingNumber'] as String,
      status: DeliveryStatus.values.firstWhere(
        (e) => e.toString() == 'DeliveryStatus.${map['status']}',
      ),
      type: DeliveryType.values.firstWhere(
        (e) => e.toString() == 'DeliveryType.${map['type']}',
      ),
      estimatedDelivery: (map['estimatedDelivery'] as Timestamp).toDate(),
      actualDelivery: map['actualDelivery'] != null
          ? (map['actualDelivery'] as Timestamp).toDate()
          : null,
      pickupAddress: map['pickupAddress'] as String,
      deliveryAddress: map['deliveryAddress'] as String,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      deliveryInstructions: map['deliveryInstructions'] as String?,
      recipientName: map['recipientName'] as String?,
      recipientPhone: map['recipientPhone'] as String?,
      updates: (map['updates'] as List)
          .map((update) => DeliveryUpdate.fromMap(update as Map<String, dynamic>))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'vendorId': vendorId,
      'courierId': courierId,
      'courierName': courierName,
      'courierPhone': courierPhone,
      'trackingNumber': trackingNumber,
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'estimatedDelivery': Timestamp.fromDate(estimatedDelivery),
      'actualDelivery': actualDelivery != null ? Timestamp.fromDate(actualDelivery!) : null,
      'pickupAddress': pickupAddress,
      'deliveryAddress': deliveryAddress,
      'latitude': latitude,
      'longitude': longitude,
      'deliveryInstructions': deliveryInstructions,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'updates': updates.map((update) => update.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  DeliveryTracking copyWith({
    String? id,
    String? orderId,
    String? vendorId,
    String? courierId,
    String? courierName,
    String? courierPhone,
    String? trackingNumber,
    DeliveryStatus? status,
    DeliveryType? type,
    DateTime? estimatedDelivery,
    DateTime? actualDelivery,
    String? pickupAddress,
    String? deliveryAddress,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    String? recipientName,
    String? recipientPhone,
    List<DeliveryUpdate>? updates,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryTracking(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      vendorId: vendorId ?? this.vendorId,
      courierId: courierId ?? this.courierId,
      courierName: courierName ?? this.courierName,
      courierPhone: courierPhone ?? this.courierPhone,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      status: status ?? this.status,
      type: type ?? this.type,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      actualDelivery: actualDelivery ?? this.actualDelivery,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      updates: updates ?? this.updates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DeliveryUpdate {
  final String status;
  final String message;
  final String? location;
  final DateTime timestamp;
  final String? updatedBy;

  DeliveryUpdate({
    required this.status,
    required this.message,
    this.location,
    required this.timestamp,
    this.updatedBy,
  });

  factory DeliveryUpdate.fromMap(Map<String, dynamic> map) {
    return DeliveryUpdate(
      status: map['status'] as String,
      message: map['message'] as String,
      location: map['location'] as String?,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'message': message,
      'location': location,
      'timestamp': Timestamp.fromDate(timestamp),
      'updatedBy': updatedBy,
    };
  }
}

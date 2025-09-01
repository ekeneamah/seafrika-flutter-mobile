import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vendor_app/models/booking_request.dart';
import 'package:vendor_app/models/booking.dart';
import 'package:vendor_app/models/customer.dart';
import 'package:vendor_app/models/notification.dart' as notification;
import 'package:vendor_app/services/notification_service.dart';

class BookingService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  BookingService({
    required FirebaseFirestore firestore,
    required String vendorId,
    required NotificationService notificationService,
  })  : _firestore = firestore,
        _vendorId = vendorId,
        _notificationService = notificationService;

  Future<BookingRequest> createBookingRequest({
    required String customerId,
    required String serviceId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required DateTime requestedDate,
    required String serviceName,
    required double price,
    String? notes,
  }) async {
    try {
      final requestRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('booking_requests')
          .doc();

      final request = BookingRequest(
        id: requestRef.id,
        customerId: customerId,
        serviceId: serviceId,
        requestedDate: requestedDate,
        status: 'pending',
        notes: notes,
      );

      await requestRef.set(request.toJson());

      // Send notification to vendor
      await _sendBookingRequestNotification(request, customerName, serviceName);

      return request;
    } catch (e) {
      throw Exception('Failed to create booking request: $e');
    }
  }

  Future<void> _sendBookingRequestNotification(
    BookingRequest request,
    String customerName,
    String serviceName,
  ) async {
    try {
      // Get vendor's FCM token from Firestore
      final vendorDoc =
          await _firestore.collection('vendors').doc(_vendorId).get();
      final fcmToken = vendorDoc.data()?['fcmToken'];

      if (fcmToken != null) {
        // Send notification using Cloud Functions
        await _firestore.collection('notifications').add({
          'type': 'booking_request',
          'vendorId': _vendorId,
          'fcmToken': fcmToken,
          'title': 'New Booking Request',
          'body': '$customerName requested a booking for $serviceName',
          'data': {
            'bookingId': request.id,
            'type': 'booking_request',
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Failed to send booking request notification: $e');
      // Don't throw the error as notification failure shouldn't affect the booking request
    }
  }

  Future<Booking> createBooking({
    required String customerId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required DateTime bookingDate,
    required List<BookingItem> items,
    String? notes,
  }) async {
    final booking = Booking(
      id: '',
      vendorId: _vendorId,
      customerId: customerId,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      bookingDate: bookingDate,
      items: items,
      status: BookingStatus.pending,
      notes: notes,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore.collection('bookings').add(booking.toMap());
    final createdBooking = booking.copyWith(id: docRef.id);

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Booking',
      message: 'New booking from $customerName',
      type: notification.NotificationType.booking,
      priority: notification.NotificationPriority.medium,
      data: createdBooking.toMap(),
    );

    return createdBooking;
  }

  Stream<List<Booking>> streamBookings({
    String? customerId,
    BookingStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore
        .collection('bookings')
        .where('vendorId', isEqualTo: _vendorId);

    if (customerId != null) {
      query = query.where('customerId', isEqualTo: customerId);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.toString());
    }

    if (startDate != null) {
      query = query.where('bookingDate', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('bookingDate', isLessThanOrEqualTo: endDate);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Booking.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<Booking> fetchBooking(String bookingId) async {
    final doc = await _firestore.collection('bookings').doc(bookingId).get();
    if (!doc.exists) {
      throw Exception('Booking not found');
    }
    return Booking.fromMap(doc.data()!);
  }

  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    final booking = await fetchBooking(bookingId);
    if (booking.status == status) return;

    await _firestore.collection('bookings').doc(bookingId).update({
      'status': status.toString(),
    });

    // Send notification
    await _notificationService.sendNotification(
      title: 'Booking Status Updated',
      message: 'Booking status changed to ${status.toString()}',
      type: notification.NotificationType.booking,
      priority: notification.NotificationPriority.medium,
      data: booking.copyWith(status: status).toMap(),
    );
  }

  Future<void> cancelBooking(String bookingId) async {
    final booking = await fetchBooking(bookingId);
    if (booking.status == BookingStatus.cancelled) return;

    await _firestore.collection('bookings').doc(bookingId).update({
      'status': BookingStatus.cancelled.toString(),
    });

    // Send notification
    await _notificationService.sendNotification(
      title: 'Booking Cancelled',
      message: 'Booking from ${booking.customerName} has been cancelled',
      type: notification.NotificationType.booking,
      priority: notification.NotificationPriority.high,
      data: booking.copyWith(status: BookingStatus.cancelled).toMap(),
    );
  }

  Future<void> saveBookingDraft({
    required Customer? customer,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required DateTime date,
    required TimeOfDay time,
    required double price,
    String? notes,
  }) async {
    final bookingDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final request = BookingRequest(
      id: '',
      customerId: customer?.id ?? '',
      serviceId: '',
      requestedDate: bookingDate,
      status: 'draft',
      notes: notes,
    );

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('booking_drafts')
        .add(request.toJson());
  }

  Future<List<BookingRequest>> fetchBookingRequests() async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('booking_requests')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BookingRequest.fromJson({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch booking requests: $e');
    }
  }
}

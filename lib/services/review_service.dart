import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/review.dart';

class ReviewService {
  final FirebaseFirestore _firestore;
  final String _vendorId;

  ReviewService(this._firestore, this._vendorId);

  // Platform Management
  Future<List<ReviewPlatform>> fetchPlatforms() async {
    final snapshot = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('review_platforms')
        .get();

    return snapshot.docs
        .map((doc) => ReviewPlatform.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<ReviewPlatform> fetchPlatform(String platformId) async {
    final doc = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('review_platforms')
        .doc(platformId)
        .get();

    if (!doc.exists) {
      throw Exception('Platform not found');
    }

    return ReviewPlatform.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<ReviewPlatform> connectPlatform({
    required String name,
    required String icon,
    required Map<String, dynamic> credentials,
    Map<String, dynamic>? settings,
  }) async {
    final docRef = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('review_platforms')
        .doc();

    final platform = ReviewPlatform(
      id: docRef.id,
      name: name,
      icon: icon,
      status: 'connected',
      connectedAt: DateTime.now(),
      credentials: credentials,
      settings: settings,
    );

    await docRef.set(platform.toMap());
    return platform;
  }

  Future<ReviewPlatform> updatePlatform({
    required String platformId,
    String? name,
    String? icon,
    Map<String, dynamic>? credentials,
    Map<String, dynamic>? settings,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (icon != null) updates['icon'] = icon;
    if (credentials != null) updates['credentials'] = credentials;
    if (settings != null) updates['settings'] = settings;

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('review_platforms')
        .doc(platformId)
        .update(updates);

    return fetchPlatform(platformId);
  }

  Future<void> disconnectPlatform(String platformId) async {
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('review_platforms')
        .doc(platformId)
        .delete();
  }

  Future<void> updatePlatformSettings(
    String platformId,
    Map<String, dynamic> settings,
  ) async {
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('review_platforms')
        .doc(platformId)
        .update({'settings': settings});
  }

  // Review Management
  Stream<List<Review>> streamReviews({
    String? platformId,
    ReviewType? type,
    ReviewStatus? status,
    String? productId,
  }) {
    Query query =
        _firestore.collection('vendors').doc(_vendorId).collection('reviews');

    if (platformId != null) {
      query = query.where('platformId', isEqualTo: platformId);
    }
    if (type != null) {
      query = query.where('type', isEqualTo: type.toString().split('.').last);
    }
    if (status != null) {
      query =
          query.where('status', isEqualTo: status.toString().split('.').last);
    }
    if (productId != null) {
      query = query.where('productId', isEqualTo: productId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Review.fromMap(
              {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    });
  }

  Future<Review> fetchReview(String reviewId) async {
    final doc = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('reviews')
        .doc(reviewId)
        .get();

    if (!doc.exists) {
      throw Exception('Review not found');
    }

    return Review.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<void> respondToReview(
    String reviewId, {
    required String response,
    ReviewStatus? newStatus,
  }) async {
    final updates = {
      'response': response,
      'respondedAt': DateTime.now(),
    };

    if (newStatus != null) {
      updates['status'] = newStatus.toString().split('.').last;
    }

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('reviews')
        .doc(reviewId)
        .update(updates);
  }

  Future<void> updateReviewStatus(String reviewId, ReviewStatus status) async {
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('reviews')
        .doc(reviewId)
        .update({
      'status': status.toString().split('.').last,
    });
  }

  Future<void> addReviewerToCRM(String reviewId) async {
    final review = await fetchReview(reviewId);

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('customers')
        .add({
      'name': review.customerName,
      'email': review.customerEmail,
      'phone': review.customerPhone,
      'source': 'review_platform',
      'sourceId': review.platformId,
      'createdAt': DateTime.now(),
    });
  }
}

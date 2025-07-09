import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String id;
  final String name;
  final double price;
  // Add other fields as needed

  Service({
    required this.id,
    required this.name,
    required this.price,
  });

  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
    );
  }
}

class ServiceService {
  final FirebaseFirestore _firestore;
  final String _vendorId;

  ServiceService({
    required FirebaseFirestore firestore,
    required String vendorId,
  })  : _firestore = firestore,
        _vendorId = vendorId;

  Future<Service> fetchService(String serviceId) async {
    final doc = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('services')
        .doc(serviceId)
        .get();

    if (!doc.exists) {
      throw Exception('Service not found');
    }

    return Service.fromMap({...doc.data()!, 'id': doc.id});
  }
}

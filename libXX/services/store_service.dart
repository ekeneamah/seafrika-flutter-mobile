import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/store.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart';
import 'package:vendor_app/services/firestore_service.dart';

class StoreService extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;
  List<Store> _stores = [];
  bool _isLoading = false;

  StoreService(this._firestore, this._vendorId, this._notificationService);

  List<Store> get stores => _stores;
  bool get isLoading => _isLoading;

  Future<void> fetchStores() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('stores')
          .where('vendorId', isEqualTo: _vendorId)
          .get();

      if (snapshot.docs.isEmpty) {
        _stores = [];
        return;
      }

      _stores = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Store.fromMap(data);
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      print('Error fetching stores: $e');
      _stores = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createStore({required Store store}) async {
    try {
      final docRef = await _firestore.collection('stores').add(store.toMap());
      final newStore = store.copyWith(id: docRef.id);
      _stores = [..._stores, newStore]
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();

      await _notificationService.sendNotification(
        title: 'New Store Added',
        message: 'Store ${store.name} has been added',
        type: NotificationType.system,
        priority: NotificationPriority.low,
        data: newStore.toMap(),
      );
    } catch (e) {
      print('Error creating store: $e');
      rethrow;
    }
  }

  Future<void> updateStore(Store store) async {
    try {
      await _firestore.collection('stores').doc(store.id).update(store.toMap());
      _stores = [
        for (final s in _stores)
          if (s.id == store.id) store else s
      ]..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    } catch (e) {
      print('Error updating store: $e');
      rethrow;
    }
  }

  Future<void> deleteStore(String storeId) async {
    try {
      await _firestore.collection('stores').doc(storeId).delete();
      _stores = _stores.where((s) => s.id != storeId).toList();
      notifyListeners();
    } catch (e) {
      print('Error deleting store: $e');
      rethrow;
    }
  }

  Future<void> pushInventoryToStore({
    required String storeId,
    required String inventoryId,
    required int quantity,
  }) async {
    final store = await fetchStore(storeId);
    final inventoryDoc =
        await _firestore.collection('inventory').doc(inventoryId).get();

    if (!inventoryDoc.exists) {
      throw Exception('Inventory item not found');
    }

    final inventoryData = inventoryDoc.data() as Map<String, dynamic>;
    if (inventoryData['quantity'] < quantity) {
      throw Exception('Insufficient inventory quantity');
    }

    // Create store inventory record
    await _firestore.collection('store_inventory').add({
      'storeId': storeId,
      'inventoryId': inventoryId,
      'quantity': quantity,
      'pushedAt': DateTime.now().toIso8601String(),
    });

    // Update main inventory quantity
    await _firestore.collection('inventory').doc(inventoryId).update({
      'quantity': (inventoryData['quantity'] as int) - quantity,
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    // Send notification
    await _notificationService.sendNotification(
      title: 'Inventory Pushed to Store',
      message: 'Pushed $quantity units to ${store.name}',
      type: NotificationType.system,
      priority: NotificationPriority.medium,
      data: {
        'storeId': storeId,
        'storeName': store.name,
        'inventoryId': inventoryId,
        'quantity': quantity,
      },
    );
  }

  Future<void> pullInventoryFromStore({
    required String storeId,
    required String inventoryId,
    required int quantity,
  }) async {
    final store = await fetchStore(storeId);
    final storeInventorySnapshot = await _firestore
        .collection('store_inventory')
        .where('storeId', isEqualTo: storeId)
        .where('inventoryId', isEqualTo: inventoryId)
        .get();

    if (storeInventorySnapshot.docs.isEmpty) {
      throw Exception('Inventory not found in store');
    }

    final storeInventoryData =
        storeInventorySnapshot.docs.first.data() as Map<String, dynamic>;
    if (storeInventoryData['quantity'] < quantity) {
      throw Exception('Insufficient store inventory quantity');
    }

    // Update store inventory quantity
    await _firestore
        .collection('store_inventory')
        .doc(storeInventorySnapshot.docs.first.id)
        .update({
      'quantity': (storeInventoryData['quantity'] as int) - quantity,
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    // Update main inventory quantity
    final inventoryDoc =
        await _firestore.collection('inventory').doc(inventoryId).get();
    final inventoryData = inventoryDoc.data() as Map<String, dynamic>;
    await _firestore.collection('inventory').doc(inventoryId).update({
      'quantity': (inventoryData['quantity'] as int) + quantity,
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    // Send notification
    await _notificationService.sendNotification(
      vendorId: _firestore.app.options.projectId ?? '',
      title: 'Inventory Pulled from Store',
      message: 'Pulled $quantity units from ${store.name}',
      type: NotificationType.system,
      priority: NotificationPriority.medium,
      data: {
        'storeId': storeId,
        'storeName': store.name,
        'inventoryId': inventoryId,
        'quantity': quantity,
      },
    );
  }

  Future<Store> fetchStore(String storeId) async {
    final doc = await _firestore.collection('stores').doc(storeId).get();
    if (!doc.exists) {
      throw Exception('Store not found');
    }
    final data = doc.data()!;
    data['id'] = doc.id;
    return Store.fromMap(data);
  }
}

final storeServiceProvider = ChangeNotifierProvider<StoreService>((ref) {
  final vendorId = ref.watch(vendorIdSyncProvider);
  return StoreService(
    ref.watch(firebaseFirestoreProvider),
    vendorId,
    ref.watch(notificationServiceProvider),
  );
});

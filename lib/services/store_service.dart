import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/collection_references.dart';
import 'package:vendor_app/models/store.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart';

class StoreService extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final String _ownerId;
  final String _businessId;
  final NotificationService _notificationService;
  List<Store> _stores = [];
  bool _isLoading = false;

  StoreService(this._firestore, this._ownerId, this._notificationService,
      this._businessId);

  List<Store> get stores => _stores;
  bool get isLoading => _isLoading;

  Future<void> fetchStores() async {
    if (_isLoading) return;

    // If no business is selected, set empty stores and exit loading
    if (_businessId.isEmpty) {
      _stores = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await CollectionReferences.storesForBusiness(_businessId)
          .get()
          .timeout(const Duration(seconds: 15));

      _stores = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Store.fromMap(data);
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    } catch (e, st) {
      debugPrint('Error fetching stores: $e\n$st');
      _stores = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createStore({required Store store}) async {
    try {
      assert(store.businessId == _businessId);
      assert(store.ownerId == _ownerId);
      final docRef = await CollectionReferences.stores.add(store.toMap());
      final newStore = store.copyWith(id: docRef.id);
      _stores = [..._stores, newStore]
        ..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();

      await _notificationService.sendNotification(
        title: 'New Store Added',
        message: 'Store ${newStore.name} has been added',
        type: NotificationType.system,
        priority: NotificationPriority.low,
        data: newStore.toMap(),
      );
    } catch (e, st) {
      debugPrint('Error creating store: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateStore(Store store) async {
    try {
      assert(store.businessId == _businessId);
      assert(store.ownerId == _ownerId);

      await CollectionReferences.stores.doc(store.id).update(store.toMap());
      _stores = [
        for (final s in _stores)
          if (s.id == store.id) store else s
      ]..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error updating store: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteStore(String storeId) async {
    try {
      await CollectionReferences.stores.doc(storeId).delete();
      _stores = _stores.where((s) => s.id != storeId).toList();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error deleting store: $e\n$st');
      rethrow;
    }
  }

  Future<void> pushInventoryToStore({
    required String storeId,
    required String inventoryId,
    required int quantity,
  }) async {
    final store = await fetchStore(storeId);

    // Fetch main inventory via CollectionReferences
    final inventoryDoc =
        await CollectionReferences.inventory.doc(inventoryId).get();

    if (!inventoryDoc.exists) {
      throw Exception('Inventory item not found');
    }
    final inventoryData = inventoryDoc.data()!;

    if (inventoryData['quantity'] < quantity) {
      throw Exception('Insufficient inventory quantity');
    }

    // Create a record in the store_inventory collection
    await _firestore.collection('store_inventory').add({
      'storeId': storeId,
      'inventoryId': inventoryId,
      'quantity': quantity,
      'pushedAt': DateTime.now().toIso8601String(),
    });

    // Decrement main inventory
    await CollectionReferences.inventory.doc(inventoryId).update({
      'quantity': (inventoryData['quantity'] as int) - quantity,
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    // Notify
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

    final storeInvSnap = await _firestore
        .collection('store_inventory')
        .where('storeId', isEqualTo: storeId)
        .where('inventoryId', isEqualTo: inventoryId)
        .get();

    if (storeInvSnap.docs.isEmpty) {
      throw Exception('Inventory not found in store');
    }
    final invRecord = storeInvSnap.docs.first;
    final storeInvData = invRecord.data();

    if (storeInvData['quantity'] < quantity) {
      throw Exception('Insufficient store inventory quantity');
    }

    // Decrement store inventory
    await _firestore.collection('store_inventory').doc(invRecord.id).update({
      'quantity': (storeInvData['quantity'] as int) - quantity,
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    // Increment main inventory
    final inventoryDoc =
        await CollectionReferences.inventory.doc(inventoryId).get();
    final inventoryData = inventoryDoc.data()!;
    await CollectionReferences.inventory.doc(inventoryId).update({
      'quantity': (inventoryData['quantity'] as int) + quantity,
      'lastUpdated': DateTime.now().toIso8601String(),
    });

    // Notify
    await _notificationService.sendNotification(
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
    final doc = await CollectionReferences.stores.doc(storeId).get();
    if (!doc.exists) {
      throw Exception('Store not found');
    }
    final data = doc.data()! as Map<String, dynamic>;
    data['id'] = doc.id;
    return Store.fromMap(data);
  }
}

final storeServiceProvider = ChangeNotifierProvider<StoreService>((ref) {
  final vendorId = ref.watch(vendorIdSyncProvider);
  final businessId = ref.watch(selectedBusinessIdProvider);

  // Return a service with empty businessId if none selected - this prevents crashes
  // and allows the UI to handle the "no business selected" state gracefully
  return StoreService(
    ref.watch(firebaseFirestoreProvider),
    vendorId,
    ref.watch(notificationServiceProvider),
    businessId ?? '', // Use empty string instead of null assertion
  );
});

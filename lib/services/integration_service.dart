import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/integration.dart';

class IntegrationService {
  final FirebaseFirestore _firestore;
  final String _vendorId;

  IntegrationService({
    required FirebaseFirestore firestore,
    required String vendorId,
  })  : _firestore = firestore,
        _vendorId = vendorId;

  Future<List<Integration>> fetchIntegrations() async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('integrations')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Integration.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch integrations: $e');
    }
  }

  Future<Integration> fetchIntegration(String integrationId) async {
    try {
      final doc = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('integrations')
          .doc(integrationId)
          .get();

      if (!doc.exists) {
        throw Exception('Integration not found');
      }

      return Integration.fromMap({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw Exception('Failed to fetch integration: $e');
    }
  }

  Future<Integration> connectPlatform({
    required String platformId,
    required Map<String, String> credentials,
  }) async {
    try {
      // Validate credentials with platform
      final isValid = await _validateCredentials(platformId, credentials);
      if (!isValid) {
        throw Exception('Invalid credentials');
      }

      // Get platform details
      final platform = await _getPlatformDetails(platformId);

      // Create integration document
      final docRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('integrations')
          .doc();

      final integration = Integration(
        id: docRef.id,
        platformId: platformId,
        platformName: platform['name'],
        platformIcon: platform['icon'],
        status: 'connected',
        createdAt: DateTime.now(),
        settings: IntegrationSettings(
          autoSync: false,
          syncInterval: 30,
          syncInventory: true,
          syncOrders: true,
          syncProducts: true,
        ),
      );

      await docRef.set({
        ...integration.toMap(),
        'credentials': credentials,
      });

      return integration;
    } catch (e) {
      throw Exception('Failed to connect platform: $e');
    }
  }

  Future<void> disconnectIntegration(String integrationId) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('integrations')
          .doc(integrationId)
          .update({
        'status': 'disconnected',
        'disconnectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to disconnect integration: $e');
    }
  }

  Future<void> updateIntegrationSettings({
    required String integrationId,
    required IntegrationSettings settings,
  }) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('integrations')
          .doc(integrationId)
          .update({
        'settings': settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update integration settings: $e');
    }
  }

  Future<bool> _validateCredentials(
      String platformId, Map<String, String> credentials) async {
    switch (platformId) {
      case 'shopify':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('apiSecret');
      case 'woocommerce':
        return credentials.containsKey('consumerKey') &&
            credentials.containsKey('consumerSecret');
      case 'amazon':
        return credentials.containsKey('accessKey') &&
            credentials.containsKey('secretKey');
      case 'ebay':
        return credentials.containsKey('appId') &&
            credentials.containsKey('certId');
      default:
        return credentials.isNotEmpty;
    }
  }

  Future<Map<String, dynamic>> _getPlatformDetails(String platformId) async {
    switch (platformId) {
      case 'shopify':
        return {
          'name': 'Shopify',
          'icon': 'assets/icons/shopify.png',
        };
      case 'woocommerce':
        return {
          'name': 'WooCommerce',
          'icon': 'assets/icons/woocommerce.png',
        };
      case 'amazon':
        return {
          'name': 'Amazon',
          'icon': 'assets/icons/amazon.png',
        };
      case 'ebay':
        return {
          'name': 'eBay',
          'icon': 'assets/icons/ebay.png',
        };
      default:
        return {
          'name': 'Custom Platform',
          'icon': 'assets/icons/platform.png',
        };
    }
  }
}

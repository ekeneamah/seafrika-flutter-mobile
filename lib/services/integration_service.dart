import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:crypto/crypto.dart';
import 'package:vendor_app/config/collection_references.dart';
import 'dart:convert';

/// Exception types for integration operations
class IntegrationException implements Exception {
  final String message;
  final String code;
  
  const IntegrationException(this.message, this.code);
  
  @override
  String toString() => 'IntegrationException: $message (Code: $code)';
}

class IntegrationService {
  final String _businessId;
  
  // Encryption key for credentials (in production, this should come from secure storage)
  static const String _encryptionKey = 'vendor_app_integration_key_2024';

  IntegrationService({
    required FirebaseFirestore firestore,
    required String businessId,
  }) : _businessId = businessId;

    /// Create default settings based on platform category
  IntegrationSettings _createDefaultSettings(String category) {
    switch (category) {
      case 'ecommerce':
      case 'marketplace':
        return IntegrationSettings(
          autoSync: false,
          syncInterval: 30,
          syncInventory: true,
          syncOrders: true,
          syncProducts: true,
          // Review settings (off for ecommerce/marketplace)
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: false,
        );
      case 'payment':
        return IntegrationSettings(
          autoSync: false,
          syncInterval: 15,
          syncInventory: false,
          syncOrders: true,
          syncProducts: false,
          // Review settings (off for payment platforms)
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: false,
        );
      case 'social':
        return IntegrationSettings(
          autoSync: false,
          syncInterval: 60,
          syncInventory: false,
          syncOrders: false,
          syncProducts: true,
          // Review settings (off for social platforms)
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: false,
        );
      case 'reviews':
        return IntegrationSettings(
          autoSync: true,
          syncInterval: 60,
          syncInventory: false,
          syncOrders: false,
          syncProducts: false,
          // Review settings (on for review platforms)
          syncReviews: true,
          syncRatings: true,
          autoRespondReviews: false,
          notifyNewReviews: true,
          syncCustomerFeedback: true,
        );
      default:
        // Fallback to ecommerce defaults
        return IntegrationSettings(
          autoSync: false,
          syncInterval: 30,
          syncInventory: true,
          syncOrders: true,
          syncProducts: true,
          // Review settings (default off)
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: false,
        );
    }
  }

  /// Encrypt credentials using SHA-256
  String _encryptCredential(String credential) {
    try {
      final bytes = utf8.encode(credential + _encryptionKey);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      throw IntegrationException('Failed to encrypt credential', 'ENCRYPTION_ERROR');
    }
  }

  /// Validates business ID is not empty
  void _validateBusinessId() {
    if (_businessId.isEmpty) {
      throw IntegrationException('Business ID is required for integration operations', 'INVALID_BUSINESS_ID');
    }
  }

  Future<List<Integration>> fetchIntegrations() async {
    _validateBusinessId();
    
    try {
      final snapshot = await CollectionReferences
          .integrationsForBusiness(_businessId)
          .where('status', isNotEqualTo: 'deleted') // Exclude soft-deleted integrations
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return Integration.fromMap(data);
          })
          .toList();
    } on FirebaseException catch (e) {
      throw IntegrationException('Failed to fetch integrations: ${e.message}', 'FIRESTORE_ERROR');
    } catch (e) {
      throw IntegrationException('Unexpected error while fetching integrations', 'UNKNOWN_ERROR');
    }
  }

  Future<Integration> fetchIntegration(String integrationId) async {
    _validateBusinessId();
    
    if (integrationId.isEmpty) {
      throw IntegrationException('Integration ID is required', 'INVALID_INTEGRATION_ID');
    }
    
    try {
      final doc = await CollectionReferences.integrations
          .doc(integrationId)
          .get();

      if (!doc.exists) {
        throw IntegrationException('Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data?['status'] == 'deleted') {
        throw IntegrationException('Integration has been deleted', 'INTEGRATION_DELETED');
      }

      // Verify integration belongs to the business
      if (data?['businessId'] != _businessId) {
        throw IntegrationException('Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      data!['id'] = doc.id;
      return Integration.fromMap(data);
    } on FirebaseException catch (e) {
      throw IntegrationException('Failed to fetch integration: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException('Unexpected error while fetching integration', 'UNKNOWN_ERROR');
    }
  }

  Future<Integration> connectPlatform({
    required String platformId,
    required Map<String, String> credentials,
  }) async {
    _validateBusinessId();
    
    if (platformId.isEmpty) {
      throw IntegrationException('Platform ID is required', 'INVALID_PLATFORM_ID');
    }
    
    if (credentials.isEmpty) {
      throw IntegrationException('Credentials are required', 'MISSING_CREDENTIALS');
    }

    try {
      // Check if integration already exists for this platform
      final existingQuery = await CollectionReferences
          .integrationsForPlatform(_businessId, platformId)
          .where('status', isNotEqualTo: 'deleted')
          .get();
          
      if (existingQuery.docs.isNotEmpty) {
        throw IntegrationException('Integration already exists for this platform', 'DUPLICATE_INTEGRATION');
      }

      // Validate credentials with platform
      final isValid = await _validateCredentials(platformId, credentials);
      if (!isValid) {
        throw IntegrationException('Invalid credentials provided', 'INVALID_CREDENTIALS');
      }

      // Get platform details
      final platform = await _getPlatformDetails(platformId);

      // Create integration document
      final docRef = CollectionReferences.integrations.doc();

      // Create platform-specific default settings
      final settings = _createDefaultSettings(platform['category'] as String);

      final integration = Integration(
        id: docRef.id,
        platformId: platformId,
        platformName: platform['name'],
        platformIcon: platform['icon'],
        status: 'connected',
        createdAt: DateTime.now(),
        settings: settings,
      );

      // Encrypt sensitive credentials
      final encryptedCredentials = credentials.map(
        (key, value) => MapEntry(key, _encryptCredential(value)),
      );

      await docRef.set({
        ...integration.toMap(),
        'businessId': _businessId, // Add businessId for flat structure
        'credentials': encryptedCredentials,
        'createdBy': _businessId,
        'lastSyncAt': null,
        'syncCount': 0,
      });

      return integration;
    } on FirebaseException catch (e) {
      throw IntegrationException('Failed to connect platform: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException('Unexpected error while connecting platform', 'UNKNOWN_ERROR');
    }
  }

  Future<void> disconnectIntegration(String integrationId) async {
    _validateBusinessId();
    
    if (integrationId.isEmpty) {
      throw IntegrationException('Integration ID is required', 'INVALID_INTEGRATION_ID');
    }

    try {
      // Check if integration exists
      final doc = await CollectionReferences.integrations
          .doc(integrationId)
          .get();
          
      if (!doc.exists) {
        throw IntegrationException('Integration not found', 'INTEGRATION_NOT_FOUND');
      }
      
      final data = doc.data() as Map<String, dynamic>?;
      
      // Verify integration belongs to the business
      if (data?['businessId'] != _businessId) {
        throw IntegrationException('Integration not found', 'INTEGRATION_NOT_FOUND');
      }
      
      if (data?['status'] == 'disconnected') {
        throw IntegrationException('Integration is already disconnected', 'ALREADY_DISCONNECTED');
      }

      await CollectionReferences.integrations
          .doc(integrationId)
          .update({
        'status': 'disconnected',
        'disconnectedAt': FieldValue.serverTimestamp(),
        'disconnectedBy': _businessId,
      });
    } on FirebaseException catch (e) {
      throw IntegrationException('Failed to disconnect integration: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException('Unexpected error while disconnecting integration', 'UNKNOWN_ERROR');
    }
  }

  Future<void> updateIntegrationSettings({
    required String integrationId,
    required IntegrationSettings settings,
  }) async {
    _validateBusinessId();
    
    if (integrationId.isEmpty) {
      throw IntegrationException('Integration ID is required', 'INVALID_INTEGRATION_ID');
    }

    try {
      // Check if integration exists and is active
      final doc = await CollectionReferences.integrations
          .doc(integrationId)
          .get();
          
      if (!doc.exists) {
        throw IntegrationException('Integration not found', 'INTEGRATION_NOT_FOUND');
      }
      
      final data = doc.data() as Map<String, dynamic>?;
      
      // Verify integration belongs to the business
      if (data?['businessId'] != _businessId) {
        throw IntegrationException('Integration not found', 'INTEGRATION_NOT_FOUND');
      }
      
      final status = data?['status'];
      if (status == 'disconnected' || status == 'deleted') {
        throw IntegrationException('Cannot update settings for inactive integration', 'INTEGRATION_INACTIVE');
      }

      // Validate sync interval
      if (settings.autoSync && settings.syncInterval < 5) {
        throw IntegrationException('Sync interval must be at least 5 minutes', 'INVALID_SYNC_INTERVAL');
      }

      await CollectionReferences.integrations
          .doc(integrationId)
          .update({
        'settings': settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _businessId,
      });
    } on FirebaseException catch (e) {
      throw IntegrationException('Failed to update integration settings: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException('Unexpected error while updating settings', 'UNKNOWN_ERROR');
    }
  }

  /// Triggers manual sync for an integration
  Future<void> syncIntegration(String integrationId) async {
    _validateBusinessId();
    
    if (integrationId.isEmpty) {
      throw IntegrationException('Integration ID is required', 'INVALID_INTEGRATION_ID');
    }

    try {
      final integration = await fetchIntegration(integrationId);
      
      if (integration.status != 'connected') {
        throw IntegrationException('Can only sync connected integrations', 'INTEGRATION_NOT_CONNECTED');
      }

      // Update last sync timestamp and increment sync count
      await CollectionReferences.integrations
          .doc(integrationId)
          .update({
        'lastSyncAt': FieldValue.serverTimestamp(),
        'syncCount': FieldValue.increment(1),
        'lastSyncStatus': 'success',
      });

      // TODO: Implement actual platform synchronization logic
      // This would involve calling the respective platform APIs
      
    } on FirebaseException catch (e) {
      throw IntegrationException('Failed to sync integration: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException('Unexpected error during sync', 'UNKNOWN_ERROR');
    }
  }

  /// Soft delete an integration (marks as deleted instead of removing)
  Future<void> deleteIntegration(String integrationId) async {
    _validateBusinessId();
    
    if (integrationId.isEmpty) {
      throw IntegrationException('Integration ID is required', 'INVALID_INTEGRATION_ID');
    }

    try {
      final doc = await CollectionReferences.integrations
          .doc(integrationId)
          .get();
          
      if (!doc.exists) {
        throw IntegrationException('Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      final data = doc.data() as Map<String, dynamic>?;
      
      // Verify integration belongs to the business
      if (data?['businessId'] != _businessId) {
        throw IntegrationException('Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      await CollectionReferences.integrations
          .doc(integrationId)
          .update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _businessId,
      });
    } on FirebaseException catch (e) {
      throw IntegrationException('Failed to delete integration: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException('Unexpected error while deleting integration', 'UNKNOWN_ERROR');
    }
  }

  Future<bool> _validateCredentials(
      String platformId, Map<String, String> credentials) async {
    switch (platformId) {
      // E-commerce Platforms
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
      case 'magento':
        return credentials.containsKey('accessToken') &&
            credentials.containsKey('storeUrl');
            
      // Payment Platforms
      case 'stripe':
        return credentials.containsKey('publishableKey') &&
            credentials.containsKey('secretKey');
      case 'paypal':
        return credentials.containsKey('clientId') &&
            credentials.containsKey('clientSecret');
      case 'square':
        return credentials.containsKey('applicationId') &&
            credentials.containsKey('accessToken');
      case 'razorpay':
        return credentials.containsKey('keyId') &&
            credentials.containsKey('keySecret');
      case 'paystack':
        return credentials.containsKey('publicKey') &&
            credentials.containsKey('secretKey');
      case 'flutterwave':
        return credentials.containsKey('publicKey') &&
            credentials.containsKey('secretKey');
            
      // Social Media Platforms
      case 'facebook':
        return credentials.containsKey('appId') &&
            credentials.containsKey('appSecret') &&
            credentials.containsKey('accessToken');
      case 'instagram':
        return credentials.containsKey('appId') &&
            credentials.containsKey('appSecret') &&
            credentials.containsKey('accessToken');
      case 'twitter':
        return credentials.containsKey('consumerKey') &&
            credentials.containsKey('consumerSecret') &&
            credentials.containsKey('accessToken') &&
            credentials.containsKey('accessTokenSecret');
      case 'tiktok':
        return credentials.containsKey('appId') &&
            credentials.containsKey('appSecret') &&
            credentials.containsKey('accessToken');
      case 'whatsapp_business':
        return credentials.containsKey('phoneNumberId') &&
            credentials.containsKey('accessToken');
      case 'telegram':
        return credentials.containsKey('botToken') &&
            credentials.containsKey('chatId');
            
      // Review & Feedback Platforms
      case 'google_business':
        return credentials.containsKey('placeId') &&
            credentials.containsKey('apiKey');
      case 'google_reviews':
        return credentials.containsKey('businessId') &&
            credentials.containsKey('serviceAccountKey');
      case 'trustpilot':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('businessUnitId');
      case 'yelp':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('businessId');
      case 'tripadvisor':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('locationId');
      case 'bazaarvoice':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('clientId');
      case 'yotpo':
        return credentials.containsKey('appKey') &&
            credentials.containsKey('secret');
      case 'reviews_io':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('storeId');
      case 'shopify_reviews':
        return credentials.containsKey('shopDomain') &&
            credentials.containsKey('accessToken');
      case 'woocommerce_reviews':
        return credentials.containsKey('consumerKey') &&
            credentials.containsKey('consumerSecret') &&
            credentials.containsKey('storeUrl');
            
      default:
        return credentials.isNotEmpty;
    }
  }

  /// Get all supported platforms for online stores
  Future<List<Map<String, dynamic>>> getSupportedPlatforms() async {
    // Return e-commerce and marketplace platforms for online stores
    final platformIds = [
      'shopify',
      'woocommerce', 
      'magento',
      'amazon',
      'ebay',
    ];
    
    final platforms = <Map<String, dynamic>>[];
    for (final platformId in platformIds) {
      final platformDetails = await _getPlatformDetails(platformId);
      platforms.add({
        'id': platformId,
        'name': platformDetails['name'],
        'icon': platformDetails['icon'],
        'category': platformDetails['category'],
      });
    }
    
    return platforms;
  }

  /// Check if user has an existing integration for the specified platform
  Future<bool> hasIntegrationForPlatform(String platformId) async {
    try {
      final integrations = await fetchIntegrations();
      return integrations.any((integration) => integration.platformId == platformId);
    } catch (e) {
      // If there's an error fetching integrations, assume no integration exists
      return false;
    }
  }

  Future<Map<String, dynamic>> _getPlatformDetails(String platformId) async {
    switch (platformId) {
      // E-commerce Platforms
      case 'shopify':
        return {
          'name': 'Shopify',
          'icon': 'assets/icons/shopify.png',
          'category': 'ecommerce',
        };
      case 'woocommerce':
        return {
          'name': 'WooCommerce',
          'icon': 'assets/icons/woocommerce.png',
          'category': 'ecommerce',
        };
      case 'magento':
        return {
          'name': 'Magento',
          'icon': 'assets/icons/magento.png',
          'category': 'ecommerce',
        };
      case 'amazon':
        return {
          'name': 'Amazon',
          'icon': 'assets/icons/amazon.png',
          'category': 'marketplace',
        };
      case 'ebay':
        return {
          'name': 'eBay',
          'icon': 'assets/icons/ebay.png',
          'category': 'marketplace',
        };
        
      // Payment Platforms
      case 'stripe':
        return {
          'name': 'Stripe',
          'icon': 'assets/icons/stripe.png',
          'category': 'payment',
        };
      case 'paypal':
        return {
          'name': 'PayPal',
          'icon': 'assets/icons/paypal.png',
          'category': 'payment',
        };
      case 'square':
        return {
          'name': 'Square',
          'icon': 'assets/icons/square.png',
          'category': 'payment',
        };
      case 'razorpay':
        return {
          'name': 'Razorpay',
          'icon': 'assets/icons/razorpay.png',
          'category': 'payment',
        };
      case 'paystack':
        return {
          'name': 'Paystack',
          'icon': 'assets/icons/paystack.png',
          'category': 'payment',
        };
      case 'flutterwave':
        return {
          'name': 'Flutterwave',
          'icon': 'assets/icons/flutterwave.png',
          'category': 'payment',
        };
        
      // Social Media Platforms
      case 'facebook':
        return {
          'name': 'Facebook',
          'icon': 'assets/icons/facebook.png',
          'category': 'social',
        };
      case 'instagram':
        return {
          'name': 'Instagram',
          'icon': 'assets/icons/instagram.png',
          'category': 'social',
        };
      case 'twitter':
        return {
          'name': 'Twitter',
          'icon': 'assets/icons/twitter.png',
          'category': 'social',
        };
      case 'tiktok':
        return {
          'name': 'TikTok',
          'icon': 'assets/icons/tiktok.png',
          'category': 'social',
        };
      case 'whatsapp_business':
        return {
          'name': 'WhatsApp Business',
          'icon': 'assets/icons/whatsapp.png',
          'category': 'social',
        };
      case 'telegram':
        return {
          'name': 'Telegram',
          'icon': 'assets/icons/telegram.png',
          'category': 'social',
        };
        
      // Review & Feedback Platforms
      case 'google_business':
        return {
          'name': 'Google My Business',
          'icon': 'assets/icons/google_business.png',
          'category': 'reviews',
        };
      case 'google_reviews':
        return {
          'name': 'Google Reviews',
          'icon': 'assets/icons/google_reviews.png',
          'category': 'reviews',
        };
      case 'trustpilot':
        return {
          'name': 'Trustpilot',
          'icon': 'assets/icons/trustpilot.png',
          'category': 'reviews',
        };
      case 'yelp':
        return {
          'name': 'Yelp',
          'icon': 'assets/icons/yelp.png',
          'category': 'reviews',
        };
      case 'tripadvisor':
        return {
          'name': 'TripAdvisor',
          'icon': 'assets/icons/tripadvisor.png',
          'category': 'reviews',
        };
      case 'bazaarvoice':
        return {
          'name': 'Bazaarvoice',
          'icon': 'assets/icons/bazaarvoice.png',
          'category': 'reviews',
        };
      case 'yotpo':
        return {
          'name': 'Yotpo',
          'icon': 'assets/icons/yotpo.png',
          'category': 'reviews',
        };
      case 'reviews_io':
        return {
          'name': 'Reviews.io',
          'icon': 'assets/icons/reviews_io.png',
          'category': 'reviews',
        };
      case 'shopify_reviews':
        return {
          'name': 'Shopify Reviews',
          'icon': 'assets/icons/shopify_reviews.png',
          'category': 'reviews',
        };
      case 'woocommerce_reviews':
        return {
          'name': 'WooCommerce Reviews',
          'icon': 'assets/icons/woocommerce_reviews.png',
          'category': 'reviews',
        };
        
      default:
        return {
          'name': 'Custom Platform',
          'icon': 'assets/icons/platform.png',
          'category': 'other',
        };
    }
  }
}

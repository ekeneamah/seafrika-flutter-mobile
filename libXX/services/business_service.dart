import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vendor_app/models/business.dart';
import 'package:vendor_app/config/collection_names.dart';

class BusinessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get businessCollection =>
      _firestore.collection(CollectionNames.businesses);

  // Create a new business
  Future<String> createBusiness(Business business) async {
    try {
      debugPrint("Ceate business data $business");
      // Validate business data first
      /* if (!validateBusinessData(business)) {
        throw Exception('Invalid business data provided');
      } */

      // Check if user can create a business
      final canCreate = await canUserCreateBusiness(business.ownerId);
      if (!canCreate) {
        throw Exception(
            'You do not have permission to create a business. Please ensure you have the correct role.');
      }

      // Generate business ID
      final businessId = 'BIZ-${DateTime.now().microsecondsSinceEpoch}';
      final createdAt = DateTime.now();
      final newBusiness = business.copyWith(
        id: businessId,
        createdAt: createdAt,
      );

      // Create a unique name identifier for checking uniqueness
      final nameId =
          '${business.name.toLowerCase().replaceAll(' ', '_')}_${business.country.toLowerCase()}';

      // Use a batch write to ensure atomicity
      final batch = _firestore.batch();

      // First, create the business name document to check uniqueness
      // This must include all required fields according to Firestore rules
      final businessNameDoc =
          _firestore.collection(CollectionNames.businessNames).doc(nameId);
      batch.set(businessNameDoc, {
        'name': business.name,
        'country': business.country,
        'businessId': businessId,
        'ownerId': business.ownerId,
        'isActive': true,
        'createdAt': createdAt,
      });

      // Then, create the business document
      // Ensure all required fields are present according to Firestore rules
      final businessDoc = businessCollection.doc(businessId);
      final businessData = newBusiness.toMap();

      // Validate required fields for Firestore rules
      final requiredFields = [
        'id',
        'name',
        'address',
        'country',
        'state',
        'ownerId',
        'isActive',
        'createdAt'
      ];
      for (final field in requiredFields) {
        if (!businessData.containsKey(field) || businessData[field] == null) {
          throw Exception('Required field $field is missing');
        }
      }

      // Ensure isActive is explicitly set to true
      businessData['isActive'] = true;

      batch.set(businessDoc, businessData);

      // Execute the batch
      await batch.commit();

      // Assign business_owner role to the user
      await assignBusinessOwnerRole(business.ownerId);

      return businessId;
    } catch (e) {
      debugPrint('Error creating business: $e');

      // Check if it's a permission error during creation
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'You do not have permission to create a business. Please ensure you are logged in as a business owner.');
      }

      // Check if it's a uniqueness violation
      if (e.toString().contains('already exists') ||
          e.toString().contains('ALREADY_EXISTS')) {
        throw Exception(
            'A business with this name already exists in ${business.country}. Please choose a different name.');
      }

      // Check for missing required fields
      if (e.toString().contains('Required field')) {
        rethrow;
      }

      // Check for validation errors
      if (e.toString().contains('Invalid business data')) {
        rethrow;
      }

      rethrow;
    }
  }

  // Get business by ID
  Future<Business?> getBusiness(String businessId) async {
    try {
      final doc = await businessCollection.doc(businessId).get();
      if (doc.exists) {
        return Business.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting business: $e');
      return null;
    }
  }

  // Check if business name is available
  Future<bool> isBusinessNameAvailable(
      String businessName, String country) async {
    try {
      final nameId =
          '${businessName.toLowerCase().replaceAll(' ', '_')}_${country.toLowerCase()}';
      final doc = await _firestore
          .collection(CollectionNames.businessNames)
          .doc(nameId)
          .get();
      return !doc.exists ||
          (doc.data() as Map<String, dynamic>)['isActive'] != true;
    } catch (e) {
      debugPrint('Error checking business name availability: $e');
      return false; // Err on the side of caution
    }
  }

  // Check if user is a member of a business (owner or admin)
  Future<bool> isUserBusinessMember(String businessId, String userId) async {
    try {
      final business = await getBusiness(businessId);
      if (business == null) return false;

      return business.ownerId == userId || business.adminIds.contains(userId);
    } catch (e) {
      debugPrint('Error checking business membership: $e');
      return false;
    }
  }

  // Get businesses by owner
  Future<List<Business>> getBusinessesByOwner(String ownerId) async {
    try {
      final querySnapshot = await businessCollection
          .where('ownerId', isEqualTo: ownerId)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Business.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting businesses by owner: $e');
      return [];
    }
  }

  // Update business
  Future<void> updateBusiness(
      String businessId, Map<String, dynamic> updates) async {
    try {
      // Check if name or country is being updated
      if (updates.containsKey('name') || updates.containsKey('country')) {
        // Get current business data
        final currentBusiness = await getBusiness(businessId);
        if (currentBusiness == null) {
          throw Exception('Business not found');
        }

        final newName = updates['name'] ?? currentBusiness.name;
        final newCountry = updates['country'] ?? currentBusiness.country;

        // If name or country changed, update the businessNames collection
        if (newName != currentBusiness.name ||
            newCountry != currentBusiness.country) {
          final batch = _firestore.batch();

          // Delete old name entry
          final oldNameId =
              '${currentBusiness.name.toLowerCase().replaceAll(' ', '_')}_${currentBusiness.country.toLowerCase()}';
          final oldNameDoc = _firestore
              .collection(CollectionNames.businessNames)
              .doc(oldNameId);
          batch.delete(oldNameDoc);

          // Create new name entry
          final newNameId =
              '${newName.toLowerCase().replaceAll(' ', '_')}_${newCountry.toLowerCase()}';
          final newNameDoc = _firestore
              .collection(CollectionNames.businessNames)
              .doc(newNameId);
          batch.set(newNameDoc, {
            'name': newName,
            'country': newCountry,
            'businessId': businessId,
            'ownerId': currentBusiness.ownerId,
            'isActive': true,
            'createdAt': currentBusiness.createdAt,
            'updatedAt': DateTime.now(),
          });

          // Update business document
          updates['updatedAt'] = DateTime.now().toIso8601String();
          final businessDoc = businessCollection.doc(businessId);
          batch.update(businessDoc, updates);

          // Execute the batch
          await batch.commit();
        } else {
          // Just update the business document
          updates['updatedAt'] = DateTime.now().toIso8601String();
          await businessCollection.doc(businessId).update(updates);
        }
      } else {
        // Regular update without name/country change
        updates['updatedAt'] = DateTime.now().toIso8601String();
        await businessCollection.doc(businessId).update(updates);
      }
    } catch (e) {
      debugPrint('Error updating business: $e');

      // Check if it's a uniqueness violation
      if (e.toString().contains('already exists') ||
          e.toString().contains('ALREADY_EXISTS')) {
        throw Exception(
            'A business with this name already exists in the specified country. Please choose a different name.');
      }

      rethrow;
    }
  }

  // Delete business (soft delete)
  Future<void> deleteBusiness(String businessId) async {
    try {
      // Get current business data
      final currentBusiness = await getBusiness(businessId);
      if (currentBusiness == null) {
        throw Exception('Business not found');
      }

      final batch = _firestore.batch();

      // Update business document to inactive
      final businessDoc = businessCollection.doc(businessId);
      batch.update(businessDoc, {
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Update businessNames document to inactive
      final nameId =
          '${currentBusiness.name.toLowerCase().replaceAll(' ', '_')}_${currentBusiness.country.toLowerCase()}';
      final nameDoc =
          _firestore.collection(CollectionNames.businessNames).doc(nameId);
      batch.update(nameDoc, {
        'isActive': false,
        'updatedAt': DateTime.now(),
      });

      // Execute the batch
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting business: $e');
      rethrow;
    }
  }

  // Check if user can create a business
  Future<bool> canUserCreateBusiness(String userId) async {
    try {
      // Check if user document exists
      final userDoc =
          await _firestore.collection(CollectionNames.users).doc(userId).get();

      if (!userDoc.exists) {
        // User doesn't exist, they can create their first business
        return true;
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      // Check if user has business_owner role
      if (userData.containsKey('roles') &&
          (userData['roles'] as List).contains('business_owner')) {
        return true;
      }

      // If no roles are set, they can become a business owner
      if (!userData.containsKey('roles') ||
          (userData['roles'] as List).isEmpty) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking if user can create business: $e');
      return false;
    }
  }

  // Validate business data before creation
  bool validateBusinessData(Business business) {
    // Check required fields
    if (business.name.trim().isEmpty) return false;
    if (business.address.trim().isEmpty) return false;
    if (business.country.trim().isEmpty) return false;
    if (business.state.trim().isEmpty) return false;
    if (business.ownerId.trim().isEmpty) return false;

    // Validate business name length
    if (business.name.length < 2 || business.name.length > 100) return false;

    // Validate email format if provided
    if (business.email != null && business.email!.isNotEmpty) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(business.email!)) return false;
    }

    // Validate phone format if provided
    if (business.phone != null && business.phone!.isNotEmpty) {
      final phoneRegex = RegExp(r'^[\+]?[1-9][\d]{3,14}$');
      if (!phoneRegex.hasMatch(
          business.phone!.replaceAll(RegExp(r'[\s\-\(\)]'), ''))) return false;
    }

    // Validate website format if provided
    if (business.website != null && business.website!.isNotEmpty) {
      final websiteRegex = RegExp(r'^https?://[^\s/$.?#].[^\s]*$');
      if (!websiteRegex.hasMatch(business.website!)) return false;
    }

    return true;
  }

  // Add user role assignment after business creation
  Future<void> assignBusinessOwnerRole(String userId) async {
    try {
      final userDoc =
          await _firestore.collection(CollectionNames.users).doc(userId).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        List<String> roles = List<String>.from(userData['roles'] ?? []);

        // Add business_owner role if not already present
        if (!roles.contains('business_owner')) {
          roles.add('business_owner');
          await _firestore
              .collection(CollectionNames.users)
              .doc(userId)
              .update({
            'roles': roles,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
      } else {
        // User doesn't exist, create with business_owner role
        await _firestore.collection(CollectionNames.users).doc(userId).set({
          'roles': ['business_owner'],
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error assigning business owner role: $e');
      rethrow;
    }
  }
}

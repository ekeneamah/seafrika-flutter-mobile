import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/permission.dart';

class FirestoreSeeder {
  final FirebaseFirestore firestore;

  FirestoreSeeder({required this.firestore});

  Future<void> seedPermissions() async {
    final permissions = [
      Permission(
        id: 'view_users',
        name: 'View Users',
        description: 'Allows viewing of user profiles.',
        category: PermissionCategory.users,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'edit_users',
        name: 'Edit Users',
        description: 'Allows editing of user profiles.',
        category: PermissionCategory.users,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'manage_permissions',
        name: 'Manage Permissions',
        description: 'Allows creating, editing, activating, deactivating, and deleting permissions.',
        category: PermissionCategory.admin,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'manage_roles',
        name: 'Manage Roles',
        description: 'Allows assigning roles to users.',
        category: PermissionCategory.admin,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'view_inventory',
        name: 'View Inventory',
        description: 'Allows viewing inventory items.',
        category: PermissionCategory.inventory,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'edit_inventory',
        name: 'Edit Inventory',
        description: 'Allows modifying inventory items.',
        category: PermissionCategory.inventory,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'add_to_store',
        name: 'Add to Store',
        description: 'Allows adding inventory items to stores.',
        category: PermissionCategory.inventory,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'view_stores',
        name: 'View Stores',
        description: 'Allows viewing store list.',
        category: PermissionCategory.stores,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'edit_stores',
        name: 'Edit Stores',
        description: 'Allows modifying store details.',
        category: PermissionCategory.stores,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'delete_stores',
        name: 'Delete Stores',
        description: 'Allows removing stores.',
        category: PermissionCategory.stores,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'reset_password',
        name: 'Reset Password',
        description: 'Allows updating user passwords.',
        category: PermissionCategory.auth,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'view_notifications',
        name: 'View Notifications',
        description: 'Allows accessing notification list.',
        category: PermissionCategory.notifications,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'mark_notifications',
        name: 'Mark Notifications',
        description: 'Allows marking notifications as read/unread.',
        category: PermissionCategory.notifications,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'view_booking_requests',
        name: 'View Booking Requests',
        description: 'Allows viewing customer booking requests.',
        category: PermissionCategory.bookings,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'search_booking_requests',
        name: 'Search Booking Requests',
        description: 'Allows searching through booking requests.',
        category: PermissionCategory.bookings,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'view_booking_details',
        name: 'View Booking Details',
        description: 'Allows accessing detailed information about a booking.',
        category: PermissionCategory.bookings,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'create_booking',
        name: 'Create Booking',
        description: 'Allows creating new bookings.',
        category: PermissionCategory.bookings,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'edit_booking',
        name: 'Edit Booking',
        description: 'Allows modifying existing bookings.',
        category: PermissionCategory.bookings,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'view_expenses',
        name: 'View Expenses',
        description: 'Allows viewing expense list and details.',
        category: PermissionCategory.expenses,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'create_expense',
        name: 'Create Expense',
        description: 'Allows creating new expenses.',
        category: PermissionCategory.expenses,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'edit_expense',
        name: 'Edit Expense',
        description: 'Allows editing existing expenses.',
        category: PermissionCategory.expenses,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'delete_expense',
        name: 'Delete Expense',
        description: 'Allows deleting expenses.',
        category: PermissionCategory.expenses,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'view_customers',
        name: 'View Customers',
        description: 'Allows viewing customer list and details.',
        category: PermissionCategory.customers,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'create_customer',
        name: 'Create Customer',
        description: 'Allows creating new customers.',
        category: PermissionCategory.customers,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'edit_customer',
        name: 'Edit Customer',
        description: 'Allows editing existing customers.',
        category: PermissionCategory.customers,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'delete_customer',
        name: 'Delete Customer',
        description: 'Allows deleting customers.',
        category: PermissionCategory.customers,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      // --- User Management Screen Permissions ---
      Permission(
        id: 'view_user_management',
        name: 'View User Management',
        description: 'Allows access to the user management screen.',
        category: PermissionCategory.users,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'create_user',
        name: 'Create User',
        description: 'Allows creating new users.',
        category: PermissionCategory.users,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'edit_user',
        name: 'Edit User',
        description: 'Allows editing existing users.',
        category: PermissionCategory.users,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'delete_user',
        name: 'Delete User',
        description: 'Allows deleting users.',
        category: PermissionCategory.users,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Permission(
        id: 'assign_roles_to_user',
        name: 'Assign Roles to User',
        description: 'Allows assigning roles to users.',
        category: PermissionCategory.users,
        isActive: true,
        createdAt: DateTime.now(),
      ),
      // Add more permissions as needed
    ];

    final batch = firestore.batch();
    for (var permission in permissions) {
      debugPrint('Seeding permission: ${permission.name}');
      // Create a document reference for each permission
      final docRef = firestore.collection('permissions').doc(permission.id);
      batch.set(docRef, permission.toMap());
    }

    await batch.commit();
  }
}

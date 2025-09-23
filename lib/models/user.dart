import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  business_owner,
  admin,
  manager,
  staff,
  viewer,
}

class User {
  final String id;
  final String? businessId; // Made optional
  final String vendorId;
  final String email;
  final String firstName;
  final String lastName;
  final String? businessName; // Made optional
  final String? accessToken; // Access token for third-party integrations
  final String? businessAddress; // Made optional
  final String? country; // Made optional
  final String? state; // Made optional
  final String? phone;
  final String? profileImage;
  final List<String> teamIds;
  final List<UserRole> roles;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final List<String> permissions;
  final Map<String, List<UserRole>> storeRoles;
  final bool defaultPasswordChanged;

  // Optional personal attributes
  final DateTime? dateOfBirth;
  final DateTime? weddingAnniversary;
  final String? address;
  final String? hobbies;
  final String? notes;

  User({
    required this.id,
    this.businessId, // Made optional
    required this.vendorId,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.businessName, // Made optional
    this.accessToken, // Access token for integrations
    this.businessAddress, // Made optional
    this.country, // Made optional
    this.state, // Made optional
    this.phone,
    this.profileImage,
    required this.teamIds,
    required this.roles,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
    required this.permissions,
    required this.storeRoles,
    this.defaultPasswordChanged = false,
    // Optional personal attributes
    this.dateOfBirth,
    this.weddingAnniversary,
    this.address,
    this.hobbies,
    this.notes,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'vendorId': vendorId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'businessName': businessName,
      'businessAddress': businessAddress,
      'country': country,
      'state': state,
      'phone': phone,
      'profileImage': profileImage,
      'teamIds': teamIds,
      'roles': roles.map((role) => role.name).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'permissions': permissions,
      'storeRoles': storeRoles.map(
        (key, value) => MapEntry(
          key,
          value.map((role) => role.toString()).toList(),
        ),
      ),
      'defaultPasswordChanged': defaultPasswordChanged,
      // Optional personal attributes
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'weddingAnniversary': weddingAnniversary?.toIso8601String(),
      'address': address,
      'hobbies': hobbies,
      'notes': notes,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    // Handle timestamp or string for createdAt
    DateTime createdAt;

    if (map['createdAt'] is Timestamp) {
      debugPrint("created at is Timestamp $map['createdAt']");
      createdAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      debugPrint("created at is String $map['createdAt']");
      createdAt = DateTime.parse(map['createdAt']);
    } else {
      createdAt = DateTime.now(); // Fallback
    }

    // Handle timestamp or string for lastLoginAt
    DateTime? lastLoginAt;
    if (map['lastLoginAt'] is Timestamp) {
      lastLoginAt = (map['lastLoginAt'] as Timestamp).toDate();
    } else if (map['lastLoginAt'] is String) {
      lastLoginAt = DateTime.parse(map['lastLoginAt']);
    }

    return User(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      vendorId: map['vendorId'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      businessName: map['businessName'] ?? '',
      accessToken: map['accessToken'],
      businessAddress: map['businessAddress'] ?? '',
      country: map['country'] ?? '',
      state: map['state'] ?? '',
      phone: map['phone'],
      profileImage: map['profileImage'],
      teamIds: List<String>.from(map['teamIds'] ?? []),
      roles: (map['roles'] as List<dynamic>?)
              ?.map((role) => UserRole.values.firstWhere(
                    (e) => e.name == role,
                    orElse: () => UserRole.viewer,
                  ))
              .toList() ??
          [UserRole.viewer],
      isActive: map['isActive'] ?? true,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      permissions: List<String>.from(map['permissions'] ?? []),
      storeRoles: (map['storeRoles'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value as List<dynamic>)
                  .map((e) => UserRole.values.firstWhere(
                        (role) => role.name == e,
                        orElse: () => UserRole.viewer,
                      ))
                  .toList(),
            ),
          ) ??
          {},
      defaultPasswordChanged: map['defaultPasswordChanged'] ?? false,
      // Optional personal attributes
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.parse(map['dateOfBirth'])
          : null,
      weddingAnniversary: map['weddingAnniversary'] != null
          ? DateTime.parse(map['weddingAnniversary'])
          : null,
      address: map['address'],
      hobbies: map['hobbies'],
      notes: map['notes'],
    );
  }

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle timestamp or string for createdAt
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      createdAt = DateTime.parse(data['createdAt']);
    } else {
      createdAt = DateTime.now(); // Fallback
    }

    // Handle timestamp or string for lastLoginAt
    DateTime? lastLoginAt;
    if (data['lastLoginAt'] is Timestamp) {
      lastLoginAt = (data['lastLoginAt'] as Timestamp).toDate();
    } else if (data['lastLoginAt'] is String) {
      lastLoginAt = DateTime.parse(data['lastLoginAt']);
    }

    return User(
      id: data['id'] ?? '',
      businessId: data['businessId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      businessName: data['businessName'] ?? '',
      businessAddress: data['businessAddress'] ?? '',
      country: data['country'] ?? '',
      state: data['state'] ?? '',
      phone: data['phone'],
      profileImage: data['profileImage'],
      teamIds: List<String>.from(data['teamIds'] ?? []),
      roles: (data['roles'] as List<dynamic>?)
              ?.map((role) => UserRole.values.firstWhere(
                    (e) => e.toString().split('.').last == role,
                    orElse: () => UserRole.viewer,
                  ))
              .toList() ??
          [UserRole.viewer],
      isActive: data['isActive'] ?? true,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt,
      permissions: List<String>.from(data['permissions'] ?? []),
      storeRoles: (data['storeRoles'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value as List<dynamic>)
                  .map((e) => UserRole.values.firstWhere(
                        (role) => role.name == e,
                        orElse: () => UserRole.viewer,
                      ))
                  .toList(),
            ),
          ) ??
          {},
      defaultPasswordChanged: data['defaultPasswordChanged'] ?? false,
      // Optional personal attributes
      dateOfBirth: data['dateOfBirth'] != null
          ? DateTime.parse(data['dateOfBirth'])
          : null,
      weddingAnniversary: data['weddingAnniversary'] != null
          ? DateTime.parse(data['weddingAnniversary'])
          : null,
      address: data['address'],
      hobbies: data['hobbies'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'vendorId': vendorId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'businessName': businessName,
      'businessAddress': businessAddress,
      'businessId': businessId,
      'country': country,
      'state': state,
      'phone': phone,
      'profileImage': profileImage,
      'teamIds': teamIds,
      'roles': roles.map((role) => role.toString().split('.').last).toList(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'permissions': permissions,
      'storeRoles': storeRoles.map(
        (key, value) => MapEntry(
          key,
          value.map((role) => role.toString()).toList(),
        ),
      ),
      'defaultPasswordChanged': defaultPasswordChanged,
      // Optional personal attributes
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'weddingAnniversary': weddingAnniversary?.toIso8601String(),
      'address': address,
      'hobbies': hobbies,
      'notes': notes,
    };
  }

  User copyWith({
    String? id,
    String? vendorId,
    String? email,
    String? firstName,
    String? lastName,
    String? businessName,
    String? businessAddress,
    String? businessId,
    String? country,
    String? state,
    String? phone,
    String? profileImage,
    List<String>? teamIds,
    List<UserRole>? roles,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    List<String>? permissions,
    Map<String, List<UserRole>>? storeRoles,
    bool? defaultPasswordChanged,
    // Optional personal attributes
    DateTime? dateOfBirth,
    DateTime? weddingAnniversary,
    String? address,
    String? hobbies,
    String? notes,
  }) {
    return User(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      country: country ?? this.country,
      state: state ?? this.state,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      teamIds: teamIds ?? this.teamIds,
      roles: roles ?? this.roles,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      permissions: permissions ?? this.permissions,
      storeRoles: storeRoles ?? this.storeRoles,
      defaultPasswordChanged:
          defaultPasswordChanged ?? this.defaultPasswordChanged,
      businessId: businessId ?? this.businessId,
      // Optional personal attributes
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      weddingAnniversary: weddingAnniversary ?? this.weddingAnniversary,
      address: address ?? this.address,
      hobbies: hobbies ?? this.hobbies,
      notes: notes ?? this.notes,
    );
  }

  bool hasRole(UserRole role) => roles.contains(role);
  bool hasAnyRole(List<UserRole> roles) =>
      roles.any((role) => this.roles.contains(role));
  bool hasAllRoles(List<UserRole> roles) =>
      roles.every((role) => this.roles.contains(role));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.phone == phone &&
        other.profileImage == profileImage &&
        listEquals(other.teamIds, teamIds) &&
        listEquals(other.roles, roles) &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.lastLoginAt == lastLoginAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      email,
      firstName,
      lastName,
      phone,
      profileImage,
      Object.hashAll(teamIds),
      Object.hashAll(roles.map((e) => e.toString())),
      isActive,
      createdAt,
      lastLoginAt,
    );
  }
}

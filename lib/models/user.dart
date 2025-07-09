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
  final String businessId;
  final String vendorId;
  final String email;
  final String firstName;
  final String lastName;
  final String businessName;
  final String businessAddress;
  final String country;
  final String state;
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

  User({
    required this.id,
    required this.businessId,
    required this.vendorId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.businessName,
    required this.businessAddress,
    required this.country,
    required this.state,
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
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      businessId: map['businessId'] ?? '',
      vendorId: map['vendorId'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      businessName: map['businessName'] ?? '',
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
      createdAt: DateTime.parse(map['createdAt']),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : null,
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
    );
  }

  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      createdAt: DateTime.parse(data['createdAt']),
      lastLoginAt: data['lastLoginAt'] != null
          ? DateTime.parse(data['lastLoginAt'])
          : null,
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

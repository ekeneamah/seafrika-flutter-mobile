class Store {
  final String id;
  final String businessId; // renamed from vendorId
  final String ownerId; // now required
  final String name;
  final String address;
  final String contactPerson;
  final String contactPhone;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  final String? coverImageUrl;
  final String? description;
  final String? phone;
  final String? email;
  final String? type; // 'physical' or 'online'
  final String? platform; // For online stores: 'shopify', 'woocommerce', etc.

  Store({
    required this.id,
    required this.businessId,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.contactPerson,
    required this.contactPhone,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.coverImageUrl,
    this.description,
    this.phone,
    this.email,
    required bool isDeleted,
    required bool isVerified,
    this.type,
    this.platform,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'ownerId': ownerId,
      'name': name,
      'address': address,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imageUrl': imageUrl,
      'coverImageUrl': coverImageUrl,
      'description': description,
      'phone': phone,
      'email': email,
      'type': type,
      'platform': platform,
    };
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      ownerId: map['ownerId'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      contactPerson: map['contactPerson'] as String,
      contactPhone: map['contactPhone'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      imageUrl: map['imageUrl'] as String?,
      coverImageUrl: map['coverImageUrl'] as String?,
      description: map['description'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      type: map['type'] as String?,
      platform: map['platform'] as String?,
      isDeleted: map['isDeleted'] as bool? ?? false,
      isVerified: map['isVerified'] as bool? ?? false,
    );
  }

  Store copyWith({
    String? id,
    String? businessId,
    String? ownerId,
    String? name,
    String? address,
    String? contactPerson,
    String? contactPhone,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
    String? coverImageUrl,
    String? description,
    String? phone,
    String? email,
    String? type,
    String? platform,
  }) {
    return Store(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      type: type ?? this.type,
      platform: platform ?? this.platform,
      isDeleted: false, // Assuming copy does not change deletion status
      isVerified: false, // Assuming copy does not change verification status
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

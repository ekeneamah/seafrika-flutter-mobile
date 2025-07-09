class Store {
  final String id;
  final String vendorId;
  final String name;
  final String address;
  final String contactPerson;
  final String contactPhone;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  final String? coverImageUrl;
  final String? ownerId;
  final String? description;
  final String? phone;
  final String? email;

  Store({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.address,
    required this.contactPerson,
    required this.contactPhone,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.imageUrl,
    required this.coverImageUrl,
    this.ownerId,
    required this.description,
    required this.phone,
    required this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'name': name,
      'address': address,
      'contactPerson': contactPerson,
      'contactPhone': contactPhone,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imageUrl': imageUrl,
      'coverImageUrl': coverImageUrl,
      'ownerId': ownerId,
      'description': description,
      'phone': phone,
      'email': email,
    };
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as String,
      vendorId: map['vendorId'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      contactPerson: map['contactPerson'] as String,
      contactPhone: map['contactPhone'] as String,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      imageUrl: map['imageUrl'] as String?,
      coverImageUrl: map['coverImageUrl'] as String?,
      ownerId: map['ownerId'] as String?,
      description: map['description'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
    );
  }

  Store copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? address,
    String? contactPerson,
    String? contactPhone,
    String? notes,
    DateTime? createdAt,
  }) {
    return Store(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      contactPhone: contactPhone ?? this.contactPhone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      ownerId: ownerId ?? this.ownerId,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

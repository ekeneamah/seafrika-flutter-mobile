class Business {
  final String id;
  final String name;
  final String address;
  final String country;
  final String state;
  final String? industry; // Added industry field
  final String? phone;
  final String? email;
  final String? website;
  final String? description;
  final String? logoUrl;
  final String ownerId; // User ID who owns this business
  final List<String> adminIds; // Users who can admin this business
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Business({
    required this.id,
    required this.name,
    required this.address,
    required this.country,
    required this.state,
    this.industry, // Added industry parameter
    this.phone,
    this.email,
    this.website,
    this.description,
    this.logoUrl,
    required this.ownerId,
    this.adminIds = const [],
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'country': country,
      'state': state,
      'industry': industry, // Added industry to map
      'phone': phone,
      'email': email,
      'website': website,
      'description': description,
      'logoUrl': logoUrl,
      'ownerId': ownerId,
      'adminIds': adminIds,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      country: map['country'] ?? '',
      state: map['state'] ?? '',
      industry: map['industry'], // Added industry from map
      phone: map['phone'],
      email: map['email'],
      website: map['website'],
      description: map['description'],
      logoUrl: map['logoUrl'],
      ownerId: map['ownerId'] ?? '',
      adminIds: List<String>.from(map['adminIds'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  Business copyWith({
    String? id,
    String? name,
    String? address,
    String? country,
    String? state,
    String? industry, // Added industry parameter
    String? phone,
    String? email,
    String? website,
    String? description,
    String? logoUrl,
    String? ownerId,
    List<String>? adminIds,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Business(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      country: country ?? this.country,
      state: state ?? this.state,
      industry: industry ?? this.industry, // Added industry assignment
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      ownerId: ownerId ?? this.ownerId,
      adminIds: adminIds ?? this.adminIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Business(id: $id, name: $name, address: $address, country: $country, state: $state, ownerId: $ownerId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Business && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

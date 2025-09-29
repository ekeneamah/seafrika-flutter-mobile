class Team {
  final String id;
  final String vendorId;
  final String name;
  final String? description;
  final List<String> memberIds;
  final List<String> managerIds;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;

  Team({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description,
    required this.memberIds,
    required this.managerIds,
    required this.isActive,
    required this.createdAt,
    this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'name': name,
      'description': description,
      'memberIds': memberIds,
      'managerIds': managerIds,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'] ?? '',
      vendorId: map['vendorId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      memberIds: List<String>.from(map['memberIds'] ?? []),
      managerIds: List<String>.from(map['managerIds'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
      lastUpdatedAt: map['lastUpdatedAt'] != null
          ? DateTime.parse(map['lastUpdatedAt'])
          : null,
    );
  }

  Team copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? description,
    List<String>? memberIds,
    List<String>? managerIds,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) {
    return Team(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      description: description ?? this.description,
      memberIds: memberIds ?? this.memberIds,
      managerIds: managerIds ?? this.managerIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

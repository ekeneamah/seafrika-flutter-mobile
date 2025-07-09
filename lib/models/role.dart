class Role {
  final String id;
  final String name;
  final String description;
  final List<String> permissions;

  Role({
    required this.id,
    required this.name,
    required this.permissions,
    this.description = '',
  });

  factory Role.fromMap(Map<String, dynamic> map) {
    return Role(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      permissions: List<String>.from(map['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'permissions': permissions,
    };
  }

  List<String> get permissionIds => permissions;
}

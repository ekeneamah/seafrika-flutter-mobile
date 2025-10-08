import 'package:cloud_firestore/cloud_firestore.dart';
import 'message.dart';

/// Unified conversation model for all messaging platforms
/// Provides a consistent structure regardless of the underlying platform
class Conversation {
  final String id;
  final String integrationId;
  final String businessId;

  // Conversation participants
  final List<ConversationParticipant> participants;

  // Conversation metadata
  final String? title;
  final String? description;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;

  // Read status - NEW FIELDS
  final bool isRead; // Whether the conversation has been read by business
  final DateTime? readAt; // When conversation was last read by business

  // Message counts
  final int messageCount;
  final int unreadCount; // Messages not read by business

  // Platform-specific data
  final String platformId; // Platform's native conversation ID
  final String platformName; // e.g., 'messenger', 'whatsapp', 'instagram'

  // Status and tags
  final ConversationStatus status;
  final List<String> tags;

  // Assignment
  final String? assignedTo; // User ID
  final DateTime? assignedAt;

  // Last message preview
  final Message? lastMessage;

  // Metadata
  final Map<String, dynamic>? metadata;

  const Conversation({
    required this.id,
    required this.integrationId,
    required this.businessId,
    required this.participants,
    this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    required this.isRead,
    this.readAt,
    required this.messageCount,
    required this.unreadCount,
    required this.platformId,
    required this.platformName,
    required this.status,
    this.tags = const [],
    this.assignedTo,
    this.assignedAt,
    this.lastMessage,
    this.metadata,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      integrationId: map['integrationId'] as String,
      businessId: map['businessId'] as String,
      participants: (map['participants'] as List? ?? [])
          .map((item) => ConversationParticipant.fromMap(item))
          .toList(),
      title: map['title'] as String?,
      description: map['description'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      lastMessageAt: map['lastMessageAt'] != null
          ? _parseDateTime(map['lastMessageAt'])
          : null,
      isRead: map['isRead'] as bool? ?? false,
      readAt: map['readAt'] != null ? _parseDateTime(map['readAt']) : null,
      messageCount: map['messageCount'] as int? ?? 0,
      unreadCount: map['unreadCount'] as int? ?? 0,
      platformId: map['platformId'] as String,
      platformName: map['platformName'] as String,
      status: ConversationStatus.values.firstWhere(
        (status) => status.value == map['status'],
        orElse: () => ConversationStatus.active,
      ),
      tags: List<String>.from(map['tags'] as List? ?? []),
      assignedTo: map['assignedTo'] as String?,
      assignedAt:
          map['assignedAt'] != null ? _parseDateTime(map['assignedAt']) : null,
      lastMessage: map['lastMessage'] != null
          ? Message.fromMap(map['lastMessage'])
          : null,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'integrationId': integrationId,
      'businessId': businessId,
      'participants': participants.map((item) => item.toMap()).toList(),
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'messageCount': messageCount,
      'unreadCount': unreadCount,
      'platformId': platformId,
      'platformName': platformName,
      'status': status.value,
      'tags': tags,
      'assignedTo': assignedTo,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'lastMessage': lastMessage?.toMap(),
      'metadata': metadata,
    };
  }

  Conversation copyWith({
    String? id,
    String? integrationId,
    String? businessId,
    List<ConversationParticipant>? participants,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    bool? isRead,
    DateTime? readAt,
    int? messageCount,
    int? unreadCount,
    String? platformId,
    String? platformName,
    ConversationStatus? status,
    List<String>? tags,
    String? assignedTo,
    DateTime? assignedAt,
    Message? lastMessage,
    Map<String, dynamic>? metadata,
  }) {
    return Conversation(
      id: id ?? this.id,
      integrationId: integrationId ?? this.integrationId,
      businessId: businessId ?? this.businessId,
      participants: participants ?? this.participants,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      messageCount: messageCount ?? this.messageCount,
      unreadCount: unreadCount ?? this.unreadCount,
      platformId: platformId ?? this.platformId,
      platformName: platformName ?? this.platformName,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedAt: assignedAt ?? this.assignedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      metadata: metadata ?? this.metadata,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    throw ArgumentError('Invalid date format: $value');
  }
}

class ConversationParticipant {
  final String id;
  final String? name;
  final ParticipantType type;
  final String platformId;
  final Map<String, dynamic>? metadata;

  const ConversationParticipant({
    required this.id,
    this.name,
    required this.type,
    required this.platformId,
    this.metadata,
  });

  factory ConversationParticipant.fromMap(Map<String, dynamic> map) {
    return ConversationParticipant(
      id: map['id'] as String,
      name: map['name'] as String?,
      type: ParticipantType.values.firstWhere(
        (type) => type.value == map['type'],
        orElse: () => ParticipantType.customer,
      ),
      platformId: map['platformId'] as String,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.value,
      'platformId': platformId,
      'metadata': metadata,
    };
  }
}

// Conversation Status Enum
enum ConversationStatus {
  active('active'),
  archived('archived'),
  closed('closed'),
  spam('spam');

  const ConversationStatus(this.value);
  final String value;
}

// Participant Type Enum
enum ParticipantType {
  customer('customer'),
  business('business'),
  agent('agent');

  const ParticipantType(this.value);
  final String value;
}

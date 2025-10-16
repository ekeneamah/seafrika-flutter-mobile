import 'package:cloud_firestore/cloud_firestore.dart';

/// Message data model for multi-platform messaging
class Message {
  final String id;
  final String businessId;
  final String integrationId;
  final String conversationId;
  final MessagePlatform platform;
  final MessageType type;
  final MessageContent content;
  final MessageSender sender;
  final MessageRecipient recipient;
  final MessageMetadata metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    required this.businessId,
    required this.integrationId,
    required this.conversationId,
    required this.platform,
    required this.type,
    required this.content,
    required this.sender,
    required this.recipient,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      integrationId: map['integrationId'] as String,
      conversationId: map['conversationId'] as String,
      platform: MessagePlatform.fromString(map['platform'] as String),
      type: MessageType.fromString(map['content']?['type'] as String? ??
          'text'), // Backend stores type in content
      content:
          MessageContent.fromMap(map['content'] as Map<String, dynamic>? ?? {}),
      sender: MessageSender.fromMap(map['sender'] as Map<String, dynamic>),
      recipient:
          MessageRecipient.fromMap(map['recipient'] as Map<String, dynamic>),
      metadata: MessageMetadata.fromMap(
          map['metadata'] as Map<String, dynamic>? ?? {}),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt'] as String))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(map['updatedAt'] as String))
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'integrationId': integrationId,
      'conversationId': conversationId,
      'platform': platform.value,
      'messageType': type.value,
      'content': content.toMap(),
      'sender': sender.toMap(),
      'recipient': recipient.toMap(),
      'metadata': metadata.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Message copyWith({
    String? id,
    String? businessId,
    String? integrationId,
    String? conversationId,
    MessagePlatform? platform,
    MessageType? type,
    MessageContent? content,
    MessageSender? sender,
    MessageRecipient? recipient,
    MessageMetadata? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Message(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      integrationId: integrationId ?? this.integrationId,
      conversationId: conversationId ?? this.conversationId,
      platform: platform ?? this.platform,
      type: type ?? this.type,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      recipient: recipient ?? this.recipient,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Customer details stored at conversation level
class CustomerDetails {
  final String name;
  final String? profilePic;
  final DateTime? lastUpdated;

  CustomerDetails({
    required this.name,
    this.profilePic,
    this.lastUpdated,
  });

  factory CustomerDetails.fromMap(Map<String, dynamic> map) {
    return CustomerDetails(
      name: map['name'] as String,
      profilePic: map['profilePic'] as String?,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] is Timestamp
              ? (map['lastUpdated'] as Timestamp).toDate()
              : DateTime.parse(map['lastUpdated'] as String))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'profilePic': profilePic,
      'lastUpdated':
          lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : null,
    };
  }
}

/// Conversation model that groups related messages
class Conversation {
  final String id;
  final String businessId;
  final String integrationId;
  final MessagePlatform platform;
  final ConversationType type;
  final String threadId;
  final List<ConversationParticipant> participants;
  final ConversationMetadata metadata;
  final DateTime lastMessageAt;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final int unreadCount;
  final bool isArchived;
  final bool isPinned;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CustomerDetails? customerDetails; // NEW: Customer details from backend

  Conversation({
    required this.id,
    required this.businessId,
    required this.integrationId,
    required this.platform,
    required this.type,
    required this.threadId,
    required this.participants,
    required this.metadata,
    required this.lastMessageAt,
    this.lastMessageId,
    this.lastMessagePreview,
    required this.unreadCount,
    this.isArchived = false,
    this.isPinned = false,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.customerDetails, // NEW: Customer details from backend
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      integrationId: map['integrationId'] as String,
      platform: MessagePlatform.fromString(map['platform'] as String),
      type: ConversationType.fromString(map['type'] as String? ??
          'direct'), // Default to direct if not specified
      threadId: map['threadId'] as String? ??
          map['id'] as String, // Use conversation ID if threadId not present
      participants: (map['participants'] as List<dynamic>?)
              ?.map((p) =>
                  ConversationParticipant.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: map['metadata'] != null
          ? ConversationMetadata.fromMap(
              map['metadata'] as Map<String, dynamic>)
          : ConversationMetadata(), // Provide default metadata if not present
      lastMessageAt: map['lastMessageAt'] != null
          ? (map['lastMessageAt'] is Timestamp
              ? (map['lastMessageAt'] as Timestamp).toDate()
              : DateTime.parse(map['lastMessageAt'] as String))
          : DateTime.now(), // Default to now if not present
      lastMessageId: map['lastMessageId'] as String?,
      lastMessagePreview: map['lastMessagePreview'] as String?,
      unreadCount: map['unreadCount'] as int? ?? 0,
      isArchived: map['isArchived'] as bool? ?? false,
      isPinned: map['isPinned'] as bool? ?? false,
      tags: List<String>.from(map['tags'] as List<dynamic>? ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.parse(map['createdAt'] as String))
          : DateTime.now(), // Default to now if not present
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(map['updatedAt'] as String))
          : DateTime.now(), // Default to now if not present
      customerDetails: map['customerDetails'] != null
          ? CustomerDetails.fromMap(
              map['customerDetails'] as Map<String, dynamic>)
          : null, // NEW: Handle customer details from backend
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'integrationId': integrationId,
      'platform': platform.value,
      'type': type.value,
      'threadId': threadId,
      'participants': participants.map((p) => p.toMap()).toList(),
      'metadata': metadata.toMap(),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'lastMessageId': lastMessageId,
      'lastMessagePreview': lastMessagePreview,
      'unreadCount': unreadCount,
      'isArchived': isArchived,
      'isPinned': isPinned,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'customerDetails':
          customerDetails?.toMap(), // NEW: Include customer details
    };
  }
}

/// Platform enumeration for multi-platform support
enum MessagePlatform {
  facebook('facebook', 'Facebook', '📘'),
  instagram('instagram', 'Instagram', '📸'),
  messenger('messenger', 'Messenger', '💬'),
  whatsapp('whatsapp', 'WhatsApp', '📱'),
  tiktok('tiktok', 'TikTok', '🎵'),
  youtube('youtube', 'YouTube', '📺'),
  email('email', 'Email', '📧'),
  sms('sms', 'SMS', '💬'),
  website('website', 'Website', '🌐'),
  phone('phone', 'Phone', '📞');

  const MessagePlatform(this.value, this.displayName, this.icon);

  final String value;
  final String displayName;
  final String icon;

  static MessagePlatform fromString(String value) {
    return MessagePlatform.values.firstWhere(
      (platform) => platform.value == value,
      orElse: () => MessagePlatform.website,
    );
  }
}

/// Message type enumeration
enum MessageType {
  text('text', 'Text Message'),
  image('image', 'Image'),
  video('video', 'Video'),
  audio('audio', 'Audio'),
  file('file', 'File'),
  location('location', 'Location'),
  contact('contact', 'Contact'),
  postback('postback', 'Button Click'),
  quickReply('quick_reply', 'Quick Reply'),
  comment('comment', 'Comment'),
  mention('mention', 'Mention'),
  reaction('reaction', 'Reaction'),
  story('story', 'Story'),
  post('post', 'Post'),
  review('review', 'Review'),
  lead('lead', 'Lead'),
  order('order', 'Order'),
  booking('booking', 'Booking'),
  system('system', 'System Message');

  const MessageType(this.value, this.displayName);

  final String value;
  final String displayName;

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => MessageType.text,
    );
  }
}

/// Conversation type enumeration
enum ConversationType {
  direct('direct', 'Direct Message'),
  group('group', 'Group Chat'),
  broadcast('broadcast', 'Broadcast'),
  support('support', 'Support Ticket'),
  sales('sales', 'Sales Inquiry'),
  feedback('feedback', 'Feedback'),
  complaint('complaint', 'Complaint'),
  lead('lead', 'Lead Generation'),
  social('social', 'Social Media');

  const ConversationType(this.value, this.displayName);

  final String value;
  final String displayName;

  static ConversationType fromString(String value) {
    return ConversationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ConversationType.direct,
    );
  }
}

/// Message content with support for different media types
class MessageContent {
  final String? text;
  final List<MessageAttachment> attachments;
  final MessageLocation? location;
  final MessageContact? contact;
  final MessagePostback? postback;
  final MessageQuickReply? quickReply;
  final Map<String, dynamic>? metadata;

  MessageContent({
    this.text,
    this.attachments = const [],
    this.location,
    this.contact,
    this.postback,
    this.quickReply,
    this.metadata,
  });

  factory MessageContent.fromMap(Map<String, dynamic> map) {
    // Handle both frontend format (attachments array) and backend format (data object)
    List<MessageAttachment> attachments = [];

    if (map['attachments'] != null) {
      // Frontend format: direct attachments array
      attachments = (map['attachments'] as List<dynamic>)
          .map((a) => MessageAttachment.fromMap(a as Map<String, dynamic>))
          .toList();
    } else if (map['data'] != null) {
      // Backend format: data object with attachment_X keys
      final data = map['data'] as Map<String, dynamic>;
      attachments = data.entries
          .where((entry) => entry.key.startsWith('attachment_'))
          .map((entry) {
        final attData = entry.value as Map<String, dynamic>;
        return MessageAttachment(
          type: attData['type'] as String? ?? 'file',
          url: attData['url'] as String? ?? '',
          filename: attData['filename'] as String?,
          mimeType: attData['mimeType'] as String?,
        );
      }).toList();
    }

    return MessageContent(
      text: map['text'] as String?,
      attachments: attachments,
      location: map['location'] != null
          ? MessageLocation.fromMap(map['location'] as Map<String, dynamic>)
          : null,
      contact: map['contact'] != null
          ? MessageContact.fromMap(map['contact'] as Map<String, dynamic>)
          : null,
      postback: map['postback'] != null
          ? MessagePostback.fromMap(map['postback'] as Map<String, dynamic>)
          : null,
      quickReply: map['quickReply'] != null
          ? MessageQuickReply.fromMap(map['quickReply'] as Map<String, dynamic>)
          : null,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'location': location?.toMap(),
      'contact': contact?.toMap(),
      'postback': postback?.toMap(),
      'quickReply': quickReply?.toMap(),
      'metadata': metadata,
    };
  }

  MessageContent copyWith({
    String? text,
    List<MessageAttachment>? attachments,
    MessageLocation? location,
    MessageContact? contact,
    MessagePostback? postback,
    MessageQuickReply? quickReply,
    Map<String, dynamic>? metadata,
  }) {
    return MessageContent(
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      location: location ?? this.location,
      contact: contact ?? this.contact,
      postback: postback ?? this.postback,
      quickReply: quickReply ?? this.quickReply,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Message attachment model
class MessageAttachment {
  final String type;
  final String url;
  final String? filename;
  final int? size;
  final String? mimeType;
  final String? thumbnailUrl;
  final Map<String, dynamic>? metadata;

  // Progress tracking fields for upload
  final double? uploadProgress; // 0.0 to 1.0
  final bool isUploading;
  final String? localPath; // Local file path for preview before upload

  MessageAttachment({
    required this.type,
    required this.url,
    this.filename,
    this.size,
    this.mimeType,
    this.thumbnailUrl,
    this.metadata,
    this.uploadProgress,
    this.isUploading = false,
    this.localPath,
  });

  factory MessageAttachment.fromMap(Map<String, dynamic> map) {
    return MessageAttachment(
      type: map['type'] as String,
      url: map['url'] as String,
      filename: map['filename'] as String?,
      size: map['size'] as int?,
      mimeType: map['mimeType'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      // These fields are not stored in Firestore
      uploadProgress: null,
      isUploading: false,
      localPath: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'url': url,
      'filename': filename,
      'size': size,
      'mimeType': mimeType,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata,
      // Don't include upload progress in Firestore
    };
  }

  MessageAttachment copyWith({
    String? type,
    String? url,
    String? filename,
    int? size,
    String? mimeType,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
    double? uploadProgress,
    bool? isUploading,
    String? localPath,
  }) {
    return MessageAttachment(
      type: type ?? this.type,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isUploading: isUploading ?? this.isUploading,
      localPath: localPath ?? this.localPath,
    );
  }
}

/// Message sender information
class MessageSender {
  final String id;
  final String? name;
  final String? username;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final bool isCustomer;
  final Map<String, dynamic>? metadata;

  MessageSender({
    required this.id,
    this.name,
    this.username,
    this.email,
    this.phone,
    this.avatarUrl,
    this.isCustomer = true,
    this.metadata,
  });

  factory MessageSender.fromMap(Map<String, dynamic> map) {
    // Handle backend's 'type' field vs frontend's 'isCustomer' field
    bool isCustomer = map['isCustomer'] as bool? ?? true;
    if (map['type'] != null) {
      isCustomer = (map['type'] as String) == 'customer';
    }

    return MessageSender(
      id: map['id'] as String,
      name: map['name'] as String?,
      username: map['username'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      isCustomer: isCustomer,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'isCustomer': isCustomer,
      'metadata': metadata,
    };
  }
}

/// Message recipient information
class MessageRecipient {
  final String id;
  final String? name;
  final String? username;
  final Map<String, dynamic>? metadata;

  MessageRecipient({
    required this.id,
    this.name,
    this.username,
    this.metadata,
  });

  factory MessageRecipient.fromMap(Map<String, dynamic> map) {
    return MessageRecipient(
      id: map['id'] as String,
      name: map['name'] as String?,
      username: map['username'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'metadata': metadata,
    };
  }
}

/// Message metadata for tracking and processing
class MessageMetadata {
  final int timestamp;
  final String source;
  final bool isRead;
  final DateTime? readAt; // NEW FIELD - when message was read
  final bool isReplied;
  final MessagePriority priority;
  final List<String> tags;
  final String? externalId;
  final Map<String, dynamic>? rawPayload;
  final MessageStatus status; // NEW FIELD - message delivery status

  MessageMetadata({
    required this.timestamp,
    required this.source,
    this.isRead = false,
    this.readAt, // NEW FIELD
    this.isReplied = false,
    this.priority = MessagePriority.normal,
    this.tags = const [],
    this.externalId,
    this.rawPayload,
    this.status = MessageStatus.sent, // Default to sent for existing messages
  });

  factory MessageMetadata.fromMap(Map<String, dynamic> map) {
    // Handle backend's timestamp structure
    int timestamp;
    if (map['timestamp'] is int) {
      timestamp = map['timestamp'] as int;
    } else if (map['timestamp'] is DateTime) {
      timestamp = (map['timestamp'] as DateTime).millisecondsSinceEpoch;
    } else {
      timestamp = DateTime.now().millisecondsSinceEpoch;
    }

    // Handle backend's platformData structure
    String source = 'unknown';
    Map<String, dynamic>? rawPayload;

    if (map['platformData'] != null) {
      final platformData = map['platformData'] as Map<String, dynamic>;
      source = platformData['source'] as String? ?? 'unknown';
      rawPayload = platformData['rawPayload'] as Map<String, dynamic>?;
    } else {
      source = map['source'] as String? ?? 'unknown';
      rawPayload = map['rawPayload'] as Map<String, dynamic>?;
    }

    return MessageMetadata(
      timestamp: timestamp,
      source: source,
      isRead: map['isRead'] as bool? ?? false,
      readAt: map['readAt'] != null
          ? (map['readAt'] is Timestamp
              ? (map['readAt'] as Timestamp).toDate()
              : DateTime.parse(map['readAt'] as String))
          : null,
      isReplied: map['isReplied'] as bool? ?? false,
      priority:
          MessagePriority.fromString(map['priority'] as String? ?? 'normal'),
      tags: List<String>.from(map['tags'] as List<dynamic>? ?? []),
      externalId: map['externalId'] as String? ??
          map['platformMessageId'] as String?, // Backend uses platformMessageId
      rawPayload: rawPayload,
      status: MessageStatus.fromString(map['status'] as String? ?? 'sent'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'source': source,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'isReplied': isReplied,
      'status': status.value,
      'priority': priority.value,
      'tags': tags,
      'externalId': externalId,
      'rawPayload': rawPayload,
    };
  }

  MessageMetadata copyWith({
    int? timestamp,
    String? source,
    bool? isRead,
    DateTime? readAt,
    bool? isReplied,
    MessagePriority? priority,
    List<String>? tags,
    String? externalId,
    Map<String, dynamic>? rawPayload,
    MessageStatus? status,
  }) {
    return MessageMetadata(
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isReplied: isReplied ?? this.isReplied,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
      externalId: externalId ?? this.externalId,
      rawPayload: rawPayload ?? this.rawPayload,
      status: status ?? this.status,
    );
  }
}

/// Message priority enumeration
enum MessagePriority {
  low('low', 'Low'),
  normal('normal', 'Normal'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const MessagePriority(this.value, this.displayName);

  final String value;
  final String displayName;

  static MessagePriority fromString(String value) {
    return MessagePriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => MessagePriority.normal,
    );
  }
}

/// Message status enumeration for delivery tracking
enum MessageStatus {
  sending('sending', 'Sending', 'Message is being sent'),
  sent('sent', 'Sent', 'Message sent to server'),
  delivered('delivered', 'Delivered', 'Message delivered to recipient'),
  read('read', 'Read', 'Message read by recipient'),
  failed('failed', 'Failed', 'Failed to send message');

  const MessageStatus(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  static MessageStatus fromString(String value) {
    return MessageStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => MessageStatus.sent,
    );
  }
}

/// Additional supporting classes for specialized message content
class MessageLocation {
  final double latitude;
  final double longitude;
  final String? address;
  final String? name;

  MessageLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.name,
  });

  factory MessageLocation.fromMap(Map<String, dynamic> map) {
    return MessageLocation(
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      address: map['address'] as String?,
      name: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'name': name,
    };
  }
}

class MessageContact {
  final String? name;
  final String? phone;
  final String? email;

  MessageContact({this.name, this.phone, this.email});

  factory MessageContact.fromMap(Map<String, dynamic> map) {
    return MessageContact(
      name: map['name'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
    };
  }
}

class MessagePostback {
  final String payload;
  final String? title;

  MessagePostback({required this.payload, this.title});

  factory MessagePostback.fromMap(Map<String, dynamic> map) {
    return MessagePostback(
      payload: map['payload'] as String,
      title: map['title'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'payload': payload,
      'title': title,
    };
  }
}

class MessageQuickReply {
  final String payload;
  final String text;

  MessageQuickReply({required this.payload, required this.text});

  factory MessageQuickReply.fromMap(Map<String, dynamic> map) {
    return MessageQuickReply(
      payload: map['payload'] as String,
      text: map['text'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'payload': payload,
      'text': text,
    };
  }
}

/// Conversation participant information
class ConversationParticipant {
  final String id;
  final String? name;
  final String? role;
  final bool isActive;

  ConversationParticipant({
    required this.id,
    this.name,
    this.role,
    this.isActive = true,
  });

  factory ConversationParticipant.fromMap(Map<String, dynamic> map) {
    return ConversationParticipant(
      id: map['id'] as String,
      name: map['name'] as String?,
      role: map['role'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'isActive': isActive,
    };
  }
}

/// Conversation metadata
class ConversationMetadata {
  final String? sourcePostId;
  final String? sourceVideoId;
  final String? sourceChannelId;
  final Map<String, dynamic>? customFields;

  ConversationMetadata({
    this.sourcePostId,
    this.sourceVideoId,
    this.sourceChannelId,
    this.customFields,
  });

  factory ConversationMetadata.fromMap(Map<String, dynamic> map) {
    return ConversationMetadata(
      sourcePostId: map['sourcePostId'] as String?,
      sourceVideoId: map['sourceVideoId'] as String?,
      sourceChannelId: map['sourceChannelId'] as String?,
      customFields: map['customFields'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sourcePostId': sourcePostId,
      'sourceVideoId': sourceVideoId,
      'sourceChannelId': sourceChannelId,
      'customFields': customFields,
    };
  }
}

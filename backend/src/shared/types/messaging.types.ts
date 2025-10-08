/**
 * Shared messaging interfaces for unified messaging across all platforms
 * These interfaces provide a consistent structure for messages and conversations
 * regardless of the underlying platform (WhatsApp, Messenger, Instagram, etc.)
 */

export interface BaseMessage {
  id: string;
  conversationId: string;
  integrationId: string;
  businessId: string;
  
  // Message content
  content: string;
  messageType: MessageType;
  
  // Participants
  senderId: string;
  senderName?: string;
  senderType: SenderType;
  recipientId: string;
  recipientName?: string;
  
  // Timestamps
  createdAt: string; // ISO string
  updatedAt: string; // ISO string
  
  // Read status - NEW FIELDS
  isRead: boolean;
  readAt?: string; // ISO string - when message was read
  
  // Platform-specific data
  platformId: string; // Platform's native message ID
  platformName: string; // e.g., 'messenger', 'whatsapp', 'instagram'
  
  // Attachments and media
  attachments?: MessageAttachment[];
  
  // Message status
  status: MessageStatus;
  
  // Metadata
  metadata?: Record<string, any>;
}

export interface BaseConversation {
  id: string;
  integrationId: string;
  businessId: string;
  
  // Conversation participants
  participants: ConversationParticipant[];
  
  // Conversation metadata
  title?: string;
  description?: string;
  
  // Timestamps
  createdAt: string; // ISO string
  updatedAt: string; // ISO string
  lastMessageAt?: string; // ISO string
  
  // Read status - NEW FIELDS
  isRead: boolean; // Whether the conversation has been read by business
  readAt?: string; // ISO string - when conversation was last read by business
  
  // Message counts
  messageCount: number;
  unreadCount: number; // Messages not read by business
  
  // Platform-specific data
  platformId: string; // Platform's native conversation ID
  platformName: string; // e.g., 'messenger', 'whatsapp', 'instagram'
  
  // Status and tags
  status: ConversationStatus;
  tags?: string[];
  
  // Assignment
  assignedTo?: string; // User ID
  assignedAt?: string; // ISO string
  
  // Last message preview
  lastMessage?: BaseMessage;
  
  // Metadata
  metadata?: Record<string, any>;
}

export interface ConversationParticipant {
  id: string;
  name?: string;
  type: ParticipantType;
  platformId: string;
  metadata?: Record<string, any>;
}

export interface MessageAttachment {
  id: string;
  type: AttachmentType;
  url: string;
  filename?: string;
  mimeType?: string;
  size?: number;
  thumbnail?: string;
  metadata?: Record<string, any>;
}

// Enums
export enum MessageType {
  TEXT = 'text',
  IMAGE = 'image',
  VIDEO = 'video',
  AUDIO = 'audio',
  DOCUMENT = 'document',
  LOCATION = 'location',
  CONTACT = 'contact',
  STICKER = 'sticker',
  TEMPLATE = 'template',
  SYSTEM = 'system',
}

export enum SenderType {
  CUSTOMER = 'customer',
  BUSINESS = 'business',
  SYSTEM = 'system',
}

export enum MessageStatus {
  SENT = 'sent',
  DELIVERED = 'delivered',
  READ = 'read',
  FAILED = 'failed',
  PENDING = 'pending',
}

export enum ConversationStatus {
  ACTIVE = 'active',
  ARCHIVED = 'archived',
  CLOSED = 'closed',
  SPAM = 'spam',
}

export enum ParticipantType {
  CUSTOMER = 'customer',
  BUSINESS = 'business',
  AGENT = 'agent',
}

export enum AttachmentType {
  IMAGE = 'image',
  VIDEO = 'video',
  AUDIO = 'audio',
  DOCUMENT = 'document',
  LOCATION = 'location',
  CONTACT = 'contact',
}

// Request/Response interfaces for API endpoints
export interface CreateMessageRequest {
  conversationId: string;
  integrationId: string;
  content: string;
  messageType: MessageType;
  recipientId: string;
  attachments?: Omit<MessageAttachment, 'id'>[];
  metadata?: Record<string, any>;
}

export interface UpdateMessageReadStatusRequest {
  messageId: string;
  isRead: boolean;
  readAt?: string;
}

export interface UpdateConversationReadStatusRequest {
  conversationId: string;
  isRead: boolean;
  readAt?: string;
}

export interface MessagesListResponse {
  messages: BaseMessage[];
  pagination?: {
    page: number;
    limit: number;
    total: number;
    hasNext: boolean;
    hasPrev: boolean;
  };
}

export interface ConversationsListResponse {
  conversations: BaseConversation[];
  pagination?: {
    page: number;
    limit: number;
    total: number;
    hasNext: boolean;
    hasPrev: boolean;
  };
}

// Filters for querying
export interface MessagesFilter {
  conversationId?: string;
  integrationId?: string;
  businessId?: string;
  senderId?: string;
  messageType?: MessageType;
  status?: MessageStatus;
  isRead?: boolean;
  fromDate?: string;
  toDate?: string;
  search?: string;
}

export interface ConversationsFilter {
  integrationId?: string;
  businessId?: string;
  status?: ConversationStatus;
  isRead?: boolean;
  assignedTo?: string;
  hasUnread?: boolean;
  tags?: string[];
  fromDate?: string;
  toDate?: string;
  search?: string;
}
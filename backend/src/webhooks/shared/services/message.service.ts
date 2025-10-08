import { Injectable, Logger } from '@nestjs/common';
import { FirestoreService } from '../../../firebase/firestore.service';
import * as admin from 'firebase-admin';
import axios from 'axios';
import { 
  BaseMessage, 
  BaseConversation, 
  MessageType, 
  SenderType, 
  MessageStatus, 
  ConversationStatus, 
  ParticipantType,
  CreateMessageRequest,
  UpdateMessageReadStatusRequest,
  UpdateConversationReadStatusRequest,
  ConversationParticipant
} from '../../../shared/types/messaging.types';

/**
 * MessageService - 3-Tier Flat Collection Structure
 * 
 * This service handles saving and managing messages using a performance-optimized
 * flat collection structure that matches the frontend expectations:
 * 
 * Tier 1: integrations/{integrationId} - Contains messaging stats (updated on each new message)
 * Tier 2: conversations/{conversationId} - Conversation headers/metadata  
 * Tier 3: messages/{messageId} - Individual messages
 * 
 * This replaces the nested collection approach with a flat structure for
 * better performance, lower costs, and easier cross-conversation queries.
 */
@Injectable()
export class MessageService {
  private readonly logger = new Logger(MessageService.name);
  private customerCache = new Map<string, { name: string; profilePic?: string; timestamp: number }>();
  private readonly CACHE_TTL = 60 * 60 * 1000; // 1 hour cache

  constructor(private readonly firestoreService: FirestoreService) {}

  /**
   * Clean data for Firestore by removing undefined values recursively
   */
  private cleanFirestoreData(obj: any): any {
    if (obj === null || obj === undefined) {
      return null;
    }
    
    if (Array.isArray(obj)) {
      return obj.map(item => this.cleanFirestoreData(item)).filter(item => item !== null && item !== undefined);
    }
    
    if (typeof obj === 'object' && obj.constructor === Object) {
      const cleaned: any = {};
      for (const [key, value] of Object.entries(obj)) {
        const cleanedValue = this.cleanFirestoreData(value);
        if (cleanedValue !== null && cleanedValue !== undefined) {
          cleaned[key] = cleanedValue;
        }
      }
      return cleaned;
    }
    
    return obj;
  }

  /**
   * Fetch customer details from Facebook/Instagram Graph API with caching
   */
  private async fetchCustomerDetails(senderId: string, pageAccessToken: string, platform: string = 'messenger'): Promise<{ name: string; profilePic?: string } | null> {
    try {
      // Check cache first
      const cached = this.customerCache.get(senderId);
      if (cached && (Date.now() - cached.timestamp) < this.CACHE_TTL) {
        this.logger.log(`� [MessageService] Using cached customer details for: ${senderId}`);
        return { name: cached.name, profilePic: cached.profilePic };
      }

      this.logger.log(`�👤 [MessageService] Fetching customer details for sender ID: ${senderId}`);
      
      
      let apiUrl: string;
      let fields: string;

      if (platform === 'instagram') {
        // For Instagram, we need to get the Instagram user details
        apiUrl = `https://graph.facebook.com/v21.0/${senderId}`;
        fields = 'name,username,profile_picture_url'; // Instagram fields
      } else {
        // For Facebook/Messenger
        apiUrl = `https://graph.facebook.com/v21.0/${senderId}`;
        fields = 'first_name,last_name,profile_pic'; // Facebook fields
      }

      const response = await axios.get(apiUrl, {
        params: {
          fields: fields,
          access_token: pageAccessToken
        },
        timeout: 5000 // 5 second timeout to avoid blocking webhook processing
      });

      const customerData = response.data;
      let customerName: string;
      let profilePicUrl: string | undefined;

      if (platform === 'instagram') {
        // Instagram API response format
        customerName = customerData.name || customerData.username || 'Instagram User';
        profilePicUrl = customerData.profile_picture_url;
      } else {
        // Facebook/Messenger API response format
        customerName = `${customerData.first_name || ''} ${customerData.last_name || ''}`.trim();
        profilePicUrl = customerData.profile_pic;
      }
      
      const customerDetails = {
        name: customerName || 'Customer',
        profilePic: profilePicUrl
      };

      // Cache the result with platform-specific key
      const cacheKey = `${platform}_${senderId}`;
      this.customerCache.set(cacheKey, {
        ...customerDetails,
        timestamp: Date.now()
      });
      
      this.logger.log(`✅ [MessageService] ${platform} customer details fetched and cached: ${customerName}`);
      return customerDetails;
    } catch (error) {
      this.logger.warn(`⚠️ [MessageService] Failed to fetch ${platform} customer details for ${senderId}:`, error.message);
      return null;
    }
  }

  /**
   * Get page access token for an integration (supports both Facebook and Instagram)
   */
  private async getPageAccessToken(integrationId: string): Promise<string | null> {
    try {
      const integration = await this.firestoreService.getDocument('integrations', integrationId);
      
      // For Facebook/Messenger integrations
      if (integration?.credentials?.pageInfo?.accessToken) {
        return integration.credentials.pageInfo.accessToken;
      }
      
      // For Instagram integrations or direct access tokens
      if (integration?.credentials?.accessToken) {
        return integration.credentials.accessToken;
      }

      // For Instagram business accounts connected via Facebook Page
      if (integration?.credentials?.pageInfo?.instagramBusinessAccount?.accessToken) {
        return integration.credentials.pageInfo.instagramBusinessAccount.accessToken;
      }
      
      this.logger.warn(`⚠️ [MessageService] No access token found for integration: ${integrationId}`);
      return null;
    } catch (error) {
      this.logger.error(`❌ [MessageService] Error getting access token for integration ${integrationId}:`, error);
      return null;
    }
  }

  /**
   * Save a message from webhook events using 3-tier flat structure
   */
  async saveWebhookMessage(webhookData: {
    messageId: string;
    businessId: string;
    integrationId: string;
    platform: string;
    messageType: string;
    content: {
      text?: string;
      attachments?: Array<{
        type: string;
        url: string;
        payload?: any;
      }>;
    };
    sender: {
      id: string;
      name?: string;
      username?: string;
    };
    recipient: {
      id: string;
      name?: string;
    };
    conversation: {
      threadId: string;
      pageId?: string;
      postId?: string;
    };
    metadata: {
      timestamp: number;
      source: string;
      rawPayload?: any;
      isRead?: boolean;
      isReplied?: boolean;
    };
  }): Promise<string> {
    const saveStartTime = Date.now();
    this.logger.log(`💾 [MessageService] Starting webhook message save for business ${webhookData.businessId}, integration ${webhookData.integrationId}`);
    this.logger.debug(`💾 [MessageService] Webhook data: ${JSON.stringify(webhookData, null, 2)}`);

    try {
      // Validate required fields
      if (!webhookData.messageId || !webhookData.businessId || !webhookData.integrationId) {
        this.logger.error(`❌ [MessageService] Missing required fields: messageId=${webhookData.messageId}, businessId=${webhookData.businessId}, integrationId=${webhookData.integrationId}`);
        throw new Error('Missing required fields for webhook message');
      }

      // Fetch customer details from Facebook/Instagram API for better UX
      let customerDetails = null;
      const pageAccessToken = await this.getPageAccessToken(webhookData.integrationId);
      if (pageAccessToken && webhookData.sender.id) {
        customerDetails = await this.fetchCustomerDetails(
          webhookData.sender.id, 
          pageAccessToken, 
          webhookData.platform
        );
      }

      // Use fetched customer name or fallback to provided/default values
      const customerName = customerDetails?.name || 
                          webhookData.sender.name || 
                          webhookData.sender.username || 
                          'Customer';

      // Transform to frontend-compatible message format
      this.logger.log(`🔄 [MessageService] Transforming webhook data to frontend-compatible format`);
      const frontendMessage = {
        id: webhookData.messageId,
        conversationId: webhookData.conversation.threadId,
        businessId: webhookData.businessId,
        integrationId: webhookData.integrationId,
        content: {
          text: webhookData.content.text || '',
          type: this.mapToMessageType(webhookData.messageType),
          data: webhookData.content.attachments?.reduce((acc, att, index) => {
            acc[`attachment_${index}`] = {
              type: att.type,
              url: att.url,
              filename: att.payload?.name,
              mimeType: att.payload?.type
            };
            return acc;
          }, {} as Record<string, any>) || {}
        },
        sender: {
          id: webhookData.sender.id,
          type: this.determineSenderType(webhookData.sender.id, webhookData.recipient.id)
        },
        recipient: {
          id: webhookData.recipient.id,
          type: 'business'
        },
        platform: webhookData.platform,
        timestamp: new Date(webhookData.metadata.timestamp),
        createdAt: new Date(webhookData.metadata.timestamp),
        metadata: {
          isRead: false,
          readAt: null,
          priority: 'normal',
          platformMessageId: webhookData.messageId,
          platformData: {
            source: webhookData.metadata.source,
            rawPayload: webhookData.metadata.rawPayload
          }
        }
      };

      this.logger.log(`💾 [MessageService] Frontend message transformed, saving to messages collection`);
      this.logger.debug(`💾 [MessageService] Frontend message: ${JSON.stringify(frontendMessage, null, 2)}`);

      // Tier 3: Save message to flat messages collection (clean data first)
      const cleanedMessage = this.cleanFirestoreData(frontendMessage);
      await this.firestoreService.createDocument('messages', cleanedMessage, webhookData.messageId);
      this.logger.log(`✅ [MessageService] Message saved to flat structure: ${webhookData.messageId}`);

      // Tier 2: Update or create conversation with customer details
      this.logger.log(`🔄 [MessageService] Updating/creating conversation: ${webhookData.conversation.threadId}`);
      await this.updateOrCreateConversation(webhookData.conversation.threadId, {
        integrationId: webhookData.integrationId,
        businessId: webhookData.businessId,
        platformName: webhookData.platform,
        participants: [
          {
            id: webhookData.sender.id,
            name: customerName, // Use the fetched customer name
            type: ParticipantType.CUSTOMER,
            platformId: webhookData.sender.id,
          },
          {
            id: webhookData.recipient.id,
            name: webhookData.recipient.name || 'Business',
            type: ParticipantType.BUSINESS,
            platformId: webhookData.recipient.id,
          },
        ],
        lastMessage: frontendMessage,
        customerDetails: customerDetails, // Store full customer details at conversation level
      });

      // Tier 1: Update integration messaging stats (CRITICAL - this updates stats on each new message)
      this.logger.log(`📊 [MessageService] Updating integration messaging stats for: ${webhookData.integrationId}`);
      await this.updateIntegrationMessagingStats(webhookData.integrationId, frontendMessage);

      const saveTime = Date.now() - saveStartTime;
      this.logger.log(`✅ [MessageService] Webhook message processing completed successfully in ${saveTime}ms`);
      return webhookData.messageId;
    } catch (error) {
      const saveTime = Date.now() - saveStartTime;
      this.logger.error(`❌ [MessageService] Failed to save webhook message after ${saveTime}ms:`, error);
      this.logger.error(`📋 [MessageService] Failed webhook data: ${JSON.stringify(webhookData, null, 2)}`);
      throw error;
    }
  }

  /**
   * Update or create a conversation using flat collection structure (Tier 2)
   */
  private async updateOrCreateConversation(
    conversationId: string,
    data: {
      integrationId: string;
      businessId: string;
      platformName: string;
      participants: ConversationParticipant[];
      lastMessage: any;
      customerDetails?: { name: string; profilePic?: string } | null;
    }
  ): Promise<void> {
    try {
      const existingConversation = await this.firestoreService.getDocument('conversations', conversationId);
      const now = new Date();

      if (existingConversation) {
        // Update existing conversation with frontend-compatible structure
        const updatedConversation: any = {
          updatedAt: now,
          lastMessageAt: new Date(data.lastMessage.timestamp || data.lastMessage.createdAt),
          lastMessageId: data.lastMessage.id,
          lastMessagePreview: data.lastMessage.content?.text || 'Media message',
          unreadCount: (existingConversation?.unreadCount || 0) + 1,
          isRead: false,
          readAt: null
        };

        // Update customer details if we have new ones and they're different
        if (data.customerDetails && 
            (!existingConversation.customerDetails || 
             existingConversation.customerDetails.name !== data.customerDetails.name)) {
          updatedConversation.customerDetails = {
            name: data.customerDetails.name,
            profilePic: data.customerDetails.profilePic,
            lastUpdated: now
          };
          updatedConversation.title = `Conversation with ${data.customerDetails.name}`;
          this.logger.log(`Updated customer details for conversation: ${conversationId}`);
        }

        await this.firestoreService.updateDocument('conversations', conversationId, updatedConversation);
        this.logger.log(`Updated conversation: ${conversationId}`);
      } else {
        // Create new conversation with frontend-compatible structure
        const newConversation = {
          id: conversationId,
          businessId: data.businessId,
          integrationId: data.integrationId,
          platform: data.platformName,
          platformConversationId: conversationId,
          participants: data.participants.map(p => ({
            id: p.id,
            name: p.name || 'Unknown',
            role: p.type === ParticipantType.CUSTOMER ? 'customer' : 'business'
          })),
          title: `Conversation with ${data.participants.find(p => p.type === ParticipantType.CUSTOMER)?.name || 'Customer'}`,
          createdAt: now,
          updatedAt: now,
          lastMessageAt: new Date(data.lastMessage.timestamp || data.lastMessage.createdAt),
          lastMessageId: data.lastMessage.id,
          lastMessagePreview: data.lastMessage.content?.text || 'Media message',
          unreadCount: 1,
          isRead: false,
          readAt: null,
          status: 'active',
          tags: [],
          priority: 'normal',
          assignedTo: null,
          isArchived: false,
          isPinned: false,
          metadata: {
            createdFromWebhook: true,
            platform: data.platformName
          },
          // Store customer details at conversation level
          customerDetails: data.customerDetails ? {
            name: data.customerDetails.name,
            profilePic: data.customerDetails.profilePic,
            lastUpdated: now
          } : null
        };

        // Clean the conversation data before saving
        const cleanedConversation = this.cleanFirestoreData(newConversation);
        await this.firestoreService.createDocument('conversations', cleanedConversation, conversationId);
        this.logger.log(`Created new conversation: ${conversationId}`);
      }
    } catch (error) {
      this.logger.error('Failed to update conversation:', error);
      throw error;
    }
  }

  /**
   * Update integration messaging stats (Tier 1) - UPDATES STATS ON EACH NEW MESSAGE
   */
  private async updateIntegrationMessagingStats(
    integrationId: string,
    message: any
  ): Promise<void> {
    try {
      const integration = await this.firestoreService.getDocument('integrations', integrationId);
      
      if (integration) {
        const currentStats = integration.messagingStats || {
          totalNewMessages: 0,
          totalMessageCount: 0,
          lastMessageDate: null,
          lastMessageId: null,
          lastMessagePreview: null
        };

        const updatedStats = {
          totalNewMessages: currentStats.totalNewMessages + 1,
          totalMessageCount: currentStats.totalMessageCount + 1,
          lastMessageDate: new Date(message.timestamp || message.createdAt),
          lastMessageId: message.id,
          lastMessagePreview: message.content?.text || 'Media message',
        };

        await this.firestoreService.updateDocument('integrations', integrationId, {
          messagingStats: updatedStats
        });

        this.logger.log(`Updated messaging stats for integration: ${integrationId}`);
      }
    } catch (error) {
      this.logger.error(`Failed to update integration messaging stats: ${error.message}`);
      // Don't throw error as this is not critical for message saving
    }
  }

  /**
   * Mark messages as read and update readAt timestamp
   */
  async markMessagesAsRead(
    businessId: string,
    requests: UpdateMessageReadStatusRequest[]
  ): Promise<void> {
    try {
      const readTimestamp = new Date();

      // Use batch operations through FirestoreService
      const batchOperations = requests.map(request => ({
        operation: 'update' as const,
        collection: 'messages',
        documentId: request.messageId,
        data: {
          'metadata.isRead': true,
          'metadata.readAt': readTimestamp,
        }
      }));

      await this.firestoreService.batchWrite(batchOperations);
      this.logger.log(`Marked ${requests.length} messages as read for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to mark messages as read:', error);
      throw error;
    }
  }

  /**
   * Update conversation read status
   */
  async updateConversationReadStatus(
    businessId: string,
    request: UpdateConversationReadStatusRequest
  ): Promise<void> {
    try {
      const updateData: any = {
        isRead: request.isRead,
        readAt: request.isRead ? new Date() : null,
      };

      if (request.isRead) {
        updateData.unreadCount = 0;
      }

      await this.firestoreService.updateDocument('conversations', request.conversationId, updateData);

      // If marking conversation as read, also update integration stats
      if (request.isRead) {
        const conversation = await this.firestoreService.getDocument('conversations', request.conversationId);
        const integrationId = conversation?.integrationId;
        const unreadCount = conversation?.unreadCount || 0;
        
        if (integrationId && unreadCount > 0) {
          const integration = await this.firestoreService.getDocument('integrations', integrationId);
          if (integration?.messagingStats) {
            const updatedStats = {
              ...integration.messagingStats,
              totalNewMessages: Math.max(0, (integration.messagingStats.totalNewMessages || 0) - unreadCount),
            };
            
            await this.firestoreService.updateDocument('integrations', integrationId, {
              messagingStats: updatedStats
            });
          }
        }
      }

      this.logger.log(`Updated conversation read status: ${request.conversationId} to ${request.isRead}`);
    } catch (error) {
      this.logger.error('Failed to update conversation read status:', error);
      throw error;
    }
  }

  /**
   * Find business and integration IDs from platform page/account ID
   */
  async findBusinessIntegrationFromPlatformId(
    platformId: string, 
    platform: 'facebook' | 'instagram' | 'messenger' | 'tiktok' | 'youtube'
  ): Promise<{ businessId: string; integrationId: string } | null> {
    const lookupStartTime = Date.now();
    this.logger.log(`🔍 [MessageService] Looking up platform ID ${platformId} for platform ${platform}`);

    try {
      // Query all integrations to find the one with matching platform ID
      // Note: Integration model uses 'channel' field, not 'platform'
      const firestore = this.firestoreService.getFirestore();
      
      // Map platform to channel name used in integration model
      const channelMap = {
        'facebook': 'facebook_pages',
        'instagram': 'instagram', 
        'messenger': 'messenger',
        'tiktok': 'tiktok',
        'youtube': 'youtube'
      };
      
      const channel = channelMap[platform];
      if (!channel) {
        this.logger.warn(`⚠️ [MessageService] Unknown platform: ${platform}`);
        return null;
      }
this.logger.debug(`🔍 [MessageService] Mapped platform ${platform} to channel ${channel}`);
      const integrationsQuery = firestore
        .collectionGroup('integrations')
        .where('platformId', '==', platformId)
        .where('channel', '==', channel)
        .limit(1);

      this.logger.log(`🔍 [MessageService] Executing Firestore query for platformId=${platformId}, channel=${channel}`);
      const snapshot = await integrationsQuery.get();

      if (snapshot.empty) {
        const lookupTime = Date.now() - lookupStartTime;
        this.logger.warn(`⚠️ [MessageService] No integration found for platform ID ${platformId} on channel ${channel} (${lookupTime}ms)`);
        return null;
      }

      const integrationDoc = snapshot.docs[0];
      const integrationData = integrationDoc.data();
      
      // Extract business ID from the document path
      const pathSegments = integrationDoc.ref.path.split('/');
      const businessId = pathSegments[1]; // businesses/{businessId}/integrations/{integrationId}
      const integrationId = integrationDoc.id;

      const lookupTime = Date.now() - lookupStartTime;
      this.logger.log(`✅ [MessageService] Found integration ${integrationId} for business ${businessId} (${lookupTime}ms)`);
      this.logger.debug(`🔍 [MessageService] Integration data: ${JSON.stringify(integrationData, null, 2)}`);
      
      return { businessId, integrationId };
    } catch (error) {
      const lookupTime = Date.now() - lookupStartTime;
      this.logger.error(`❌ [MessageService] Error finding business integration for platform ID ${platformId} after ${lookupTime}ms:`, error);
      return null;
    }
  }

  // Utility methods
  private mapToMessageType(type: string): MessageType {
    switch (type.toLowerCase()) {
      case 'text':
        return MessageType.TEXT;
      case 'image':
        return MessageType.IMAGE;
      case 'video':
        return MessageType.VIDEO;
      case 'audio':
        return MessageType.AUDIO;
      case 'file':
      case 'document':
        return MessageType.DOCUMENT;
      default:
        return MessageType.TEXT;
    }
  }

  private determineSenderType(senderId: string, recipientId: string): SenderType {
    // If sender is the recipient (business replying), it's a business message
    // Otherwise, it's a customer message
    return senderId === recipientId ? SenderType.BUSINESS : SenderType.CUSTOMER;
  }

  /**
   * Get messages for a business (flat collection structure)
   */
  async getMessages(
    businessId: string, 
    options: {
      integrationId?: string;
      conversationId?: string;
      limit?: number;
      cursor?: string;
      unreadOnly?: boolean;
    } = {}
  ): Promise<{ messages: any[]; nextCursor?: string }> {
    try {
      // Use native Firestore for complex queries
      const firestore = this.firestoreService.getFirestore();
      let query = firestore
        .collection('messages')
        .where('businessId', '==', businessId)
        .orderBy('createdAt', 'desc');

      if (options.integrationId) {
        query = query.where('integrationId', '==', options.integrationId);
      }

      if (options.conversationId) {
        query = query.where('conversationId', '==', options.conversationId);
      }

      if (options.unreadOnly) {
        query = query.where('metadata.isRead', '==', false);
      }

      if (options.limit) {
        query = query.limit(options.limit);
      }

      if (options.cursor) {
        const cursorDoc = await firestore
          .doc(`messages/${options.cursor}`)
          .get();
        if (cursorDoc.exists) {
          query = query.startAfter(cursorDoc);
        }
      }

      const snapshot = await query.get();
      const messages = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));

      const nextCursor = snapshot.docs.length > 0 
        ? snapshot.docs[snapshot.docs.length - 1].id 
        : undefined;

      this.logger.log(`Retrieved ${messages.length} messages for business ${businessId}`);
      return { messages, nextCursor };
    } catch (error) {
      this.logger.error('Failed to get messages:', error);
      throw error;
    }
  }

  /**
   * Get unread message count for a business (flat collection structure)
   */
  async getUnreadCount(businessId: string, integrationId?: string): Promise<number> {
    try {
      // Use native Firestore for complex queries
      const firestore = this.firestoreService.getFirestore();
      let query = firestore
        .collection('messages')
        .where('businessId', '==', businessId)
        .where('metadata.isRead', '==', false);

      if (integrationId) {
        query = query.where('integrationId', '==', integrationId);
      }

      const snapshot = await query.count().get();
      const count = snapshot.data().count;
      
      this.logger.log(`Unread count for business ${businessId}: ${count}`);
      return count;
    } catch (error) {
      this.logger.error('Failed to get unread count:', error);
      return 0;
    }
  }
}

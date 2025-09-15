import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirestoreService } from '../firestore/firestore.service';
import axios, { AxiosResponse } from 'axios';
import { 
  WhatsAppMessage, 
  WhatsAppMessageResponse,
  WhatsAppTemplate,
  WhatsAppBusinessProfile,
  WhatsAppAnalytics,
  WhatsAppCredentials,
  WhatsAppIntegrationDocument
} from './types/whatsapp.types';

@Injectable()
export class WhatsAppService {
  private readonly logger = new Logger(WhatsAppService.name);
  private readonly WHATSAPP_API_BASE_URL = 'https://graph.facebook.com/v21.0';

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
  ) {}

  /**
   * Send a WhatsApp message
   */
  async sendMessage(
    integrationId: string,
    to: string,
    message: Partial<WhatsAppMessage>
  ): Promise<WhatsAppMessageResponse> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { access_token, phone_number_id } = integration.credentials;

    try {
      const payload = this.buildMessagePayload(to, message);
      
      const response = await axios.post(
        `${this.WHATSAPP_API_BASE_URL}/${phone_number_id}/messages`,
        payload,
        {
          headers: {
            'Authorization': `Bearer ${access_token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      this.logger.log(`WhatsApp message sent successfully to ${to}`);
      return response.data;
    } catch (error) {
      this.logger.error(`Failed to send WhatsApp message to ${to}:`, error.response?.data || error);
      throw new HttpException(
        `Failed to send WhatsApp message: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Send a template message
   */
  async sendTemplateMessage(
    integrationId: string,
    to: string,
    templateName: string,
    language: string,
    components?: any[]
  ): Promise<WhatsAppMessageResponse> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { access_token, phone_number_id } = integration.credentials;

    try {
      const payload = {
        messaging_product: 'whatsapp',
        to,
        type: 'template',
        template: {
          name: templateName,
          language: {
            code: language,
          },
          components: components || [],
        },
      };

      const response = await axios.post(
        `${this.WHATSAPP_API_BASE_URL}/${phone_number_id}/messages`,
        payload,
        {
          headers: {
            'Authorization': `Bearer ${access_token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      this.logger.log(`WhatsApp template message sent successfully to ${to}`);
      return response.data;
    } catch (error) {
      this.logger.error(`Failed to send WhatsApp template message to ${to}:`, error.response?.data || error);
      throw new HttpException(
        `Failed to send WhatsApp template message: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get message templates
   */
  async getTemplates(integrationId: string): Promise<WhatsAppTemplate[]> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { access_token, business_account_id } = integration.credentials;

    try {
      const response = await axios.get(
        `${this.WHATSAPP_API_BASE_URL}/${business_account_id}/message_templates`,
        {
          headers: {
            'Authorization': `Bearer ${access_token}`,
          },
          params: {
            fields: 'id,name,category,status,language,components',
          },
        }
      );

      this.logger.log(`Retrieved ${response.data.data.length} WhatsApp templates`);
      return response.data.data;
    } catch (error) {
      this.logger.error('Failed to get WhatsApp templates:', error.response?.data || error);
      throw new HttpException(
        `Failed to get WhatsApp templates: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get business profile
   */
  async getBusinessProfile(integrationId: string): Promise<WhatsAppBusinessProfile> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { access_token, phone_number_id } = integration.credentials;

    try {
      const response = await axios.get(
        `${this.WHATSAPP_API_BASE_URL}/${phone_number_id}/whatsapp_business_profile`,
        {
          headers: {
            'Authorization': `Bearer ${access_token}`,
          },
          params: {
            fields: 'about,address,description,email,profile_picture_url,websites,vertical',
          },
        }
      );

      this.logger.log('Retrieved WhatsApp business profile');
      return response.data.data[0];
    } catch (error) {
      this.logger.error('Failed to get WhatsApp business profile:', error.response?.data || error);
      throw new HttpException(
        `Failed to get WhatsApp business profile: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Update business profile
   */
  async updateBusinessProfile(
    integrationId: string,
    profile: Partial<WhatsAppBusinessProfile>
  ): Promise<any> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { access_token, phone_number_id } = integration.credentials;

    try {
      const response = await axios.post(
        `${this.WHATSAPP_API_BASE_URL}/${phone_number_id}/whatsapp_business_profile`,
        {
          messaging_product: 'whatsapp',
          ...profile,
        },
        {
          headers: {
            'Authorization': `Bearer ${access_token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      this.logger.log('Updated WhatsApp business profile');
      return response.data;
    } catch (error) {
      this.logger.error('Failed to update WhatsApp business profile:', error.response?.data || error);
      throw new HttpException(
        `Failed to update WhatsApp business profile: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get analytics data
   */
  async getAnalytics(
    integrationId: string,
    start: string,
    end: string,
    granularity: 'HALF_HOUR' | 'DAY' | 'MONTH' = 'DAY'
  ): Promise<WhatsAppAnalytics> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { access_token, phone_number_id } = integration.credentials;

    try {
      const response = await axios.get(
        `${this.WHATSAPP_API_BASE_URL}/${phone_number_id}/analytics`,
        {
          headers: {
            'Authorization': `Bearer ${access_token}`,
          },
          params: {
            start,
            end,
            granularity,
            metric_types: 'sent,delivered,read,failed',
          },
        }
      );

      this.logger.log('Retrieved WhatsApp analytics');
      return response.data;
    } catch (error) {
      this.logger.error('Failed to get WhatsApp analytics:', error.response?.data || error);
      throw new HttpException(
        `Failed to get WhatsApp analytics: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Upload media for WhatsApp
   */
  async uploadMedia(
    integrationId: string,
    mediaFile: Buffer,
    mimeType: string,
    filename?: string
  ): Promise<{ id: string }> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { access_token, phone_number_id } = integration.credentials;

    try {
      const formData = new FormData();
      formData.append('messaging_product', 'whatsapp');
      // Convert Buffer to Uint8Array for proper Blob creation
      const bufferData = Buffer.isBuffer(mediaFile) ? mediaFile : Buffer.from(mediaFile);
      const uint8Array = new Uint8Array(bufferData);
      const blob = new Blob([uint8Array], { type: mimeType });
      formData.append('file', blob, filename);
      formData.append('type', mimeType);

      const response = await axios.post(
        `${this.WHATSAPP_API_BASE_URL}/${phone_number_id}/media`,
        formData,
        {
          headers: {
            'Authorization': `Bearer ${access_token}`,
            'Content-Type': 'multipart/form-data',
          },
        }
      );

      this.logger.log('Media uploaded to WhatsApp successfully');
      return response.data;
    } catch (error) {
      this.logger.error('Failed to upload media to WhatsApp:', error.response?.data || error);
      throw new HttpException(
        `Failed to upload media to WhatsApp: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Mark message as read
   */
  async markMessageAsRead(integrationId: string, messageId: string): Promise<any> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    const { access_token, phone_number_id } = integration.credentials;

    try {
      const response = await axios.post(
        `${this.WHATSAPP_API_BASE_URL}/${phone_number_id}/messages`,
        {
          messaging_product: 'whatsapp',
          status: 'read',
          message_id: messageId,
        },
        {
          headers: {
            'Authorization': `Bearer ${access_token}`,
            'Content-Type': 'application/json',
          },
        }
      );

      this.logger.log(`Marked WhatsApp message ${messageId} as read`);
      return response.data;
    } catch (error) {
      this.logger.error(`Failed to mark WhatsApp message ${messageId} as read:`, error.response?.data || error);
      throw new HttpException(
        `Failed to mark message as read: ${error.response?.data?.error?.message || error.message}`,
        error.response?.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get conversation list for a WhatsApp Business account
   */
  async getConversations(
    integrationId: string,
    limit: number = 20,
    offset: number = 0
  ): Promise<any> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    try {
      // First get conversations from Firestore as WhatsApp Cloud API doesn't have a direct endpoint for this
      const conversationsSnapshot = await this.firestoreService
        .collection('whatsapp_conversations')
        .where('integrationId', '==', integrationId)
        .orderBy('lastMessageTimestamp', 'desc')
        .limit(limit)
        .offset(offset)
        .get();

      if (conversationsSnapshot.empty) {
        // Return empty results if no conversations found
        return {
          conversations: [],
          pagination: {
            total: 0,
            limit,
            offset,
            has_more: false
          }
        };
      }

      const conversations = [];
      for (const doc of conversationsSnapshot.docs) {
        const conversationData = doc.data();
        conversations.push({
          id: doc.id,
          contact: conversationData.contact,
          last_message: conversationData.lastMessage,
          unread_count: conversationData.unreadCount || 0,
          timestamp: conversationData.lastMessageTimestamp?.toDate() || new Date()
        });
      }

      // Get total count for pagination
      const totalSnapshot = await this.firestoreService
        .collection('whatsapp_conversations')
        .where('integrationId', '==', integrationId)
        .get();

      const totalCount = totalSnapshot.size;

      return {
        conversations,
        pagination: {
          total: totalCount,
          limit,
          offset,
          has_more: offset + limit < totalCount
        }
      };
    } catch (error) {
      this.logger.error(`Failed to get WhatsApp conversations:`, error);
      throw new HttpException(
        `Failed to get conversations: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get messages for a specific WhatsApp conversation
   */
  async getConversationMessages(
    integrationId: string,
    contactId: string,
    limit: number = 50,
    before?: string
  ): Promise<any> {
    const integration = await this.getIntegration(integrationId);
    this.validateIntegration(integration);

    try {
      let query = this.firestoreService
        .collection('whatsapp_messages')
        .where('integrationId', '==', integrationId)
        .where('contactId', '==', contactId)
        .orderBy('timestamp', 'desc')
        .limit(limit);

      // Add timestamp condition for pagination if 'before' is provided
      if (before) {
        const beforeDate = new Date(before);
        // Create a new query with the additional condition
        query = this.firestoreService
          .collection('whatsapp_messages')
          .where('integrationId', '==', integrationId)
          .where('contactId', '==', contactId)
          .where('timestamp', '<', beforeDate)
          .orderBy('timestamp', 'desc')
          .limit(limit);
      }

      const messagesSnapshot = await query.get();

      const messages = messagesSnapshot.docs.map(doc => {
        const messageData = doc.data();
        return {
          id: doc.id,
          timestamp: messageData.timestamp?.toDate() || new Date(),
          type: messageData.type || 'text',
          from: messageData.from,
          text: messageData.text,
          image: messageData.image,
          video: messageData.video,
          document: messageData.document,
          location: messageData.location,
          status: messageData.status || 'delivered'
        };
      });

      // Get the timestamp of the last message for cursor-based pagination
      const lastMessage = messages[messages.length - 1];
      const cursor = lastMessage ? lastMessage.timestamp.toISOString() : null;

      return {
        messages,
        pagination: {
          has_more: messages.length === limit,
          cursor
        }
      };
    } catch (error) {
      this.logger.error(`Failed to get WhatsApp conversation messages:`, error);
      throw new HttpException(
        `Failed to get conversation messages: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Private helper methods
   */
  private async getIntegration(integrationId: string): Promise<WhatsAppIntegrationDocument> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const integrationDoc = await integrationsCollection.doc(integrationId).get();
      
      if (!integrationDoc.exists) {
        this.logger.warn(`Integration not found: ${integrationId}`);
        throw new HttpException('Integration not found', HttpStatus.NOT_FOUND);
      }

      const integration = integrationDoc.data() as WhatsAppIntegrationDocument;
      integration.id = integrationDoc.id;
      
      this.logger.log(`Found integration: ${integrationId} for business: ${integration.businessId}`);
      return integration;
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }
      
      this.logger.error(`Failed to fetch integration ${integrationId}:`, error);
      throw new HttpException(
        'Failed to fetch integration data',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  private validateIntegration(integration: WhatsAppIntegrationDocument): void {
    if (integration.platformId !== 'whatsapp') {
      this.logger.warn(`Invalid platform for integration ${integration.id}: ${integration.platformId}`);
      throw new HttpException(
        'Integration is not a WhatsApp integration',
        HttpStatus.BAD_REQUEST,
      );
    }

    if (integration.status !== 'active') {
      this.logger.warn(`Integration ${integration.id} is not active: ${integration.status}`);
      throw new HttpException('Integration is not active', HttpStatus.BAD_REQUEST);
    }

    if (!integration.credentials?.access_token || !integration.credentials?.phone_number_id) {
      this.logger.warn(`Integration ${integration.id} missing required credentials`);
      throw new HttpException('Integration missing required credentials', HttpStatus.BAD_REQUEST);
    }
  }

  private buildMessagePayload(to: string, message: Partial<WhatsAppMessage>): any {
    const payload: any = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to,
      type: message.type || 'text',
    };

    if (message.context?.message_id) {
      payload.context = {
        message_id: message.context.message_id,
      };
    }

    switch (message.type) {
      case 'text':
        payload.text = {
          preview_url: false,
          body: message.text?.body || '',
        };
        break;
      case 'image':
        payload.image = message.image;
        break;
      case 'document':
        payload.document = message.document;
        break;
      case 'audio':
        payload.audio = message.audio;
        break;
      case 'video':
        payload.video = message.video;
        break;
      case 'location':
        payload.location = message.location;
        break;
      case 'contacts':
        payload.contacts = message.contacts;
        break;
      case 'template':
        payload.template = message.template;
        break;
      default:
        payload.type = 'text';
        payload.text = {
          preview_url: false,
          body: message.text?.body || 'Hello!',
        };
    }

    return payload;
  }
}

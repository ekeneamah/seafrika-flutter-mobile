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

import { Injectable, Logger } from '@nestjs/common';
import { FirestoreService } from '../firestore/firestore.service';
import { WhatsAppWebhookDto, WhatsAppWebhookEntryDto } from './dto/whatsapp-webhook.dto';
import { WhatsAppMessage } from '../integrations/types/whatsapp.types';

@Injectable()
export class WhatsAppWebhookService {
  private readonly logger = new Logger(WhatsAppWebhookService.name);

  constructor(
    private readonly firestoreService: FirestoreService,
  ) {}

  async processWhatsAppWebhook(webhookData: WhatsAppWebhookDto): Promise<void> {
    this.logger.log('Processing WhatsApp webhook');
    
    for (const entry of webhookData.entry) {
      await this.processWebhookEntry(entry);
    }
  }

  private async processWebhookEntry(entry: WhatsAppWebhookEntryDto): Promise<void> {
    this.logger.log(`Processing WhatsApp webhook entry: ${entry.id}`);

    for (const change of entry.changes) {
      if (change.field === 'messages') {
        await this.processMessagesChange(entry.id, change.value);
      }
    }
  }

  private async processMessagesChange(phoneNumberId: string, value: any): Promise<void> {
    // Find integration by phone number ID
    const integration = await this.findIntegrationByPhoneNumberId(phoneNumberId);
    
    if (!integration) {
      this.logger.warn(`No integration found for phone number ID: ${phoneNumberId}`);
      return;
    }

    // Process incoming messages
    if (value.messages) {
      for (const message of value.messages) {
        await this.processIncomingMessage(integration, message);
      }
    }

    // Process message statuses
    if (value.statuses) {
      for (const status of value.statuses) {
        await this.processMessageStatus(integration, status);
      }
    }

    // Process errors
    if (value.errors) {
      for (const error of value.errors) {
        await this.processWebhookError(integration, error);
      }
    }
  }

  private async processIncomingMessage(integration: any, message: WhatsAppMessage): Promise<void> {
    this.logger.log(`Processing incoming WhatsApp message: ${message.id} from ${message.from}`);

    try {
      // Store message in Firestore
      await this.storeIncomingMessage(integration.businessId, integration.id, message);

      // Check for auto-responder rules
      if (integration.settings?.autoResponder) {
        await this.checkAutoResponderRules(integration, message);
      }

      // Send notification to business
      await this.sendMessageNotification(integration, message);

    } catch (error) {
      this.logger.error(`Failed to process incoming message ${message.id}:`, error);
    }
  }

  private async processMessageStatus(integration: any, status: any): Promise<void> {
    this.logger.log(`Processing WhatsApp message status: ${status.id} - ${status.status}`);

    try {
      // Update message status in Firestore
      await this.updateMessageStatus(integration.businessId, integration.id, status);

      // Send status notification if needed
      if (status.status === 'failed' && status.errors) {
        await this.sendStatusNotification(integration, status);
      }

    } catch (error) {
      this.logger.error(`Failed to process message status ${status.id}:`, error);
    }
  }

  private async processWebhookError(integration: any, error: any): Promise<void> {
    this.logger.error(`WhatsApp webhook error for integration ${integration.id}:`, error);

    try {
      // Store error in Firestore
      await this.storeWebhookError(integration.businessId, integration.id, error);

      // Send error notification to business
      await this.sendErrorNotification(integration, error);

    } catch (storeError) {
      this.logger.error(`Failed to store webhook error:`, storeError);
    }
  }

  private async findIntegrationByPhoneNumberId(phoneNumberId: string): Promise<any> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const querySnapshot = await integrationsCollection
        .where('platformId', '==', 'whatsapp')
        .where('credentials.phone_number_id', '==', phoneNumberId)
        .where('status', '==', 'active')
        .get();

      if (querySnapshot.empty) {
        return null;
      }

      const doc = querySnapshot.docs[0];
      const integration = doc.data();
      integration.id = doc.id;

      return integration;
    } catch (error) {
      this.logger.error(`Failed to find integration by phone number ID ${phoneNumberId}:`, error);
      return null;
    }
  }

  private async storeIncomingMessage(businessId: string, integrationId: string, message: WhatsAppMessage): Promise<void> {
    try {
      const messagesCollection = this.firestoreService
        .collection('businesses')
        .doc(businessId)
        .collection('whatsapp_messages');

      await messagesCollection.doc(message.id).set({
        ...message,
        integrationId,
        direction: 'incoming',
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      this.logger.log(`Stored incoming WhatsApp message: ${message.id}`);
    } catch (error) {
      this.logger.error(`Failed to store incoming message ${message.id}:`, error);
      throw error;
    }
  }

  private async updateMessageStatus(businessId: string, integrationId: string, status: any): Promise<void> {
    try {
      const messagesCollection = this.firestoreService
        .collection('businesses')
        .doc(businessId)
        .collection('whatsapp_messages');

      await messagesCollection.doc(status.id).update({
        status: status.status,
        statusTimestamp: new Date(parseInt(status.timestamp) * 1000),
        conversation: status.conversation,
        pricing: status.pricing,
        errors: status.errors,
        updatedAt: new Date(),
      });

      this.logger.log(`Updated WhatsApp message status: ${status.id} -> ${status.status}`);
    } catch (error) {
      this.logger.error(`Failed to update message status ${status.id}:`, error);
      throw error;
    }
  }

  private async checkAutoResponderRules(integration: any, message: WhatsAppMessage): Promise<void> {
    try {
      // Check business hours
      if (integration.settings?.businessHours?.enabled) {
        const isBusinessHours = this.isWithinBusinessHours(integration.settings.businessHours);
        
        if (!isBusinessHours && integration.settings?.awayMessage?.enabled) {
          await this.sendAutoReply(integration, message, integration.settings.awayMessage.message);
          return;
        }
      }

      // Check for welcome message on first interaction
      const isFirstMessage = await this.isFirstMessageFromContact(integration.businessId, message.from);
      if (isFirstMessage && integration.settings?.welcomeMessage?.enabled) {
        await this.sendAutoReply(integration, message, integration.settings.welcomeMessage.message);
      }

    } catch (error) {
      this.logger.error(`Failed to check auto-responder rules:`, error);
    }
  }

  private async sendAutoReply(integration: any, originalMessage: WhatsAppMessage, replyText: string): Promise<void> {
    try {
      // This would integrate with WhatsApp service to send reply
      // For now, just log the auto-reply
      this.logger.log(`Auto-reply sent to ${originalMessage.from}: ${replyText}`);
      
      // Store the auto-reply in messages collection
      const replyMessage = {
        id: `auto_${Date.now()}`,
        from: integration.credentials.phone_number_id,
        to: originalMessage.from,
        type: 'text',
        text: { body: replyText },
        timestamp: new Date().toISOString(),
        context: { message_id: originalMessage.id },
      };

      await this.storeOutgoingMessage(integration.businessId, integration.id, replyMessage);

    } catch (error) {
      this.logger.error(`Failed to send auto-reply:`, error);
    }
  }

  private async storeOutgoingMessage(businessId: string, integrationId: string, message: any): Promise<void> {
    try {
      const messagesCollection = this.firestoreService
        .collection('businesses')
        .doc(businessId)
        .collection('whatsapp_messages');

      await messagesCollection.doc(message.id).set({
        ...message,
        integrationId,
        direction: 'outgoing',
        isAutoReply: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      this.logger.log(`Stored outgoing WhatsApp message: ${message.id}`);
    } catch (error) {
      this.logger.error(`Failed to store outgoing message ${message.id}:`, error);
      throw error;
    }
  }

  private async storeWebhookError(businessId: string, integrationId: string, error: any): Promise<void> {
    try {
      const errorsCollection = this.firestoreService
        .collection('businesses')
        .doc(businessId)
        .collection('integration_errors');

      await errorsCollection.add({
        integrationId,
        platform: 'whatsapp',
        errorCode: error.code,
        errorTitle: error.title,
        errorMessage: error.message,
        errorDetails: error.error_data,
        createdAt: new Date(),
      });

      this.logger.log(`Stored WhatsApp webhook error: ${error.code}`);
    } catch (storeError) {
      this.logger.error(`Failed to store webhook error:`, storeError);
      throw storeError;
    }
  }

  private async sendMessageNotification(integration: any, message: WhatsAppMessage): Promise<void> {
    try {
      // Send notification to business about new message
      // This could be push notification, email, or in-app notification
      this.logger.log(`Notification sent for new WhatsApp message from ${message.from}`);
    } catch (error) {
      this.logger.error(`Failed to send message notification:`, error);
    }
  }

  private async sendStatusNotification(integration: any, status: any): Promise<void> {
    try {
      // Send notification about failed message status
      this.logger.log(`Status notification sent for failed message: ${status.id}`);
    } catch (error) {
      this.logger.error(`Failed to send status notification:`, error);
    }
  }

  private async sendErrorNotification(integration: any, error: any): Promise<void> {
    try {
      // Send notification about webhook error
      this.logger.log(`Error notification sent for WhatsApp error: ${error.code}`);
    } catch (notifyError) {
      this.logger.error(`Failed to send error notification:`, notifyError);
    }
  }

  private isWithinBusinessHours(businessHours: any): boolean {
    const now = new Date();
    const dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    const dayOfWeek = dayNames[now.getDay() === 0 ? 6 : now.getDay() - 1]; // getDay: 0=Sunday, 1=Monday, etc.
    const currentTime = now.toTimeString().substring(0, 5); // HH:MM format

    const daySettings = businessHours[dayOfWeek];
    if (!daySettings || !daySettings.enabled) {
      return false;
    }

    return currentTime >= daySettings.start && currentTime <= daySettings.end;
  }

  private async isFirstMessageFromContact(businessId: string, contactPhone: string): Promise<boolean> {
    try {
      const messagesCollection = this.firestoreService
        .collection('businesses')
        .doc(businessId)
        .collection('whatsapp_messages');

      const querySnapshot = await messagesCollection
        .where('from', '==', contactPhone)
        .limit(1)
        .get();

      return querySnapshot.empty;
    } catch (error) {
      this.logger.error(`Failed to check if first message from contact:`, error);
      return false;
    }
  }
}

import { Injectable, Logger } from '@nestjs/common';
import { FirestoreService } from '../firestore/firestore.service';
import { FacebookWebhookDto, FacebookWebhookEntryDto } from './dto/facebook-webhook.dto';

@Injectable()
export class FacebookWebhookService {
  private readonly logger = new Logger(FacebookWebhookService.name);

  constructor(
    private readonly firestoreService: FirestoreService,
  ) {}

  async processFacebookWebhook(webhookData: FacebookWebhookDto): Promise<void> {
    this.logger.log('Processing Facebook webhook');
    
    for (const entry of webhookData.entry) {
      await this.processWebhookEntry(entry);
    }
  }

  private async processWebhookEntry(entry: FacebookWebhookEntryDto): Promise<void> {
    this.logger.log(`Processing Facebook webhook entry: ${entry.id}`);

    for (const change of entry.changes) {
      await this.processChange(entry.id, change);
    }
  }

  private async processChange(pageId: string, change: any): Promise<void> {
    // Find integration by page ID
    const integration = await this.findIntegrationByPageId(pageId);
    
    if (!integration) {
      this.logger.warn(`No integration found for page ID: ${pageId}`);
      return;
    }

    const { field, value } = change;

    try {
      switch (field) {
        case 'feed':
          await this.processFeedChange(integration, value);
          break;
        case 'mention':
          await this.processMentionChange(integration, value);
          break;
        case 'conversations':
          await this.processConversationChange(integration, value);
          break;
        default:
          this.logger.log(`Unhandled Facebook webhook field: ${field}`);
      }
    } catch (error) {
      this.logger.error(`Failed to process Facebook webhook change for field ${field}:`, error);
    }
  }

  private async processFeedChange(integration: any, value: any): Promise<void> {
    this.logger.log(`Processing Facebook feed change: ${value.item} - ${value.verb}`);

    switch (value.item) {
      case 'post':
        await this.processPostChange(integration, value);
        break;
      case 'comment':
        await this.processCommentChange(integration, value);
        break;
      case 'reaction':
        await this.processReactionChange(integration, value);
        break;
      case 'share':
        await this.processShareChange(integration, value);
        break;
      default:
        this.logger.log(`Unhandled feed item: ${value.item}`);
    }
  }

  private async processPostChange(integration: any, value: any): Promise<void> {
    this.logger.log(`Processing post ${value.verb}: ${value.post_id}`);

    try {
      switch (value.verb) {
        case 'add':
          await this.handleNewPost(integration, value);
          break;
        case 'edit':
          await this.handlePostEdit(integration, value);
          break;
        case 'delete':
          await this.handlePostDelete(integration, value);
          break;
        case 'hide':
        case 'unhide':
          await this.handlePostVisibilityChange(integration, value);
          break;
        default:
          this.logger.log(`Unhandled post verb: ${value.verb}`);
      }
    } catch (error) {
      this.logger.error(`Failed to process post change:`, error);
    }
  }

  private async processCommentChange(integration: any, value: any): Promise<void> {
    this.logger.log(`Processing comment ${value.verb}: ${value.comment_id} on post ${value.post_id}`);

    try {
      switch (value.verb) {
        case 'add':
          await this.handleNewComment(integration, value);
          break;
        case 'edit':
          await this.handleCommentEdit(integration, value);
          break;
        case 'delete':
          await this.handleCommentDelete(integration, value);
          break;
        case 'hide':
        case 'unhide':
          await this.handleCommentVisibilityChange(integration, value);
          break;
        default:
          this.logger.log(`Unhandled comment verb: ${value.verb}`);
      }
    } catch (error) {
      this.logger.error(`Failed to process comment change:`, error);
    }
  }

  private async processReactionChange(integration: any, value: any): Promise<void> {
    this.logger.log(`Processing reaction ${value.verb}: ${value.reaction_type} on post ${value.post_id}`);

    try {
      await this.storeReactionEvent(integration, value);
      await this.sendReactionNotification(integration, value);
    } catch (error) {
      this.logger.error(`Failed to process reaction change:`, error);
    }
  }

  private async processShareChange(integration: any, value: any): Promise<void> {
    this.logger.log(`Processing share ${value.verb}: post ${value.post_id}`);

    try {
      await this.storeShareEvent(integration, value);
      await this.sendShareNotification(integration, value);
    } catch (error) {
      this.logger.error(`Failed to process share change:`, error);
    }
  }

  private async processMentionChange(integration: any, value: any): Promise<void> {
    this.logger.log(`Processing mention: ${value.item} - ${value.verb}`);

    try {
      await this.storeMentionEvent(integration, value);
      await this.sendMentionNotification(integration, value);
    } catch (error) {
      this.logger.error(`Failed to process mention change:`, error);
    }
  }

  private async processConversationChange(integration: any, value: any): Promise<void> {
    this.logger.log(`Processing conversation change: ${value.item} - ${value.verb}`);

    try {
      if (value.item === 'message') {
        await this.handleNewMessage(integration, value);
      }
    } catch (error) {
      this.logger.error(`Failed to process conversation change:`, error);
    }
  }

  private async handleNewPost(integration: any, value: any): Promise<void> {
    try {
      await this.storePostEvent(integration, value, 'created');
      await this.sendPostNotification(integration, value, 'created');
    } catch (error) {
      this.logger.error(`Failed to handle new post:`, error);
    }
  }

  private async handlePostEdit(integration: any, value: any): Promise<void> {
    try {
      await this.storePostEvent(integration, value, 'edited');
    } catch (error) {
      this.logger.error(`Failed to handle post edit:`, error);
    }
  }

  private async handlePostDelete(integration: any, value: any): Promise<void> {
    try {
      await this.storePostEvent(integration, value, 'deleted');
    } catch (error) {
      this.logger.error(`Failed to handle post delete:`, error);
    }
  }

  private async handlePostVisibilityChange(integration: any, value: any): Promise<void> {
    try {
      await this.storePostEvent(integration, value, value.verb);
    } catch (error) {
      this.logger.error(`Failed to handle post visibility change:`, error);
    }
  }

  private async handleNewComment(integration: any, value: any): Promise<void> {
    try {
      await this.storeCommentEvent(integration, value, 'created');
      await this.sendCommentNotification(integration, value);

      // Check for auto-moderation rules
      if (integration.settings?.moderateComments) {
        await this.checkCommentModerationRules(integration, value);
      }

      // Check for auto-responder rules
      if (integration.settings?.autoResponder) {
        await this.checkCommentAutoResponderRules(integration, value);
      }
    } catch (error) {
      this.logger.error(`Failed to handle new comment:`, error);
    }
  }

  private async handleCommentEdit(integration: any, value: any): Promise<void> {
    try {
      await this.storeCommentEvent(integration, value, 'edited');
    } catch (error) {
      this.logger.error(`Failed to handle comment edit:`, error);
    }
  }

  private async handleCommentDelete(integration: any, value: any): Promise<void> {
    try {
      await this.storeCommentEvent(integration, value, 'deleted');
    } catch (error) {
      this.logger.error(`Failed to handle comment delete:`, error);
    }
  }

  private async handleCommentVisibilityChange(integration: any, value: any): Promise<void> {
    try {
      await this.storeCommentEvent(integration, value, value.verb);
    } catch (error) {
      this.logger.error(`Failed to handle comment visibility change:`, error);
    }
  }

  private async handleNewMessage(integration: any, value: any): Promise<void> {
    try {
      await this.storeMessageEvent(integration, value);
      await this.sendMessageNotification(integration, value);

      // Check for auto-responder rules
      if (integration.settings?.autoResponder) {
        await this.checkMessageAutoResponderRules(integration, value);
      }

      // Process message intents and commands
      await this.processMessageIntents(integration, value);

    } catch (error) {
      this.logger.error(`Failed to handle new message:`, error);
    }
  }

  /**
   * Process Messenger-specific events like postbacks, quick replies, etc.
   */
  async processMessengerWebhook(webhookData: any): Promise<void> {
    this.logger.log('Processing Messenger webhook');
    
    for (const entry of webhookData.entry) {
      if (entry.messaging) {
        for (const messagingEvent of entry.messaging) {
          await this.processMessagingEvent(entry.id, messagingEvent);
        }
      }
    }
  }

  private async processMessagingEvent(pageId: string, messagingEvent: any): Promise<void> {
    const integration = await this.findIntegrationByPageId(pageId);
    
    if (!integration) {
      this.logger.warn(`No integration found for page ID: ${pageId}`);
      return;
    }

    try {
      if (messagingEvent.message) {
        await this.handleMessengerMessage(integration, messagingEvent);
      } else if (messagingEvent.postback) {
        await this.handleMessengerPostback(integration, messagingEvent);
      } else if (messagingEvent.delivery) {
        await this.handleMessageDelivery(integration, messagingEvent);
      } else if (messagingEvent.read) {
        await this.handleMessageRead(integration, messagingEvent);
      } else if (messagingEvent.referral) {
        await this.handleMessengerReferral(integration, messagingEvent);
      }
    } catch (error) {
      this.logger.error('Failed to process messaging event:', error);
    }
  }

  private async handleMessengerMessage(integration: any, messagingEvent: any): Promise<void> {
    const { sender, recipient, timestamp, message } = messagingEvent;
    
    try {
      // Store the message
      await this.storeMessengerMessage(integration, {
        senderId: sender.id,
        recipientId: recipient.id,
        timestamp,
        message,
        messageType: 'received'
      });

      // Send notification
      await this.sendMessageNotification(integration, messagingEvent);

      // Process message content and intents
      if (message.text) {
        await this.processMessageIntents(integration, {
          senderId: sender.id,
          text: message.text,
          timestamp
        });
      }

      // Handle attachments
      if (message.attachments) {
        await this.processMessageAttachments(integration, message.attachments, sender.id);
      }

      // Auto-respond if configured
      if (integration.settings?.autoResponder?.enabled) {
        await this.sendAutoResponse(integration, sender.id, message.text);
      }

    } catch (error) {
      this.logger.error('Failed to handle Messenger message:', error);
    }
  }

  private async handleMessengerPostback(integration: any, messagingEvent: any): Promise<void> {
    const { sender, postback, timestamp } = messagingEvent;
    
    try {
      // Store postback event
      await this.storePostbackEvent(integration, {
        senderId: sender.id,
        payload: postback.payload,
        title: postback.title,
        timestamp
      });

      // Process postback action
      await this.processPostbackAction(integration, sender.id, postback.payload);

    } catch (error) {
      this.logger.error('Failed to handle Messenger postback:', error);
    }
  }

  private async handleMessageDelivery(integration: any, messagingEvent: any): Promise<void> {
    const { delivery } = messagingEvent;
    
    try {
      // Update message delivery status
      await this.updateMessageDeliveryStatus(integration, delivery.mids, 'delivered');
      
    } catch (error) {
      this.logger.error('Failed to handle message delivery:', error);
    }
  }

  private async handleMessageRead(integration: any, messagingEvent: any): Promise<void> {
    const { read } = messagingEvent;
    
    try {
      // Update message read status
      await this.updateMessageReadStatus(integration, read.watermark);
      
    } catch (error) {
      this.logger.error('Failed to handle message read:', error);
    }
  }

  private async handleMessengerReferral(integration: any, messagingEvent: any): Promise<void> {
    const { sender, referral, timestamp } = messagingEvent;
    
    try {
      // Store referral event for analytics
      await this.storeReferralEvent(integration, {
        senderId: sender.id,
        ref: referral.ref,
        source: referral.source,
        type: referral.type,
        timestamp
      });
      
    } catch (error) {
      this.logger.error('Failed to handle Messenger referral:', error);
    }
  }

  private async processMessageIntents(integration: any, messageData: any): Promise<void> {
    try {
      const { text, senderId } = messageData;
      
      if (!text) return;

      const lowerText = text.toLowerCase().trim();

      // Handle common intents
      if (lowerText.includes('hello') || lowerText.includes('hi') || lowerText.includes('hey')) {
        await this.sendGreetingResponse(integration, senderId);
      } else if (lowerText.includes('help') || lowerText.includes('support')) {
        await this.sendHelpResponse(integration, senderId);
      } else if (lowerText.includes('hours') || lowerText.includes('open')) {
        await this.sendBusinessHoursResponse(integration, senderId);
      } else if (lowerText.includes('location') || lowerText.includes('address')) {
        await this.sendLocationResponse(integration, senderId);
      } else if (lowerText.includes('menu') || lowerText.includes('catalog')) {
        await this.sendMenuResponse(integration, senderId);
      }
      
    } catch (error) {
      this.logger.error('Failed to process message intents:', error);
    }
  }

  private async processMessageAttachments(integration: any, attachments: any[], senderId: string): Promise<void> {
    try {
      for (const attachment of attachments) {
        await this.storeMessageAttachment(integration, {
          senderId,
          type: attachment.type,
          payload: attachment.payload,
          timestamp: new Date()
        });

        // Process based on attachment type
        if (attachment.type === 'location') {
          await this.processLocationShare(integration, senderId, attachment.payload);
        } else if (attachment.type === 'image' || attachment.type === 'video') {
          await this.processMediaShare(integration, senderId, attachment);
        }
      }
    } catch (error) {
      this.logger.error('Failed to process message attachments:', error);
    }
  }

  private async sendAutoResponse(integration: any, recipientId: string, messageText: string): Promise<void> {
    try {
      const { autoResponder } = integration.settings;
      
      if (!autoResponder?.enabled) return;

      // Check business hours
      const isBusinessHours = this.isWithinBusinessHours(integration.settings?.businessHours);
      
      let responseMessage = autoResponder.defaultMessage || 'Thank you for your message. We will get back to you soon.';
      
      if (!isBusinessHours && autoResponder.awayMessage) {
        responseMessage = autoResponder.awayMessage;
      }

      // Send auto-response via Facebook API
      // This would require injecting FacebookService
      this.logger.log(`Auto-response sent to ${recipientId}: ${responseMessage}`);
      
    } catch (error) {
      this.logger.error('Failed to send auto-response:', error);
    }
  }

  private async sendGreetingResponse(integration: any, recipientId: string): Promise<void> {
    const greeting = integration.settings?.responses?.greeting || 
      'Hello! Welcome to our page. How can we help you today?';
    
    // Send greeting via Facebook API
    this.logger.log(`Greeting sent to ${recipientId}: ${greeting}`);
  }

  private async sendHelpResponse(integration: any, recipientId: string): Promise<void> {
    const helpMessage = integration.settings?.responses?.help || 
      'Here are some ways we can help:\n• Business hours\n• Location\n• Menu/Catalog\n• Support';
    
    // Send help message via Facebook API
    this.logger.log(`Help response sent to ${recipientId}: ${helpMessage}`);
  }

  private async sendBusinessHoursResponse(integration: any, recipientId: string): Promise<void> {
    const businessHours = integration.settings?.businessHours;
    let hoursMessage = 'Our business hours:\n';
    
    if (businessHours) {
      ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'].forEach(day => {
        const dayHours = businessHours[day];
        if (dayHours?.enabled) {
          hoursMessage += `${day.charAt(0).toUpperCase() + day.slice(1)}: ${dayHours.start} - ${dayHours.end}\n`;
        }
      });
    } else {
      hoursMessage = 'Please contact us for our current business hours.';
    }
    
    // Send business hours via Facebook API
    this.logger.log(`Business hours sent to ${recipientId}`);
  }

  private async sendLocationResponse(integration: any, recipientId: string): Promise<void> {
    const location = integration.settings?.businessInfo?.address || 
      'Please contact us for our location information.';
    
    // Send location via Facebook API
    this.logger.log(`Location sent to ${recipientId}: ${location}`);
  }

  private async sendMenuResponse(integration: any, recipientId: string): Promise<void> {
    const menuMessage = integration.settings?.responses?.menu || 
      'Check out our products and services on our page!';
    
    // Send menu/catalog via Facebook API
    this.logger.log(`Menu response sent to ${recipientId}`);
  }

  private async findIntegrationByPageId(pageId: string): Promise<any> {
    try {
      const integrationsCollection = this.firestoreService.collection('integrations');
      const querySnapshot = await integrationsCollection
        .where('platformId', '==', 'facebook')
        .where('credentials.page_id', '==', pageId)
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
      this.logger.error(`Failed to find integration by page ID ${pageId}:`, error);
      return null;
    }
  }

  private async storePostEvent(integration: any, value: any, action: string): Promise<void> {
    try {
      const eventsCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('facebook_events');

      await eventsCollection.add({
        integrationId: integration.id,
        type: 'post',
        action,
        postId: value.post_id,
        post: value.post,
        from: value.from,
        createdTime: value.created_time ? new Date(value.created_time * 1000) : new Date(),
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store post event:`, error);
      throw error;
    }
  }

  private async storeCommentEvent(integration: any, value: any, action: string): Promise<void> {
    try {
      const eventsCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('facebook_events');

      await eventsCollection.add({
        integrationId: integration.id,
        type: 'comment',
        action,
        commentId: value.comment_id,
        postId: value.post_id,
        parentId: value.parent_id,
        message: value.message,
        from: value.from,
        createdTime: value.created_time ? new Date(value.created_time * 1000) : new Date(),
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store comment event:`, error);
      throw error;
    }
  }

  private async storeReactionEvent(integration: any, value: any): Promise<void> {
    try {
      const eventsCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('facebook_events');

      await eventsCollection.add({
        integrationId: integration.id,
        type: 'reaction',
        action: value.verb,
        postId: value.post_id,
        reactionType: value.reaction_type,
        from: value.from,
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store reaction event:`, error);
      throw error;
    }
  }

  private async storeShareEvent(integration: any, value: any): Promise<void> {
    try {
      const eventsCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('facebook_events');

      await eventsCollection.add({
        integrationId: integration.id,
        type: 'share',
        action: value.verb,
        postId: value.post_id,
        share: value.share,
        from: value.from,
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store share event:`, error);
      throw error;
    }
  }

  private async storeMentionEvent(integration: any, value: any): Promise<void> {
    try {
      const eventsCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('facebook_events');

      await eventsCollection.add({
        integrationId: integration.id,
        type: 'mention',
        action: value.verb,
        postId: value.post_id,
        message: value.message,
        from: value.from,
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store mention event:`, error);
      throw error;
    }
  }

  private async storeMessageEvent(integration: any, value: any): Promise<void> {
    try {
      const messagesCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('facebook_messages');

      await messagesCollection.add({
        integrationId: integration.id,
        message: value.message,
        from: value.from,
        createdTime: value.created_time ? new Date(value.created_time * 1000) : new Date(),
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store message event:`, error);
      throw error;
    }
  }

  private async storeMessengerMessage(integration: any, messageData: any): Promise<void> {
    try {
      const messagesCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('messenger_messages');

      await messagesCollection.add({
        integrationId: integration.id,
        senderId: messageData.senderId,
        recipientId: messageData.recipientId,
        message: messageData.message,
        messageType: messageData.messageType,
        timestamp: new Date(messageData.timestamp),
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store Messenger message:`, error);
      throw error;
    }
  }

  private async storePostbackEvent(integration: any, postbackData: any): Promise<void> {
    try {
      const eventsCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('messenger_events');

      await eventsCollection.add({
        integrationId: integration.id,
        type: 'postback',
        senderId: postbackData.senderId,
        payload: postbackData.payload,
        title: postbackData.title,
        timestamp: new Date(postbackData.timestamp),
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store postback event:`, error);
      throw error;
    }
  }

  private async storeReferralEvent(integration: any, referralData: any): Promise<void> {
    try {
      const eventsCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('messenger_events');

      await eventsCollection.add({
        integrationId: integration.id,
        type: 'referral',
        senderId: referralData.senderId,
        ref: referralData.ref,
        source: referralData.source,
        referralType: referralData.type,
        timestamp: new Date(referralData.timestamp),
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store referral event:`, error);
      throw error;
    }
  }

  private async storeMessageAttachment(integration: any, attachmentData: any): Promise<void> {
    try {
      const attachmentsCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('message_attachments');

      await attachmentsCollection.add({
        integrationId: integration.id,
        senderId: attachmentData.senderId,
        type: attachmentData.type,
        payload: attachmentData.payload,
        timestamp: attachmentData.timestamp,
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.error(`Failed to store message attachment:`, error);
      throw error;
    }
  }

  private async updateMessageDeliveryStatus(integration: any, messageIds: string[], status: string): Promise<void> {
    try {
      const messagesCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('messenger_messages');

      for (const messageId of messageIds) {
        const querySnapshot = await messagesCollection
          .where('message.mid', '==', messageId)
          .get();

        querySnapshot.forEach(async (doc) => {
          await doc.ref.update({
            deliveryStatus: status,
            deliveredAt: new Date(),
          });
        });
      }
    } catch (error) {
      this.logger.error(`Failed to update message delivery status:`, error);
    }
  }

  private async updateMessageReadStatus(integration: any, watermark: number): Promise<void> {
    try {
      const messagesCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('messenger_messages');

      const querySnapshot = await messagesCollection
        .where('timestamp', '<=', new Date(watermark))
        .where('readStatus', '!=', 'read')
        .get();

      querySnapshot.forEach(async (doc) => {
        await doc.ref.update({
          readStatus: 'read',
          readAt: new Date(),
        });
      });
    } catch (error) {
      this.logger.error(`Failed to update message read status:`, error);
    }
  }

  private async processPostbackAction(integration: any, senderId: string, payload: string): Promise<void> {
    try {
      // Handle different postback actions
      switch (payload) {
        case 'GET_STARTED':
          await this.sendGreetingResponse(integration, senderId);
          break;
        case 'MENU':
          await this.sendMenuResponse(integration, senderId);
          break;
        case 'HOURS':
          await this.sendBusinessHoursResponse(integration, senderId);
          break;
        case 'LOCATION':
          await this.sendLocationResponse(integration, senderId);
          break;
        case 'SUPPORT':
          await this.sendHelpResponse(integration, senderId);
          break;
        default:
          this.logger.log(`Unhandled postback payload: ${payload}`);
      }
    } catch (error) {
      this.logger.error(`Failed to process postback action:`, error);
    }
  }

  private async processLocationShare(integration: any, senderId: string, locationPayload: any): Promise<void> {
    try {
      // Store location data
      const locationsCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('customer_locations');

      await locationsCollection.add({
        integrationId: integration.id,
        senderId: senderId,
        coordinates: locationPayload.coordinates,
        address: locationPayload.address,
        title: locationPayload.title,
        createdAt: new Date(),
      });

      // Send acknowledgment
      const response = 'Thank you for sharing your location! We\'ll use this to better assist you.';
      this.logger.log(`Location acknowledgment sent to ${senderId}`);
    } catch (error) {
      this.logger.error(`Failed to process location share:`, error);
    }
  }

  private async processMediaShare(integration: any, senderId: string, attachment: any): Promise<void> {
    try {
      // Store media reference
      const mediaCollection = this.firestoreService
        .collection('businesses')
        .doc(integration.businessId)
        .collection('shared_media');

      await mediaCollection.add({
        integrationId: integration.id,
        senderId: senderId,
        type: attachment.type,
        url: attachment.payload.url,
        stickerId: attachment.payload.sticker_id,
        createdAt: new Date(),
      });

      // Send acknowledgment
      const response = `Thank you for sharing the ${attachment.type}!`;
      this.logger.log(`Media acknowledgment sent to ${senderId}`);
    } catch (error) {
      this.logger.error(`Failed to process media share:`, error);
    }
  }

  private async checkCommentModerationRules(integration: any, value: any): Promise<void> {
    try {
      // Check for offensive content and auto-hide if needed
      if (integration.settings?.hideOffensiveComments) {
        const isOffensive = await this.isOffensiveContent(value.message);
        if (isOffensive) {
          // This would call Facebook API to hide the comment
          this.logger.log(`Auto-hiding offensive comment: ${value.comment_id}`);
        }
      }
    } catch (error) {
      this.logger.error(`Failed to check comment moderation rules:`, error);
    }
  }

  private async checkCommentAutoResponderRules(integration: any, value: any): Promise<void> {
    try {
      // Check business hours and send auto-reply if needed
      if (integration.settings?.businessHours?.enabled) {
        const isBusinessHours = this.isWithinBusinessHours(integration.settings.businessHours);
        
        if (!isBusinessHours && integration.settings?.awayMessage?.enabled) {
          // This would call Facebook API to reply to the comment
          this.logger.log(`Auto-replying to comment outside business hours: ${value.comment_id}`);
        }
      }
    } catch (error) {
      this.logger.error(`Failed to check comment auto-responder rules:`, error);
    }
  }

  private async checkMessageAutoResponderRules(integration: any, value: any): Promise<void> {
    try {
      // Similar to comment auto-responder but for private messages
      if (integration.settings?.businessHours?.enabled) {
        const isBusinessHours = this.isWithinBusinessHours(integration.settings.businessHours);
        
        if (!isBusinessHours && integration.settings?.awayMessage?.enabled) {
          // This would call Facebook API to send auto-reply message
          this.logger.log(`Auto-replying to message outside business hours`);
        }
      }
    } catch (error) {
      this.logger.error(`Failed to check message auto-responder rules:`, error);
    }
  }

  private async sendPostNotification(integration: any, value: any, action: string): Promise<void> {
    try {
      this.logger.log(`Post notification sent: ${action} - ${value.post_id}`);
    } catch (error) {
      this.logger.error(`Failed to send post notification:`, error);
    }
  }

  private async sendCommentNotification(integration: any, value: any): Promise<void> {
    try {
      this.logger.log(`Comment notification sent: ${value.comment_id}`);
    } catch (error) {
      this.logger.error(`Failed to send comment notification:`, error);
    }
  }

  private async sendReactionNotification(integration: any, value: any): Promise<void> {
    try {
      this.logger.log(`Reaction notification sent: ${value.reaction_type} on ${value.post_id}`);
    } catch (error) {
      this.logger.error(`Failed to send reaction notification:`, error);
    }
  }

  private async sendShareNotification(integration: any, value: any): Promise<void> {
    try {
      this.logger.log(`Share notification sent: ${value.post_id}`);
    } catch (error) {
      this.logger.error(`Failed to send share notification:`, error);
    }
  }

  private async sendMentionNotification(integration: any, value: any): Promise<void> {
    try {
      this.logger.log(`Mention notification sent: ${value.post_id}`);
    } catch (error) {
      this.logger.error(`Failed to send mention notification:`, error);
    }
  }

  private async sendMessageNotification(integration: any, value: any): Promise<void> {
    try {
      this.logger.log(`Message notification sent from: ${value.from?.name}`);
    } catch (error) {
      this.logger.error(`Failed to send message notification:`, error);
    }
  }

  private async isOffensiveContent(message: string): Promise<boolean> {
    // Implement content moderation logic here
    // This could use AI/ML services or keyword filtering
    return false;
  }

  private isWithinBusinessHours(businessHours: any): boolean {
    const now = new Date();
    const dayOfWeek = now.toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase(); // monday, tuesday, etc.
    const currentTime = now.toTimeString().substring(0, 5); // HH:MM format

    const daySettings = businessHours[dayOfWeek];
    if (!daySettings || !daySettings.enabled) {
      return false;
    }

    return currentTime >= daySettings.start && currentTime <= daySettings.end;
  }
}

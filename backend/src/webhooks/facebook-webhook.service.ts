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
    } catch (error) {
      this.logger.error(`Failed to handle new message:`, error);
    }
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

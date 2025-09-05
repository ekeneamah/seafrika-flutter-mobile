import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirestoreService } from '../firestore/firestore.service';
import { InstagramWebhookDto, InstagramEntry } from './dto/instagram-webhook.dto';
import * as crypto from 'crypto';

@Injectable()
export class InstagramWebhookService {
  private readonly logger = new Logger(InstagramWebhookService.name);

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
  ) {}

  /**
   * Verify Instagram webhook subscription
   */
  async verifyWebhook(verifyToken: string): Promise<boolean> {
    const expectedToken = this.configService.get<string>('INSTAGRAM_VERIFY_TOKEN');
    
    if (!expectedToken) {
      this.logger.error('Instagram verify token not configured');
      return false;
    }

    return verifyToken === expectedToken;
  }

  /**
   * Verify webhook signature for security
   */
  async verifySignature(payload: Buffer, signature: string): Promise<boolean> {
    if (!signature) {
      return false;
    }

    const appSecret = this.configService.get<string>('INSTAGRAM_APP_SECRET');
    
    if (!appSecret) {
      this.logger.error('Instagram app secret not configured');
      return false;
    }

    // Remove 'sha256=' prefix
    const receivedSignature = signature.replace('sha256=', '');
    
    // Calculate expected signature
    const expectedSignature = crypto
      .createHmac('sha256', appSecret)
      .update(payload)
      .digest('hex');

    return crypto.timingSafeEqual(
      Buffer.from(receivedSignature, 'hex'),
      Buffer.from(expectedSignature, 'hex'),
    );
  }

  /**
   * Process Instagram webhook data
   */
  async processWebhook(webhookData: InstagramWebhookDto): Promise<void> {
    this.logger.log('Processing Instagram webhook data');

    for (const entry of webhookData.entry) {
      await this.processEntry(entry);
    }
  }

  /**
   * Process individual webhook entry
   */
  private async processEntry(entry: InstagramEntry): Promise<void> {
    this.logger.log(`Processing entry for Instagram account: ${entry.id}`);

    // Store the webhook event
    await this.storeWebhookEvent(entry);

    // Process different types of changes
    for (const change of entry.changes) {
      switch (change.field) {
        case 'media':
          await this.handleMediaChange(entry.id, change);
          break;
        case 'comments':
          await this.handleCommentsChange(entry.id, change);
          break;
        case 'mentions':
          await this.handleMentionsChange(entry.id, change);
          break;
        case 'story_insights':
          await this.handleStoryInsights(entry.id, change);
          break;
        default:
          this.logger.log(`Unhandled change field: ${change.field}`);
      }
    }
  }

  /**
   * Handle media changes (new posts, updates)
   */
  private async handleMediaChange(instagramId: string, change: any): Promise<void> {
    this.logger.log('Processing media change');
    
    const mediaData = {
      instagramAccountId: instagramId,
      mediaId: change.value?.media_id,
      changeType: 'media',
      data: change.value,
      timestamp: new Date(),
    };

    // Store in Firestore
    const docRef = this.firestoreService.collection('instagram_media_events').doc();
    await docRef.set(mediaData);

    // You can add your business logic here
    // For example: update product posts, analyze engagement, etc.
  }

  /**
   * Handle comments changes
   */
  private async handleCommentsChange(instagramId: string, change: any): Promise<void> {
    this.logger.log('Processing comments change');
    
    const commentData = {
      instagramAccountId: instagramId,
      commentId: change.value?.comment_id,
      mediaId: change.value?.media_id,
      changeType: 'comments',
      data: change.value,
      timestamp: new Date(),
    };

    // Store in Firestore
    const docRef = this.firestoreService.collection('instagram_comment_events').doc();
    await docRef.set(commentData);

    // Business logic: handle customer inquiries, moderate comments, etc.
  }

  /**
   * Handle mentions
   */
  private async handleMentionsChange(instagramId: string, change: any): Promise<void> {
    this.logger.log('Processing mentions change');
    
    const mentionData = {
      instagramAccountId: instagramId,
      mentionId: change.value?.mention_id,
      mediaId: change.value?.media_id,
      changeType: 'mentions',
      data: change.value,
      timestamp: new Date(),
    };

    // Store in Firestore
    const docRef = this.firestoreService.collection('instagram_mention_events').doc();
    await docRef.set(mentionData);

    // Business logic: track brand mentions, respond to customer mentions, etc.
  }

  /**
   * Handle story insights
   */
  private async handleStoryInsights(instagramId: string, change: any): Promise<void> {
    this.logger.log('Processing story insights');
    
    const insightData = {
      instagramAccountId: instagramId,
      storyId: change.value?.story_id,
      changeType: 'story_insights',
      data: change.value,
      timestamp: new Date(),
    };

    // Store in Firestore
    const docRef = this.firestoreService.collection('instagram_story_insights').doc();
    await docRef.set(insightData);

    // Business logic: analyze story performance, track engagement, etc.
  }

  /**
   * Store webhook event for audit/debugging
   */
  private async storeWebhookEvent(entry: InstagramEntry): Promise<void> {
    const eventData = {
      instagramAccountId: entry.id,
      time: new Date(entry.time * 1000), // Convert Unix timestamp
      changes: entry.changes,
      receivedAt: new Date(),
    };

    const docRef = this.firestoreService.collection('instagram_webhook_events').doc();
    await docRef.set(eventData);
  }

  /**
   * Get webhook events for an Instagram account
   */
  async getWebhookEvents(instagramAccountId: string, limit: number = 50): Promise<any[]> {
    const query: any = this.firestoreService
      .collection('instagram_webhook_events')
      .where('instagramAccountId', '==', instagramAccountId)
      .orderBy('receivedAt', 'desc')
      .limit(limit);

    const snapshot = await query.get();
    return snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
  }

  /**
   * Get media events for an Instagram account
   */
  async getMediaEvents(instagramAccountId: string, limit: number = 50): Promise<any[]> {
    const query: any = this.firestoreService
      .collection('instagram_media_events')
      .where('instagramAccountId', '==', instagramAccountId)
      .orderBy('timestamp', 'desc')
      .limit(limit);

    const snapshot = await query.get();
    return snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
  }
}

import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { Firestore, Timestamp, FieldValue } from '@google-cloud/firestore';
import { QueueMessageDto } from './dto/queue-message.dto';

export interface QueuedMessage {
  id: string;
  messageId: string;
  conversationId: string;
  businessId: string;
  integrationId: string;
  platform: string;
  recipientId: string;
  message?: string;
  messageType?: string;
  attachmentUrl?: string;
  metadata?: Record<string, any>;
  reason?: string;
  status: 'queued' | 'retrying' | 'sent' | 'failed';
  retryCount: number;
  maxRetries: number;
  nextRetryAt: Date;
  lastError?: string;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class QueueService {
  private firestore: Firestore;
  private readonly MAX_RETRIES = 5;
  private readonly RETRY_DELAYS = [60, 300, 900, 1800, 3600]; // 1min, 5min, 15min, 30min, 1hour

  constructor() {
    this.firestore = new Firestore();
  }

  /**
   * Queue a message for later delivery
   */
  async queueMessage(dto: QueueMessageDto): Promise<QueuedMessage> {
    try {
      const queueRef = this.firestore.collection('message_queue').doc();
      const now = new Date();
      const nextRetryAt = new Date(now.getTime() + this.RETRY_DELAYS[0] * 1000);

      const queuedMessage: Partial<QueuedMessage> = {
        messageId: dto.messageId,
        conversationId: dto.conversationId,
        businessId: dto.businessId,
        integrationId: dto.integrationId,
        platform: dto.platform,
        recipientId: dto.recipientId,
        message: dto.message,
        messageType: dto.messageType || 'text',
        attachmentUrl: dto.attachmentUrl,
        metadata: dto.metadata,
        reason: dto.reason || 'offline',
        status: 'queued',
        retryCount: 0,
        maxRetries: this.MAX_RETRIES,
        nextRetryAt: nextRetryAt,
        createdAt: now,
        updatedAt: now,
      };

      await queueRef.set(queuedMessage);

      // Update message status in main messages collection
      await this.firestore
        .collection('messages')
        .doc(dto.messageId)
        .update({
          'metadata.status': 'queued',
          'metadata.queuedAt': Timestamp.fromDate(now),
          'metadata.queueId': queueRef.id,
          updatedAt: Timestamp.fromDate(now),
        });

      console.log(
        `✅ Message queued: ${dto.messageId} (queueId: ${queueRef.id})`,
      );

      return {
        id: queueRef.id,
        ...queuedMessage,
      } as QueuedMessage;
    } catch (error) {
      console.error('❌ Error queueing message:', error);
      throw new HttpException(
        'Failed to queue message',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Retry a specific queued message
   */
  async retryQueuedMessage(queueId: string): Promise<{
    success: boolean;
    message: string;
    status: string;
  }> {
    try {
      const queueRef = this.firestore.collection('message_queue').doc(queueId);
      const queueDoc = await queueRef.get();

      if (!queueDoc.exists) {
        throw new HttpException('Queue item not found', HttpStatus.NOT_FOUND);
      }

      const queueData = queueDoc.data() as QueuedMessage;

      // Check if max retries exceeded
      if (queueData.retryCount >= queueData.maxRetries) {
        await queueRef.update({
          status: 'failed',
          lastError: 'Max retries exceeded',
          updatedAt: Timestamp.now(),
        });

        return {
          success: false,
          message: 'Max retries exceeded',
          status: 'failed',
        };
      }

      // Update retry count
      const newRetryCount = queueData.retryCount + 1;
      const nextDelay = this.RETRY_DELAYS[Math.min(newRetryCount, this.RETRY_DELAYS.length - 1)];
      const nextRetryAt = new Date(Date.now() + nextDelay * 1000);

      await queueRef.update({
        status: 'retrying',
        retryCount: newRetryCount,
        nextRetryAt: Timestamp.fromDate(nextRetryAt),
        updatedAt: Timestamp.now(),
      });

      // Attempt to send the message
      const sendResult = await this.attemptSend(queueData);

      if (sendResult.success) {
        // Mark as sent
        await queueRef.update({
          status: 'sent',
          updatedAt: Timestamp.now(),
        });

        // Update main message status
        await this.firestore
          .collection('messages')
          .doc(queueData.messageId)
          .update({
            'metadata.status': 'sent',
            'metadata.sentAt': Timestamp.now(),
            updatedAt: Timestamp.now(),
          });

        console.log(`✅ Message sent from queue: ${queueData.messageId}`);

        return {
          success: true,
          message: 'Message sent successfully',
          status: 'sent',
        };
      } else {
        // Mark retry attempt
        await queueRef.update({
          status: 'queued',
          lastError: sendResult.error,
          updatedAt: Timestamp.now(),
        });

        return {
          success: false,
          message: `Retry ${newRetryCount}/${queueData.maxRetries}: ${sendResult.error}`,
          status: 'queued',
        };
      }
    } catch (error) {
      console.error('❌ Error retrying queued message:', error);
      throw new HttpException(
        'Failed to retry message',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get all queued messages for a business
   */
  async getBusinessQueue(businessId: string): Promise<QueuedMessage[]> {
    try {
      const snapshot = await this.firestore
        .collection('message_queue')
        .where('businessId', '==', businessId)
        .where('status', 'in', ['queued', 'retrying'])
        .orderBy('createdAt', 'desc')
        .get();

      return snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as QueuedMessage[];
    } catch (error) {
      console.error('❌ Error getting business queue:', error);
      throw new HttpException(
        'Failed to retrieve queue',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get queued messages for a conversation
   */
  async getConversationQueue(
    conversationId: string,
  ): Promise<QueuedMessage[]> {
    try {
      const snapshot = await this.firestore
        .collection('message_queue')
        .where('conversationId', '==', conversationId)
        .where('status', 'in', ['queued', 'retrying'])
        .orderBy('createdAt', 'asc')
        .get();

      return snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      })) as QueuedMessage[];
    } catch (error) {
      console.error('❌ Error getting conversation queue:', error);
      throw new HttpException(
        'Failed to retrieve queue',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Process all pending messages in queue (called by background job)
   */
  async processQueue(): Promise<{
    processed: number;
    succeeded: number;
    failed: number;
  }> {
    try {
      const now = new Date();
      const snapshot = await this.firestore
        .collection('message_queue')
        .where('status', '==', 'queued')
        .where('nextRetryAt', '<=', Timestamp.fromDate(now))
        .limit(100)
        .get();

      let processed = 0;
      let succeeded = 0;
      let failed = 0;

      for (const doc of snapshot.docs) {
        processed++;
        const result = await this.retryQueuedMessage(doc.id);
        if (result.success) {
          succeeded++;
        } else if (result.status === 'failed') {
          failed++;
        }
      }

      console.log(
        `📦 Queue processed: ${processed} messages (✅ ${succeeded} sent, ❌ ${failed} failed)`,
      );

      return { processed, succeeded, failed };
    } catch (error) {
      console.error('❌ Error processing queue:', error);
      throw error;
    }
  }

  /**
   * Attempt to send a queued message via the appropriate platform API
   */
  private async attemptSend(
    queueData: QueuedMessage,
  ): Promise<{ success: boolean; error?: string }> {
    try {
      // Get integration credentials
      const integrationDoc = await this.firestore
        .collection('integrations')
        .doc(queueData.integrationId)
        .get();

      if (!integrationDoc.exists) {
        return {
          success: false,
          error: 'Integration not found',
        };
      }

      const integration = integrationDoc.data();
      const accessToken = integration?.accessToken;

      if (!accessToken) {
        return {
          success: false,
          error: 'Missing access token',
        };
      }

      // Call Meta Graph API to send message
      const response = await fetch(
        'https://graph.facebook.com/v21.0/me/messages',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            access_token: accessToken,
            recipient: { id: queueData.recipientId },
            message: { text: queueData.message || '' },
          }),
        },
      );

      if (!response.ok) {
        const errorData = await response.json();
        return {
          success: false,
          error: errorData.error?.message || 'API call failed',
        };
      }

      const result = await response.json();
      console.log(
        `✅ Message sent via ${queueData.platform}: ${result.message_id}`,
      );

      return { success: true };
    } catch (error) {
      console.error('❌ Error sending queued message:', error);
      return {
        success: false,
        error: error.message || 'Unknown error',
      };
    }
  }

  /**
   * Clean up old completed/failed queue items (call this periodically)
   */
  async cleanupOldQueue(): Promise<number> {
    try {
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const snapshot = await this.firestore
        .collection('message_queue')
        .where('status', 'in', ['sent', 'failed'])
        .where('updatedAt', '<=', Timestamp.fromDate(sevenDaysAgo))
        .limit(500)
        .get();

      const batch = this.firestore.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      console.log(`🧹 Cleaned up ${snapshot.size} old queue items`);
      return snapshot.size;
    } catch (error) {
      console.error('❌ Error cleaning up queue:', error);
      throw error;
    }
  }
}

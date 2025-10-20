import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { Firestore } from '@google-cloud/firestore';
import { ReplyMessageDto, ThreadResponseDto } from './dto/reply-message.dto';
import axios from 'axios';

@Injectable()
export class ThreadsService {
  private readonly logger = new Logger(ThreadsService.name);
  private readonly db: Firestore;
  private readonly maxThreadDepth = 2; // Limit to 2 levels of nesting

  constructor() {
    this.db = new Firestore();
  }

  /**
   * Send a reply to a specific message and create thread relationship
   */
  async replyToMessage(dto: ReplyMessageDto): Promise<any> {
    try {
      // 1. Get parent message to validate and check thread depth
      const parentMessageRef = this.db.collection('messages').doc(dto.parentMessageId);
      const parentMessageSnap = await parentMessageRef.get();

      if (!parentMessageSnap.exists) {
        throw new NotFoundException(`Parent message ${dto.parentMessageId} not found`);
      }

      const parentMessage = parentMessageSnap.data();
      const currentThreadDepth = parentMessage.threadDepth || 0;

      // Check thread depth limit
      if (currentThreadDepth >= this.maxThreadDepth) {
        throw new BadRequestException(
          `Maximum thread depth of ${this.maxThreadDepth} levels exceeded`
        );
      }

      // 2. Create reply message with thread metadata
      const replyMessage = {
        content: dto.content,
        conversationId: dto.conversationId,
        senderId: dto.senderId,
        platform: dto.platform || 'app',
        replyToId: dto.parentMessageId,
        threadDepth: currentThreadDepth + 1,
        replyCount: 0,
        attachments: dto.attachments || [],
        metadata: {
          status: 'sent',
          source: 'business',
          isThreadReply: true,
          parentMessagePreview: this.getMessagePreview(parentMessage),
        },
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      // 3. Save reply message to Firestore
      const messageRef = this.db.collection('messages').doc();
      await messageRef.set(replyMessage);

      // 4. Update parent message reply count
      await parentMessageRef.update({
        replyCount: (parentMessage.replyCount || 0) + 1,
        updatedAt: new Date(),
      });

      // 5. Sync to external platform if needed
      if (dto.platform && dto.platform !== 'app') {
        await this.syncReplyToPlatform(dto, messageRef.id, parentMessage);
      }

      // 6. Return the created reply message
      const createdMessage = await messageRef.get();
      return {
        success: true,
        message: {
          id: messageRef.id,
          ...createdMessage.data(),
        },
      };
    } catch (error) {
      this.logger.error(`Error creating reply: ${error.message}`, error.stack);
      throw error;
    }
  }

  /**
   * Get all replies for a specific message (thread view)
   */
  async getThreadMessages(messageId: string): Promise<ThreadResponseDto> {
    try {
      // 1. Get parent message
      const parentMessageRef = this.db.collection('messages').doc(messageId);
      const parentMessageSnap = await parentMessageRef.get();

      if (!parentMessageSnap.exists) {
        throw new NotFoundException(`Message ${messageId} not found`);
      }

      const parentMessage = parentMessageSnap.data();

      // 2. Get all direct replies
      const repliesSnapshot = await this.db
        .collection('messages')
        .where('replyToId', '==', messageId)
        .orderBy('createdAt', 'asc')
        .get();

      const replies = [];
      for (const doc of repliesSnapshot.docs) {
        const replyData = doc.data();
        
        // Get nested replies if any (depth 2)
        const nestedRepliesSnapshot = await this.db
          .collection('messages')
          .where('replyToId', '==', doc.id)
          .orderBy('createdAt', 'asc')
          .get();

        const nestedReplies = nestedRepliesSnapshot.docs.map(nestedDoc => ({
          id: nestedDoc.id,
          ...nestedDoc.data(),
        }));

        replies.push({
          id: doc.id,
          ...replyData,
          replies: nestedReplies,
        });
      }

      return {
        parentMessageId: messageId,
        replyCount: parentMessage.replyCount || 0,
        threadDepth: parentMessage.threadDepth || 0,
        messages: [
          {
            id: messageId,
            ...parentMessage,
          },
          ...replies,
        ],
      };
    } catch (error) {
      this.logger.error(`Error getting thread: ${error.message}`, error.stack);
      throw error;
    }
  }

  /**
   * Get thread preview (parent message info) for a reply
   */
  async getThreadPreview(messageId: string): Promise<any> {
    try {
      const messageRef = this.db.collection('messages').doc(messageId);
      const messageSnap = await messageRef.get();

      if (!messageSnap.exists) {
        throw new NotFoundException(`Message ${messageId} not found`);
      }

      const message = messageSnap.data();

      // If this message is a reply, get its parent
      if (message.replyToId) {
        const parentRef = this.db.collection('messages').doc(message.replyToId);
        const parentSnap = await parentRef.get();

        if (parentSnap.exists) {
          const parentData = parentSnap.data();
          return {
            id: message.replyToId,
            content: this.getMessagePreview(parentData),
            senderId: parentData.senderId,
            createdAt: parentData.createdAt,
          };
        }
      }

      return null;
    } catch (error) {
      this.logger.error(`Error getting thread preview: ${error.message}`, error.stack);
      return null;
    }
  }

  /**
   * Delete a reply and update parent message reply count
   */
  async deleteReply(messageId: string): Promise<void> {
    try {
      const messageRef = this.db.collection('messages').doc(messageId);
      const messageSnap = await messageRef.get();

      if (!messageSnap.exists) {
        throw new NotFoundException(`Message ${messageId} not found`);
      }

      const message = messageSnap.data();

      // Soft delete
      await messageRef.update({
        deletedAt: new Date(),
        updatedAt: new Date(),
      });

      // Update parent message reply count if exists
      if (message.replyToId) {
        const parentRef = this.db.collection('messages').doc(message.replyToId);
        const parentSnap = await parentRef.get();

        if (parentSnap.exists) {
          const parent = parentSnap.data();
          await parentRef.update({
            replyCount: Math.max(0, (parent.replyCount || 1) - 1),
            updatedAt: new Date(),
          });
        }
      }

      this.logger.log(`Reply ${messageId} soft deleted`);
    } catch (error) {
      this.logger.error(`Error deleting reply: ${error.message}`, error.stack);
      throw error;
    }
  }

  /**
   * Sync reply to external platform (Instagram/Messenger)
   */
  private async syncReplyToPlatform(
    dto: ReplyMessageDto,
    messageId: string,
    parentMessage: any,
  ): Promise<void> {
    try {
      // Get conversation to find platform-specific IDs
      const conversationRef = this.db.collection('conversations').doc(dto.conversationId);
      const conversationSnap = await conversationRef.get();

      if (!conversationSnap.exists) {
        this.logger.warn(`Conversation ${dto.conversationId} not found for platform sync`);
        return;
      }

      const conversation = conversationSnap.data();
      const pageAccessToken = conversation.pageAccessToken;

      if (!pageAccessToken) {
        this.logger.warn('No page access token found for platform sync');
        return;
      }

      // Instagram and Messenger use Meta Graph API
      if (dto.platform === 'instagram' || dto.platform === 'messenger') {
        const recipientId = conversation.platformUserId;

        if (!recipientId) {
          this.logger.warn('No platform user ID found');
          return;
        }

        // Send reply via Meta Graph API
        const apiUrl = `https://graph.facebook.com/v18.0/me/messages`;
        
        const payload: any = {
          recipient: { id: recipientId },
          message: { text: dto.content },
        };

        // Add reply metadata if platform supports it (Messenger does)
        if (dto.platform === 'messenger' && parentMessage.platformMessageId) {
          payload.message.reply_to = parentMessage.platformMessageId;
        }

        const response = await axios.post(apiUrl, payload, {
          params: { access_token: pageAccessToken },
          headers: { 'Content-Type': 'application/json' },
        });

        // Update message with platform ID
        await this.db.collection('messages').doc(messageId).update({
          platformMessageId: response.data.message_id,
          'metadata.platformSynced': true,
          'metadata.platformSyncedAt': new Date(),
        });

        this.logger.log(`Reply synced to ${dto.platform} with ID ${response.data.message_id}`);
      }
    } catch (error) {
      this.logger.error(`Error syncing reply to platform: ${error.message}`, error.stack);
      // Don't throw - reply was saved locally, just log the sync error
    }
  }

  /**
   * Get message preview text (truncate to 100 chars)
   */
  private getMessagePreview(message: any): string {
    if (!message) return '';
    
    let preview = message.content || '';
    
    // If message has attachments but no text
    if (!preview && message.attachments && message.attachments.length > 0) {
      const attachment = message.attachments[0];
      preview = `[${attachment.type || 'attachment'}]`;
    }

    // Truncate to 100 characters
    if (preview.length > 100) {
      preview = preview.substring(0, 97) + '...';
    }

    return preview;
  }
}

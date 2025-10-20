import { Injectable, Logger } from '@nestjs/common';
import { FirestoreService } from '../../firestore/firestore.service';
import * as admin from 'firebase-admin';

@Injectable()
export class BulkMessageService {
  private readonly logger = new Logger(BulkMessageService.name);

  constructor(private readonly firestoreService: FirestoreService) {}

  /**
   * Delete multiple messages
   */
  async deleteMessages(
    messageIds: string[],
    conversationId: string,
    businessId: string,
    deleteForEveryone: boolean,
  ): Promise<{ deletedCount: number; failedCount: number }> {
    let deletedCount = 0;
    let failedCount = 0;

    const firestore = admin.firestore();
    const batch = firestore.batch();

    for (const messageId of messageIds) {
      try {
        const messageRef = firestore.collection('messages').doc(messageId);
        
        if (deleteForEveryone) {
          // Permanently delete the message
          batch.delete(messageRef);
        } else {
          // Soft delete - mark as deleted
          batch.update(messageRef, {
            deleted: true,
            deletedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        
        deletedCount++;
      } catch (error) {
        this.logger.error(`Failed to delete message ${messageId}: ${error.message}`);
        failedCount++;
      }
    }

    try {
      await batch.commit();
      this.logger.log(`Batch delete completed: ${deletedCount} deleted, ${failedCount} failed`);
      
      // Update conversation lastMessage if needed
      await this.updateConversationAfterDelete(conversationId);
    } catch (error) {
      this.logger.error(`Error committing batch delete: ${error.message}`);
      throw error;
    }

    return { deletedCount, failedCount };
  }

  /**
   * Mark multiple messages as read
   */
  async markAsRead(
    messageIds: string[],
    conversationId: string,
  ): Promise<{ updatedCount: number }> {
    const firestore = admin.firestore();
    const batch = firestore.batch();
    let updatedCount = 0;

    for (const messageId of messageIds) {
      try {
        const messageRef = firestore.collection('messages').doc(messageId);
        batch.update(messageRef, {
          read: true,
          readAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        updatedCount++;
      } catch (error) {
        this.logger.error(`Failed to mark message ${messageId} as read: ${error.message}`);
      }
    }

    await batch.commit();

    // Update conversation unread count
    await this.updateConversationUnreadCount(conversationId);

    return { updatedCount };
  }

  /**
   * Forward messages to other conversations
   */
  async forwardMessages(
    messageIds: string[],
    sourceConversationId: string,
    targetConversationIds: string[],
    businessId: string,
    withQuote: boolean,
  ): Promise<{ forwardedCount: number }> {
    const firestore = admin.firestore();
    let forwardedCount = 0;

    // Fetch source messages
    const sourceMessages = await Promise.all(
      messageIds.map(async (id) => {
        const doc = await firestore.collection('messages').doc(id).get();
        const data = doc.data();
        if (!data) {
          return null;
        }
        return { id, ...data } as any;
      }),
    );

    // Filter out null messages
    const validMessages = sourceMessages.filter((msg) => msg !== null);

    // Forward to each target conversation
    for (const targetConversationId of targetConversationIds) {
      const batch = firestore.batch();

      for (const sourceMessage of validMessages) {
        try {
          const newMessageRef = firestore.collection('messages').doc();
          
          const forwardedMessage: any = {
            conversationId: targetConversationId,
            businessId,
            text: sourceMessage.text || '',
            messageType: sourceMessage.messageType || 'text',
            platform: 'app',
            direction: 'outgoing',
            status: 'sent',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            read: false,
          };

          // Add quote/forwarding metadata if requested
          if (withQuote) {
            forwardedMessage.forwardedFrom = {
              messageId: sourceMessage.id,
              conversationId: sourceConversationId,
              senderName: sourceMessage.senderName || 'Unknown',
              originalText: sourceMessage.text,
            };
          }

          // Copy attachments if present
          if (sourceMessage.attachments && sourceMessage.attachments.length > 0) {
            forwardedMessage.attachments = sourceMessage.attachments;
          }

          batch.set(newMessageRef, forwardedMessage);
          forwardedCount++;
        } catch (error) {
          this.logger.error(`Failed to forward message: ${error.message}`);
        }
      }

      await batch.commit();

      // Update target conversation
      await this.updateConversationAfterForward(targetConversationId);
    }

    return { forwardedCount };
  }

  /**
   * Export messages to various formats
   */
  async exportMessages(
    messageIds: string[],
    conversationId: string,
    format: 'json' | 'txt' | 'csv',
  ): Promise<{ data: string; downloadUrl?: string }> {
    const firestore = admin.firestore();

    // Fetch messages
    const messages = await Promise.all(
      messageIds.map(async (id) => {
        const doc = await firestore.collection('messages').doc(id).get();
        return doc.data();
      }),
    );

    // Sort by timestamp
    messages.sort((a, b) => {
      const timeA = a?.createdAt?.toMillis() || 0;
      const timeB = b?.createdAt?.toMillis() || 0;
      return timeA - timeB;
    });

    let exportData: string;

    switch (format) {
      case 'json':
        exportData = JSON.stringify(messages, null, 2);
        break;

      case 'txt':
        exportData = messages
          .map((msg) => {
            const timestamp = msg?.createdAt?.toDate().toISOString() || 'Unknown';
            const sender = msg?.senderName || 'Unknown';
            const text = msg?.text || '';
            return `[${timestamp}] ${sender}: ${text}`;
          })
          .join('\n\n');
        break;

      case 'csv':
        const headers = 'Timestamp,Sender,Message,Platform,Direction\n';
        const rows = messages
          .map((msg) => {
            const timestamp = msg?.createdAt?.toDate().toISOString() || '';
            const sender = (msg?.senderName || '').replace(/"/g, '""');
            const text = (msg?.text || '').replace(/"/g, '""');
            const platform = msg?.platform || '';
            const direction = msg?.direction || '';
            return `"${timestamp}","${sender}","${text}","${platform}","${direction}"`;
          })
          .join('\n');
        exportData = headers + rows;
        break;

      default:
        exportData = JSON.stringify(messages);
    }

    // TODO: Upload to Firebase Storage and return download URL
    // For now, return data directly

    return {
      data: exportData,
    };
  }

  /**
   * Update conversation after message deletion
   */
  private async updateConversationAfterDelete(conversationId: string): Promise<void> {
    try {
      const firestore = admin.firestore();
      
      // Get latest non-deleted message
      const latestMessage = await firestore
        .collection('messages')
        .where('conversationId', '==', conversationId)
        .where('deleted', '==', false)
        .orderBy('createdAt', 'desc')
        .limit(1)
        .get();

      if (!latestMessage.empty) {
        const lastMsg = latestMessage.docs[0].data();
        await firestore.collection('conversations').doc(conversationId).update({
          lastMessage: lastMsg.text || '',
          lastMessageAt: lastMsg.createdAt,
        });
      }
    } catch (error) {
      this.logger.error(`Error updating conversation after delete: ${error.message}`);
    }
  }

  /**
   * Update conversation unread count
   */
  private async updateConversationUnreadCount(conversationId: string): Promise<void> {
    try {
      const firestore = admin.firestore();
      
      const unreadMessages = await firestore
        .collection('messages')
        .where('conversationId', '==', conversationId)
        .where('read', '==', false)
        .where('deleted', '==', false)
        .get();

      await firestore.collection('conversations').doc(conversationId).update({
        unreadCount: unreadMessages.size,
      });
    } catch (error) {
      this.logger.error(`Error updating unread count: ${error.message}`);
    }
  }

  /**
   * Update conversation after forwarding
   */
  private async updateConversationAfterForward(conversationId: string): Promise<void> {
    try {
      const firestore = admin.firestore();
      
      await firestore.collection('conversations').doc(conversationId).update({
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      this.logger.error(`Error updating conversation after forward: ${error.message}`);
    }
  }
}

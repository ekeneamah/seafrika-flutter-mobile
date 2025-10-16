import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { Firestore, Timestamp, FieldValue } from '@google-cloud/firestore';
import { AddReactionDto } from './dto/add-reaction.dto';

export interface Reaction {
  id: string;
  messageId: string;
  userId: string;
  businessId: string;
  userName?: string;
  emoji: string;
  platform?: string;
  createdAt: Date;
}

@Injectable()
export class ReactionsService {
  private firestore: Firestore;

  constructor() {
    this.firestore = new Firestore();
  }

  /**
   * Add a reaction to a message
   */
  async addReaction(
    messageId: string,
    dto: AddReactionDto,
  ): Promise<Reaction> {
    try {
      // Check if user already reacted with this emoji
      const existingReaction = await this.firestore
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .where('userId', '==', dto.userId)
        .where('emoji', '==', dto.emoji)
        .limit(1)
        .get();

      if (!existingReaction.empty) {
        // User already reacted with this emoji, return existing reaction
        const doc = existingReaction.docs[0];
        return {
          id: doc.id,
          messageId,
          ...doc.data(),
        } as Reaction;
      }

      // Create new reaction
      const reactionRef = this.firestore
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .doc();

      const now = new Date();
      const reactionData = {
        userId: dto.userId,
        businessId: dto.businessId,
        userName: dto.userName,
        emoji: dto.emoji,
        platform: dto.platform || 'app',
        createdAt: Timestamp.fromDate(now),
      };

      await reactionRef.set(reactionData);

      // Update reaction summary on message document
      await this._updateReactionSummary(messageId, dto.emoji, 1);

      console.log(
        `✅ Reaction added: ${dto.emoji} by ${dto.userId} on message ${messageId}`,
      );

      return {
        id: reactionRef.id,
        messageId,
        ...reactionData,
        createdAt: now,
      };
    } catch (error) {
      console.error('❌ Error adding reaction:', error);
      throw new HttpException(
        'Failed to add reaction',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Remove a reaction from a message
   */
  async removeReaction(messageId: string, reactionId: string): Promise<void> {
    try {
      const reactionRef = this.firestore
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .doc(reactionId);

      const reactionDoc = await reactionRef.get();

      if (!reactionDoc.exists) {
        throw new HttpException('Reaction not found', HttpStatus.NOT_FOUND);
      }

      const reactionData = reactionDoc.data();
      const emoji = reactionData?.emoji;

      // Delete reaction
      await reactionRef.delete();

      // Update reaction summary
      if (emoji) {
        await this._updateReactionSummary(messageId, emoji, -1);
      }

      console.log(`✅ Reaction removed: ${reactionId} from message ${messageId}`);
    } catch (error) {
      console.error('❌ Error removing reaction:', error);
      throw new HttpException(
        'Failed to remove reaction',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get all reactions for a message
   */
  async getReactions(messageId: string): Promise<Reaction[]> {
    try {
      const snapshot = await this.firestore
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .orderBy('createdAt', 'asc')
        .get();

      return snapshot.docs.map((doc) => ({
        id: doc.id,
        messageId,
        ...(doc.data() as Omit<Reaction, 'id' | 'messageId'>),
      }));
    } catch (error) {
      console.error('❌ Error getting reactions:', error);
      throw new HttpException(
        'Failed to get reactions',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Update reaction summary on message document
   * Stores aggregate counts like: { '👍': 5, '❤️': 3 }
   */
  private async _updateReactionSummary(
    messageId: string,
    emoji: string,
    increment: number,
  ): Promise<void> {
    try {
      const messageRef = this.firestore.collection('messages').doc(messageId);

      await messageRef.update({
        [`metadata.reactions.${emoji}`]: FieldValue.increment(increment),
        updatedAt: Timestamp.now(),
      });
    } catch (error) {
      console.error('❌ Error updating reaction summary:', error);
      // Don't throw - this is not critical
    }
  }

  /**
   * Sync reaction to external platform (Messenger/Instagram)
   * Note: As of 2025, Meta Graph API supports reactions on Messenger
   */
  async syncReactionToPlatform(
    messageId: string,
    platform: string,
    emoji: string,
  ): Promise<boolean> {
    try {
      // Get message details
      const messageDoc = await this.firestore
        .collection('messages')
        .doc(messageId)
        .get();

      if (!messageDoc.exists) {
        return false;
      }

      const messageData = messageDoc.data();
      const externalMessageId = messageData?.externalMessageId;
      const integrationId = messageData?.integrationId;

      if (!externalMessageId || !integrationId) {
        return false;
      }

      // Get integration access token
      const integrationDoc = await this.firestore
        .collection('integrations')
        .doc(integrationId)
        .get();

      if (!integrationDoc.exists) {
        return false;
      }

      const accessToken = integrationDoc.data()?.accessToken;

      if (!accessToken) {
        return false;
      }

      // Sync to platform (currently only Messenger supports reactions)
      if (platform === 'messenger') {
        // Meta Graph API endpoint for reactions
        const response = await fetch(
          `https://graph.facebook.com/v21.0/${externalMessageId}/reactions`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              access_token: accessToken,
              reaction: emoji,
            }),
          },
        );

        if (!response.ok) {
          console.error('❌ Failed to sync reaction to Messenger');
          return false;
        }

        console.log(`✅ Reaction synced to Messenger: ${emoji}`);
        return true;
      }

      // Instagram and WhatsApp don't support reactions via API yet
      return false;
    } catch (error) {
      console.error('❌ Error syncing reaction to platform:', error);
      return false;
    }
  }
}

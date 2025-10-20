import { Injectable, Logger } from '@nestjs/common';
import { Firestore } from '@google-cloud/firestore';

export interface MessageDraft {
  id: string;
  userId: string;
  businessId: string;
  conversationId: string;
  text: string;
  attachments: Array<{ type: string; localPath: string }>;
  createdAt: Date;
  updatedAt: Date;
}

export interface SaveDraftDto {
  userId: string;
  businessId: string;
  conversationId: string;
  text: string;
  attachments: Array<{ type: string; localPath: string }>;
}

/**
 * Service for managing message drafts
 * - Stores drafts in Firestore for cross-device sync
 * - Auto-deletes drafts older than 7 days
 */
@Injectable()
export class DraftsService {
  private readonly logger = new Logger(DraftsService.name);
  private readonly firestore: Firestore;
  private readonly DRAFTS_COLLECTION = 'message_drafts';
  private readonly DRAFT_EXPIRY_DAYS = 7;

  constructor() {
    this.firestore = new Firestore();
  }

  /**
   * Generate draft ID from user, business, and conversation
   */
  private generateDraftId(
    userId: string,
    businessId: string,
    conversationId: string,
  ): string {
    return `${businessId}_${userId}_${conversationId}`;
  }

  /**
   * Save or update a draft
   */
  async saveDraft(dto: SaveDraftDto): Promise<MessageDraft> {
    try {
      const draftId = this.generateDraftId(
        dto.userId,
        dto.businessId,
        dto.conversationId,
      );

      const now = new Date();
      const draftRef = this.firestore
        .collection(this.DRAFTS_COLLECTION)
        .doc(draftId);

      // Check if draft exists
      const existingDraft = await draftRef.get();
      const isUpdate = existingDraft.exists;

      const draftData = {
        userId: dto.userId,
        businessId: dto.businessId,
        conversationId: dto.conversationId,
        text: dto.text,
        attachments: dto.attachments,
        updatedAt: now,
        ...(isUpdate ? {} : { createdAt: now }),
      };

      await draftRef.set(draftData, { merge: true });

      this.logger.log(
        `✅ Draft ${isUpdate ? 'updated' : 'saved'}: ${draftId}`,
      );

      return {
        id: draftId,
        ...draftData,
        createdAt: isUpdate
          ? existingDraft.data().createdAt.toDate()
          : draftData.createdAt,
      } as MessageDraft;
    } catch (error) {
      this.logger.error('❌ Error saving draft:', error);
      throw error;
    }
  }

  /**
   * Get draft for a conversation
   */
  async getDraft(
    userId: string,
    businessId: string,
    conversationId: string,
  ): Promise<MessageDraft | null> {
    try {
      const draftId = this.generateDraftId(userId, businessId, conversationId);
      const draftRef = this.firestore
        .collection(this.DRAFTS_COLLECTION)
        .doc(draftId);

      const doc = await draftRef.get();

      if (!doc.exists) {
        return null;
      }

      const data = doc.data();

      // Check if draft is expired (older than 7 days)
      const createdAt = data.createdAt.toDate();
      const daysSinceCreation =
        (Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24);

      if (daysSinceCreation > this.DRAFT_EXPIRY_DAYS) {
        this.logger.log(`🗑️ Deleting expired draft: ${draftId}`);
        await draftRef.delete();
        return null;
      }

      return {
        id: doc.id,
        userId: data.userId,
        businessId: data.businessId,
        conversationId: data.conversationId,
        text: data.text,
        attachments: data.attachments || [],
        createdAt: data.createdAt.toDate(),
        updatedAt: data.updatedAt.toDate(),
      };
    } catch (error) {
      this.logger.error('❌ Error getting draft:', error);
      throw error;
    }
  }

  /**
   * Delete draft (after message sent or user clears)
   */
  async deleteDraft(
    userId: string,
    businessId: string,
    conversationId: string,
  ): Promise<void> {
    try {
      const draftId = this.generateDraftId(userId, businessId, conversationId);
      const draftRef = this.firestore
        .collection(this.DRAFTS_COLLECTION)
        .doc(draftId);

      await draftRef.delete();
      this.logger.log(`✅ Draft deleted: ${draftId}`);
    } catch (error) {
      this.logger.error('❌ Error deleting draft:', error);
      throw error;
    }
  }

  /**
   * Get all drafts for a user (for conversation list indicators)
   */
  async getAllDrafts(
    userId: string,
    businessId: string,
  ): Promise<MessageDraft[]> {
    try {
      const snapshot = await this.firestore
        .collection(this.DRAFTS_COLLECTION)
        .where('userId', '==', userId)
        .where('businessId', '==', businessId)
        .get();

      const drafts: MessageDraft[] = [];
      const expiredDrafts: string[] = [];

      snapshot.forEach((doc) => {
        const data = doc.data();
        const createdAt = data.createdAt.toDate();
        const daysSinceCreation =
          (Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24);

        // Mark expired drafts for deletion
        if (daysSinceCreation > this.DRAFT_EXPIRY_DAYS) {
          expiredDrafts.push(doc.id);
        } else {
          drafts.push({
            id: doc.id,
            userId: data.userId,
            businessId: data.businessId,
            conversationId: data.conversationId,
            text: data.text,
            attachments: data.attachments || [],
            createdAt: data.createdAt.toDate(),
            updatedAt: data.updatedAt.toDate(),
          });
        }
      });

      // Delete expired drafts
      if (expiredDrafts.length > 0) {
        this.logger.log(
          `🗑️ Deleting ${expiredDrafts.length} expired drafts`,
        );
        const batch = this.firestore.batch();
        expiredDrafts.forEach((draftId) => {
          const draftRef = this.firestore
            .collection(this.DRAFTS_COLLECTION)
            .doc(draftId);
          batch.delete(draftRef);
        });
        await batch.commit();
      }

      return drafts;
    } catch (error) {
      this.logger.error('❌ Error getting all drafts:', error);
      throw error;
    }
  }

  /**
   * Cleanup expired drafts (can be called periodically)
   */
  async cleanupExpiredDrafts(): Promise<number> {
    try {
      const snapshot = await this.firestore
        .collection(this.DRAFTS_COLLECTION)
        .get();

      const expiredDrafts: string[] = [];

      snapshot.forEach((doc) => {
        const data = doc.data();
        const createdAt = data.createdAt.toDate();
        const daysSinceCreation =
          (Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24);

        if (daysSinceCreation > this.DRAFT_EXPIRY_DAYS) {
          expiredDrafts.push(doc.id);
        }
      });

      if (expiredDrafts.length > 0) {
        const batch = this.firestore.batch();
        expiredDrafts.forEach((draftId) => {
          const draftRef = this.firestore
            .collection(this.DRAFTS_COLLECTION)
            .doc(draftId);
          batch.delete(draftRef);
        });
        await batch.commit();

        this.logger.log(`🗑️ Cleaned up ${expiredDrafts.length} expired drafts`);
      }

      return expiredDrafts.length;
    } catch (error) {
      this.logger.error('❌ Error cleaning up expired drafts:', error);
      throw error;
    }
  }
}

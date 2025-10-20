import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  UseGuards,
  Request,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { DraftsService } from './drafts.service';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';

/**
 * Controller for message draft operations
 * Handles saving, retrieving, and deleting message drafts
 */
@Controller('messages/drafts')
@UseGuards(JwtAuthGuard)
export class DraftsController {
  constructor(private readonly draftsService: DraftsService) {}

  /**
   * Save or update a draft for a conversation
   * POST /messages/drafts/:conversationId
   */
  @Post(':conversationId')
  async saveDraft(
    @Param('conversationId') conversationId: string,
    @Body()
    body: {
      text: string;
      attachments?: Array<{ type: string; localPath: string }>;
    },
    @Request() req,
  ) {
    try {
      const userId = req.user.userId;
      const businessId = req.user.businessId;

      if (!businessId) {
        throw new HttpException(
          'Business ID required',
          HttpStatus.BAD_REQUEST,
        );
      }

      const draft = await this.draftsService.saveDraft({
        userId,
        businessId,
        conversationId,
        text: body.text,
        attachments: body.attachments || [],
      });

      return {
        success: true,
        draft,
      };
    } catch (error) {
      console.error('❌ Error saving draft:', error);
      throw new HttpException(
        error.message || 'Failed to save draft',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get draft for a conversation
   * GET /messages/drafts/:conversationId
   */
  @Get(':conversationId')
  async getDraft(
    @Param('conversationId') conversationId: string,
    @Request() req,
  ) {
    try {
      const userId = req.user.userId;
      const businessId = req.user.businessId;

      if (!businessId) {
        throw new HttpException(
          'Business ID required',
          HttpStatus.BAD_REQUEST,
        );
      }

      const draft = await this.draftsService.getDraft(
        userId,
        businessId,
        conversationId,
      );

      if (!draft) {
        return {
          success: true,
          draft: null,
        };
      }

      return {
        success: true,
        draft,
      };
    } catch (error) {
      console.error('❌ Error getting draft:', error);
      throw new HttpException(
        error.message || 'Failed to get draft',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Delete draft for a conversation (after message sent)
   * DELETE /messages/drafts/:conversationId
   */
  @Delete(':conversationId')
  async deleteDraft(
    @Param('conversationId') conversationId: string,
    @Request() req,
  ) {
    try {
      const userId = req.user.userId;
      const businessId = req.user.businessId;

      if (!businessId) {
        throw new HttpException(
          'Business ID required',
          HttpStatus.BAD_REQUEST,
        );
      }

      await this.draftsService.deleteDraft(userId, businessId, conversationId);

      return {
        success: true,
        message: 'Draft deleted',
      };
    } catch (error) {
      console.error('❌ Error deleting draft:', error);
      throw new HttpException(
        error.message || 'Failed to delete draft',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get all drafts for current user (for conversation list indicators)
   * GET /messages/drafts
   */
  @Get()
  async getAllDrafts(@Request() req) {
    try {
      const userId = req.user.userId;
      const businessId = req.user.businessId;

      if (!businessId) {
        throw new HttpException(
          'Business ID required',
          HttpStatus.BAD_REQUEST,
        );
      }

      const drafts = await this.draftsService.getAllDrafts(userId, businessId);

      return {
        success: true,
        drafts,
      };
    } catch (error) {
      console.error('❌ Error getting all drafts:', error);
      throw new HttpException(
        error.message || 'Failed to get drafts',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

import {
  Controller,
  Post,
  Delete,
  Param,
  Body,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { ReactionsService } from './reactions.service';
import { AddReactionDto } from './dto/add-reaction.dto';

@ApiTags('Message Reactions')
@Controller('messages/:messageId/reactions')
export class ReactionsController {
  constructor(private readonly reactionsService: ReactionsService) {}

  /**
   * Add a reaction to a message
   * POST /messages/:messageId/reactions
   */
  @Post()
  @ApiOperation({ summary: 'Add reaction to a message' })
  @ApiBearerAuth()
  @ApiParam({ name: 'messageId', description: 'Message ID' })
  async addReaction(
    @Param('messageId') messageId: string,
    @Body() dto: AddReactionDto,
  ) {
    try {
      const reaction = await this.reactionsService.addReaction(messageId, dto);
      return {
        success: true,
        reaction,
      };
    } catch (error) {
      console.error('❌ Error adding reaction:', error);
      throw new HttpException(
        error.message || 'Failed to add reaction',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Remove a reaction from a message
   * DELETE /messages/:messageId/reactions/:reactionId
   */
  @Delete(':reactionId')
  @ApiOperation({ summary: 'Remove reaction from a message' })
  @ApiBearerAuth()
  @ApiParam({ name: 'messageId', description: 'Message ID' })
  @ApiParam({ name: 'reactionId', description: 'Reaction ID' })
  async removeReaction(
    @Param('messageId') messageId: string,
    @Param('reactionId') reactionId: string,
  ) {
    try {
      await this.reactionsService.removeReaction(messageId, reactionId);
      return {
        success: true,
        message: 'Reaction removed successfully',
      };
    } catch (error) {
      console.error('❌ Error removing reaction:', error);
      throw new HttpException(
        error.message || 'Failed to remove reaction',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Get all reactions for a message
   * GET /messages/:messageId/reactions
   */
  @Post('list')
  @ApiOperation({ summary: 'Get all reactions for a message' })
  @ApiBearerAuth()
  @ApiParam({ name: 'messageId', description: 'Message ID' })
  async getReactions(@Param('messageId') messageId: string) {
    try {
      const reactions = await this.reactionsService.getReactions(messageId);
      return {
        success: true,
        reactions,
      };
    } catch (error) {
      console.error('❌ Error getting reactions:', error);
      throw new HttpException(
        error.message || 'Failed to get reactions',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

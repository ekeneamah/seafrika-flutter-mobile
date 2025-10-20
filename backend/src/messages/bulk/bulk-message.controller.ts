import {
  Controller,
  Post,
  Body,
  UseGuards,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiResponse } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { BulkMessageService } from './bulk-message.service';

@ApiTags('Bulk Message Operations')
@Controller('messages/bulk')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class BulkMessageController {
  private readonly logger = new Logger(BulkMessageController.name);

  constructor(private readonly bulkMessageService: BulkMessageService) {}

  @Post('delete')
  @ApiOperation({ summary: 'Delete multiple messages' })
  @ApiResponse({ status: 200, description: 'Messages deleted successfully' })
  async deleteMessages(
    @Body('messageIds') messageIds: string[],
    @Body('conversationId') conversationId: string,
    @Body('businessId') businessId: string,
    @Body('deleteForEveryone') deleteForEveryone = false,
  ) {
    try {
      if (!messageIds || messageIds.length === 0) {
        throw new HttpException('No message IDs provided', HttpStatus.BAD_REQUEST);
      }

      if (!conversationId) {
        throw new HttpException('Conversation ID is required', HttpStatus.BAD_REQUEST);
      }

      this.logger.log(
        `Deleting ${messageIds.length} messages from conversation ${conversationId}`,
      );

      const result = await this.bulkMessageService.deleteMessages(
        messageIds,
        conversationId,
        businessId,
        deleteForEveryone,
      );

      return {
        success: true,
        deletedCount: result.deletedCount,
        failedCount: result.failedCount,
        message: `Deleted ${result.deletedCount} messages`,
      };
    } catch (error) {
      this.logger.error(`Error deleting messages: ${error.message}`);
      throw new HttpException(
        error.message || 'Failed to delete messages',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('mark-read')
  @ApiOperation({ summary: 'Mark multiple messages as read' })
  @ApiResponse({ status: 200, description: 'Messages marked as read' })
  async markAsRead(
    @Body('messageIds') messageIds: string[],
    @Body('conversationId') conversationId: string,
  ) {
    try {
      if (!messageIds || messageIds.length === 0) {
        throw new HttpException('No message IDs provided', HttpStatus.BAD_REQUEST);
      }

      this.logger.log(`Marking ${messageIds.length} messages as read`);

      const result = await this.bulkMessageService.markAsRead(messageIds, conversationId);

      return {
        success: true,
        updatedCount: result.updatedCount,
        message: `Marked ${result.updatedCount} messages as read`,
      };
    } catch (error) {
      this.logger.error(`Error marking messages as read: ${error.message}`);
      throw new HttpException(
        error.message || 'Failed to mark messages as read',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('forward')
  @ApiOperation({ summary: 'Forward messages to other conversations' })
  @ApiResponse({ status: 201, description: 'Messages forwarded successfully' })
  async forwardMessages(
    @Body('messageIds') messageIds: string[],
    @Body('sourceConversationId') sourceConversationId: string,
    @Body('targetConversationIds') targetConversationIds: string[],
    @Body('businessId') businessId: string,
    @Body('withQuote') withQuote = false,
  ) {
    try {
      if (!messageIds || messageIds.length === 0) {
        throw new HttpException('No message IDs provided', HttpStatus.BAD_REQUEST);
      }

      if (!targetConversationIds || targetConversationIds.length === 0) {
        throw new HttpException('No target conversations provided', HttpStatus.BAD_REQUEST);
      }

      this.logger.log(
        `Forwarding ${messageIds.length} messages to ${targetConversationIds.length} conversations`,
      );

      const result = await this.bulkMessageService.forwardMessages(
        messageIds,
        sourceConversationId,
        targetConversationIds,
        businessId,
        withQuote,
      );

      return {
        success: true,
        forwardedCount: result.forwardedCount,
        targetCount: targetConversationIds.length,
        message: `Forwarded ${result.forwardedCount} messages`,
      };
    } catch (error) {
      this.logger.error(`Error forwarding messages: ${error.message}`);
      throw new HttpException(
        error.message || 'Failed to forward messages',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post('export')
  @ApiOperation({ summary: 'Export selected messages' })
  @ApiResponse({ status: 200, description: 'Messages exported successfully' })
  async exportMessages(
    @Body('messageIds') messageIds: string[],
    @Body('conversationId') conversationId: string,
    @Body('format') format: 'json' | 'txt' | 'csv' = 'json',
  ) {
    try {
      if (!messageIds || messageIds.length === 0) {
        throw new HttpException('No message IDs provided', HttpStatus.BAD_REQUEST);
      }

      this.logger.log(`Exporting ${messageIds.length} messages as ${format}`);

      const result = await this.bulkMessageService.exportMessages(
        messageIds,
        conversationId,
        format,
      );

      return {
        success: true,
        format,
        data: result.data,
        downloadUrl: result.downloadUrl,
        message: `Exported ${messageIds.length} messages`,
      };
    } catch (error) {
      this.logger.error(`Error exporting messages: ${error.message}`);
      throw new HttpException(
        error.message || 'Failed to export messages',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

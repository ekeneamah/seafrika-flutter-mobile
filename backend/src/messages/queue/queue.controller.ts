import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Headers,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { QueueService } from './queue.service';
import { QueueMessageDto } from './dto/queue-message.dto';

@ApiTags('Message Queue')
@Controller('messages/queue')
export class QueueController {
  constructor(private readonly queueService: QueueService) {}

  @Post()
  @ApiOperation({ summary: 'Add message to queue for retry' })
  @ApiResponse({ status: 201, description: 'Message queued successfully' })
  @ApiResponse({ status: 400, description: 'Invalid request' })
  @ApiResponse({ status: 401, description: 'Unauthorized' })
  async queueMessage(
    @Body() queueMessageDto: QueueMessageDto,
    @Headers('authorization') auth: string,
  ) {
    try {
      // Extract user ID from auth token (simplified - implement proper JWT validation)
      if (!auth || !auth.startsWith('Bearer ')) {
        throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
      }

      // Validate required fields
      if (
        !queueMessageDto.messageId ||
        !queueMessageDto.conversationId ||
        !queueMessageDto.platform
      ) {
        throw new HttpException(
          'Missing required fields: messageId, conversationId, platform',
          HttpStatus.BAD_REQUEST,
        );
      }

      // Queue the message
      const queuedMessage = await this.queueService.queueMessage(
        queueMessageDto,
      );

      return {
        success: true,
        queueId: queuedMessage.id,
        message: 'Message queued successfully',
        retryCount: queuedMessage.retryCount,
        nextRetryAt: queuedMessage.nextRetryAt,
      };
    } catch (error) {
      console.error('Error queueing message:', error);
      throw new HttpException(
        error.message || 'Failed to queue message',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Post(':queueId/retry')
  @ApiOperation({ summary: 'Manually retry a queued message' })
  @ApiResponse({ status: 200, description: 'Retry attempted' })
  @ApiResponse({ status: 404, description: 'Queue item not found' })
  async retryQueuedMessage(
    @Param('queueId') queueId: string,
    @Headers('authorization') auth: string,
  ) {
    try {
      if (!auth || !auth.startsWith('Bearer ')) {
        throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
      }

      const result = await this.queueService.retryQueuedMessage(queueId);

      return {
        success: result.success,
        message: result.message,
        queueId: queueId,
        status: result.status,
      };
    } catch (error) {
      console.error('Error retrying queued message:', error);
      throw new HttpException(
        error.message || 'Failed to retry message',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('business/:businessId')
  @ApiOperation({ summary: 'Get all queued messages for a business' })
  @ApiResponse({ status: 200, description: 'Queue retrieved successfully' })
  async getBusinessQueue(
    @Param('businessId') businessId: string,
    @Headers('authorization') auth: string,
  ) {
    try {
      if (!auth || !auth.startsWith('Bearer ')) {
        throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
      }

      const queuedMessages = await this.queueService.getBusinessQueue(
        businessId,
      );

      return {
        success: true,
        count: queuedMessages.length,
        messages: queuedMessages,
      };
    } catch (error) {
      console.error('Error retrieving business queue:', error);
      throw new HttpException(
        error.message || 'Failed to retrieve queue',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('conversation/:conversationId')
  @ApiOperation({ summary: 'Get queued messages for a conversation' })
  @ApiResponse({ status: 200, description: 'Queue retrieved successfully' })
  async getConversationQueue(
    @Param('conversationId') conversationId: string,
    @Headers('authorization') auth: string,
  ) {
    try {
      if (!auth || !auth.startsWith('Bearer ')) {
        throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
      }

      const queuedMessages = await this.queueService.getConversationQueue(
        conversationId,
      );

      return {
        success: true,
        count: queuedMessages.length,
        messages: queuedMessages,
      };
    } catch (error) {
      console.error('Error retrieving conversation queue:', error);
      throw new HttpException(
        error.message || 'Failed to retrieve queue',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

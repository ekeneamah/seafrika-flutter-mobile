import {
  Controller,
  Post,
  Get,
  Delete,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { ThreadsService } from './threads.service';
import { ReplyMessageDto, ThreadResponseDto } from './dto/reply-message.dto';

@ApiTags('Message Threads')
@Controller('messages/threads')
// @UseGuards(JwtAuthGuard) // Uncomment when JWT auth is set up
export class ThreadsController {
  private readonly logger = new Logger(ThreadsController.name);

  constructor(private readonly threadsService: ThreadsService) {}

  @Post('reply')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Reply to a message',
    description: 'Send a reply to a specific message and create thread relationship',
  })
  @ApiResponse({
    status: 201,
    description: 'Reply created successfully',
    schema: {
      example: {
        success: true,
        message: {
          id: 'msg_reply_123',
          content: 'This is a reply',
          replyToId: 'msg_parent_456',
          threadDepth: 1,
          createdAt: '2025-10-19T12:00:00Z',
        },
      },
    },
  })
  @ApiResponse({ status: 400, description: 'Invalid request or thread depth exceeded' })
  @ApiResponse({ status: 404, description: 'Parent message not found' })
  // @ApiBearerAuth()
  async replyToMessage(@Body() replyMessageDto: ReplyMessageDto) {
    this.logger.log(`Creating reply to message ${replyMessageDto.parentMessageId}`);
    return await this.threadsService.replyToMessage(replyMessageDto);
  }

  @Get(':messageId')
  @ApiOperation({
    summary: 'Get thread messages',
    description: 'Retrieve all replies for a specific message (thread view)',
  })
  @ApiParam({
    name: 'messageId',
    description: 'ID of the parent message',
    example: 'msg_123',
  })
  @ApiResponse({
    status: 200,
    description: 'Thread retrieved successfully',
    type: ThreadResponseDto,
    schema: {
      example: {
        parentMessageId: 'msg_123',
        replyCount: 3,
        threadDepth: 0,
        messages: [
          {
            id: 'msg_123',
            content: 'Parent message',
            threadDepth: 0,
            replyCount: 3,
          },
          {
            id: 'msg_reply_1',
            content: 'First reply',
            replyToId: 'msg_123',
            threadDepth: 1,
            replies: [],
          },
        ],
      },
    },
  })
  @ApiResponse({ status: 404, description: 'Message not found' })
  // @ApiBearerAuth()
  async getThreadMessages(@Param('messageId') messageId: string): Promise<ThreadResponseDto> {
    this.logger.log(`Getting thread for message ${messageId}`);
    return await this.threadsService.getThreadMessages(messageId);
  }

  @Get(':messageId/preview')
  @ApiOperation({
    summary: 'Get thread preview',
    description: 'Get parent message preview for a reply message',
  })
  @ApiParam({
    name: 'messageId',
    description: 'ID of the reply message',
    example: 'msg_reply_123',
  })
  @ApiResponse({
    status: 200,
    description: 'Thread preview retrieved',
    schema: {
      example: {
        id: 'msg_parent_456',
        content: 'Parent message preview text...',
        senderId: 'user_123',
        createdAt: '2025-10-19T11:00:00Z',
      },
    },
  })
  @ApiResponse({ status: 404, description: 'Message not found' })
  // @ApiBearerAuth()
  async getThreadPreview(@Param('messageId') messageId: string) {
    this.logger.log(`Getting thread preview for message ${messageId}`);
    return await this.threadsService.getThreadPreview(messageId);
  }

  @Delete(':messageId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    summary: 'Delete a reply',
    description: 'Soft delete a reply message and update parent reply count',
  })
  @ApiParam({
    name: 'messageId',
    description: 'ID of the reply message to delete',
    example: 'msg_reply_123',
  })
  @ApiResponse({ status: 204, description: 'Reply deleted successfully' })
  @ApiResponse({ status: 404, description: 'Message not found' })
  // @ApiBearerAuth()
  async deleteReply(@Param('messageId') messageId: string) {
    this.logger.log(`Deleting reply ${messageId}`);
    await this.threadsService.deleteReply(messageId);
  }
}

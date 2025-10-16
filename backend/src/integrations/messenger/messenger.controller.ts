import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Body,
  Headers,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiParam, ApiQuery, ApiBody, ApiBearerAuth } from '@nestjs/swagger';
import { MessengerService } from './messenger.service';
import { FacebookService } from '../facebook/facebook.service';
import { FirestoreService } from '../../firebase/firestore.service';

@ApiTags('Messenger Integration')
@Controller('integrations/messenger')
@ApiBearerAuth()
export class MessengerController {
  private readonly logger = new Logger(MessengerController.name);

  constructor(
    private readonly messengerService: MessengerService,
    private readonly facebookService: FacebookService,
    private readonly firestoreService: FirestoreService,
  ) {}

  @Get(':integrationId/analytics')
  @ApiOperation({ 
    summary: 'Get Messenger analytics for an integration',
    description: 'Fetch Messenger insights and analytics for a given integration using the stored access token'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Analytics retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        totalConversations: { type: 'number' },
        activeConversations: { type: 'number' },
        totalMessages: { type: 'number' },
        responseRate: { type: 'number' },
        averageResponseTime: { type: 'number' },
        period: { type: 'string' },
        pageInfo: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            name: { type: 'string' }
          }
        }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - invalid parameters' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 403, description: 'Forbidden - insufficient permissions' })
  @ApiResponse({ status: 404, description: 'Integration not found or inactive' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async getMessengerAnalytics(
    @Param('integrationId') integrationId: string,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    // Validate auth header
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    if (!integrationId) {
      throw new HttpException(
        'Integration ID is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      this.logger.log(`Fetching Messenger analytics for integration: ${integrationId}`);
      
      const result = await this.messengerService.getMessengerAnalytics(integrationId);

      this.logger.log(`Successfully fetched Messenger analytics`);
      
      return result;
    } catch (error) {
      this.logger.error(`Failed to fetch Messenger analytics: ${error.message}`, error.stack);
      
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Map common error types
      if (error.message.includes('not found')) {
        throw new HttpException(
          'Integration not found or inactive',
          HttpStatus.NOT_FOUND,
        );
      }
      
      if (error.message.includes('unauthorized') || error.message.includes('invalid token')) {
        throw new HttpException(
          'Invalid or expired access token',
          HttpStatus.UNAUTHORIZED,
        );
      }
      
      if (error.message.includes('rate limit')) {
        throw new HttpException(
          'Facebook API rate limit exceeded',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      
      throw new HttpException(
        'Failed to fetch Messenger analytics',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get(':integrationId/conversations')
  @ApiOperation({ 
    summary: 'Get Messenger conversations for an integration',
    description: 'Fetch recent Messenger conversations for a given integration using the stored access token'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiQuery({ 
    name: 'limit', 
    required: false, 
    description: 'Number of conversations to return (default: 25, max: 50)',
    type: Number
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Conversations retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        conversations: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string' },
              participants: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    id: { type: 'string' },
                    name: { type: 'string' }
                  }
                }
              },
              messages: {
                type: 'object',
                properties: {
                  data: {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        id: { type: 'string' },
                        message: { type: 'string' },
                        created_time: { type: 'string' },
                        from: {
                          type: 'object',
                          properties: {
                            id: { type: 'string' },
                            name: { type: 'string' }
                          }
                        }
                      }
                    }
                  }
                }
              },
              updated_time: { type: 'string' }
            }
          }
        },
        paging: {
          type: 'object',
          properties: {
            cursors: {
              type: 'object',
              properties: {
                after: { type: 'string' }
              }
            },
            next: { type: 'string' }
          }
        }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - invalid parameters' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 403, description: 'Forbidden - insufficient permissions' })
  @ApiResponse({ status: 404, description: 'Integration not found or inactive' })
  @ApiResponse({ status: 500, description: 'Internal server error' })
  async getMessengerConversations(
    @Param('integrationId') integrationId: string,
    @Query('limit') limit?: number,
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    // Validate auth header
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    if (!integrationId) {
      throw new HttpException(
        'Integration ID is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Validate limit parameter
    const parsedLimit = limit ? Math.min(Math.max(parseInt(String(limit)), 1), 50) : 25;

    try {
      this.logger.log(`Fetching Messenger conversations for integration: ${integrationId}`);
      
      const result = await this.messengerService.getMessengerConversations(
        integrationId,
        parsedLimit
      );

      this.logger.log(`Successfully fetched ${result.conversations?.length || 0} conversations`);
      
      return result;
    } catch (error) {
      this.logger.error(`Failed to fetch Messenger conversations: ${error.message}`, error.stack);
      
      if (error instanceof HttpException) {
        throw error;
      }
      
      // Map common error types
      if (error.message.includes('not found')) {
        throw new HttpException(
          'Integration not found or inactive',
          HttpStatus.NOT_FOUND,
        );
      }
      
      if (error.message.includes('unauthorized') || error.message.includes('invalid token')) {
        throw new HttpException(
          'Invalid or expired access token',
          HttpStatus.UNAUTHORIZED,
        );
      }
      
      if (error.message.includes('rate limit')) {
        throw new HttpException(
          'Facebook API rate limit exceeded',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
      
      throw new HttpException(
        'Failed to fetch Messenger conversations',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
  /**
   * Send a message via Messenger
   * Sends a message to a recipient on Messenger and updates Firestore with the sent status
   */
  @Post(':integrationId/send')
  @ApiOperation({ 
    summary: 'Send Messenger message',
    description: 'Send a message to a recipient on Facebook Messenger. Supports text, images, videos, audio, and files.'
  })
  @ApiParam({ 
    name: 'integrationId', 
    description: 'The integration ID from Firestore' 
  })
  @ApiBody({
    description: 'Message data to send',
    schema: {
      type: 'object',
      required: ['messageId', 'conversationId', 'recipientId', 'message'],
      properties: {
        messageId: { 
          type: 'string', 
          description: 'The Firestore message document ID',
          example: 'msg_abc123'
        },
        conversationId: { 
          type: 'string', 
          description: 'The Firestore conversation ID',
          example: 'conv_xyz789'
        },
        recipientId: { 
          type: 'string', 
          description: 'The recipient\'s Facebook/Messenger PSID',
          example: '1234567890'
        },
        message: { 
          type: 'string', 
          description: 'The message text content',
          example: 'Hello! How can I help you today?'
        },
        messageType: { 
          type: 'string', 
          enum: ['text', 'image', 'video', 'audio', 'file'],
          default: 'text',
          description: 'Type of message being sent'
        },
        attachmentUrl: { 
          type: 'string', 
          description: 'URL of attachment (required for non-text messages)',
          example: 'https://example.com/image.jpg'
        }
      }
    }
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Message sent successfully',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        message_id: { type: 'string', description: 'Platform message ID from Facebook' },
        recipient_id: { type: 'string', description: 'Recipient PSID' },
        messageId: { type: 'string', description: 'Firestore message ID' }
      }
    }
  })
  @ApiResponse({ status: 400, description: 'Bad request - missing required fields' })
  @ApiResponse({ status: 401, description: 'Unauthorized - invalid or missing auth token' })
  @ApiResponse({ status: 404, description: 'Integration not found' })
  @ApiResponse({ status: 500, description: 'Failed to send message' })
  async sendMessage(
    @Param('integrationId') integrationId: string,
    @Body() body: {
      messageId: string;
      conversationId: string;
      recipientId: string;
      message: string;
      messageType?: 'text' | 'image' | 'video' | 'audio' | 'file';
      attachmentUrl?: string;
    },
    @Headers('authorization') authHeader?: string,
  ): Promise<any> {
    // Validate auth header
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new HttpException(
        'Missing or invalid Authorization header',
        HttpStatus.UNAUTHORIZED,
      );
    }

    // Validate required fields
    if (!integrationId || !body.messageId || !body.conversationId || !body.recipientId || !body.message) {
      throw new HttpException(
        'Missing required fields: integrationId, messageId, conversationId, recipientId, and message are required',
        HttpStatus.BAD_REQUEST,
      );
    }

    // Validate attachment URL for non-text messages
    if (body.messageType && body.messageType !== 'text' && !body.attachmentUrl) {
      throw new HttpException(
        'attachmentUrl is required for non-text messages',
        HttpStatus.BAD_REQUEST,
      );
    }

    try {
      this.logger.log(`Sending Messenger message for integration: ${integrationId}, recipient: ${body.recipientId}`);

      // 1. Call FacebookService to send message via Meta Graph API
      const result = await this.facebookService.sendMessage(
        integrationId,
        body.recipientId,
        body.message,
        body.messageType || 'text',
        body.attachmentUrl
      );

      this.logger.log(`Message sent successfully. Platform message_id: ${result.message_id}`);

      // 2. Update Firestore with sent status and platform message ID
      try {
        await this.firestoreService.updateDocument(
          'messages',
          body.messageId,
          {
            'metadata.status': 'sent',
            'metadata.platformMessageId': result.message_id,
            'metadata.sentAt': new Date(),
          }
        );
        this.logger.log(`Firestore updated for message: ${body.messageId}`);
      } catch (firestoreError) {
        // Log but don't fail the request if Firestore update fails
        this.logger.error(`Failed to update Firestore for message ${body.messageId}:`, firestoreError.message);
      }

      // 3. Return success response
      return {
        success: true,
        message_id: result.message_id,
        recipient_id: result.recipient_id,
        messageId: body.messageId,
      };

    } catch (error) {
      this.logger.error(`Failed to send Messenger message: ${error.message}`, error.stack);

      // Update Firestore with failed status
      try {
        await this.firestoreService.updateDocument(
          'messages',
          body.messageId,
          {
            'metadata.status': 'failed',
            'metadata.error': error.message,
            'metadata.failedAt': new Date(),
          }
        );
      } catch (firestoreError) {
        this.logger.error(`Failed to update Firestore with error status:`, firestoreError.message);
      }

      if (error instanceof HttpException) {
        throw error;
      }

      // Map common Facebook API errors
      if (error.message.includes('not found')) {
        throw new HttpException(
          'Integration or recipient not found',
          HttpStatus.NOT_FOUND,
        );
      }

      if (error.message.includes('unauthorized') || error.message.includes('invalid token')) {
        throw new HttpException(
          'Invalid or expired access token',
          HttpStatus.UNAUTHORIZED,
        );
      }

      if (error.message.includes('rate limit')) {
        throw new HttpException(
          'Facebook API rate limit exceeded. Please try again later.',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      throw new HttpException(
        `Failed to send message: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}


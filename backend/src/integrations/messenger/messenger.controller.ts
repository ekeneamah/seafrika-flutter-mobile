import {
  Controller,
  Get,
  Param,
  Query,
  Headers,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiParam, ApiQuery, ApiBearerAuth } from '@nestjs/swagger';
import { MessengerService } from './messenger.service';

@ApiTags('Messenger Integration')
@Controller('integrations/messenger')
@ApiBearerAuth()
export class MessengerController {
  private readonly logger = new Logger(MessengerController.name);

  constructor(private readonly messengerService: MessengerService) {}

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
}
import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiResponse,
  ApiBody,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TextModerationService } from './text-moderation.service';
import { GoogleApiTestService } from './google-api-test.service';
import { FirestoreService } from '../firestore/firestore.service';
import { ModerateTextDto } from './dto/moderate-text.dto';

@ApiTags('Messages')
@Controller('messages')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class MessagesController {
  private readonly logger = new Logger(MessagesController.name);

  constructor(
    private readonly textModerationService: TextModerationService,
    private readonly googleApiTestService: GoogleApiTestService,
    private readonly firestoreService: FirestoreService,
  ) {}

  /**
   * Test Google Cloud API permissions
   * GET /messages/test-google-apis
   */
  @Get('test-google-apis')
  @ApiOperation({
    summary: 'Test Google Cloud Vision and Natural Language API permissions',
    description: 'Verifies that the service account has proper permissions to use Google Cloud APIs',
  })
  @ApiResponse({
    status: 200,
    description: 'API test results',
    schema: {
      type: 'object',
      properties: {
        vision: {
          type: 'object',
          properties: {
            success: { type: 'boolean' },
            message: { type: 'string' },
          },
        },
        language: {
          type: 'object',
          properties: {
            success: { type: 'boolean' },
            message: { type: 'string' },
          },
        },
      },
    },
  })
  async testGoogleApis() {
    try {
      this.logger.log('Testing Google Cloud API permissions...');
      const results = await this.googleApiTestService.testAll();
      
      this.logger.log(`Vision API: ${results.vision.success ? '✅' : '❌'} - ${results.vision.message}`);
      this.logger.log(`Language API: ${results.language.success ? '✅' : '❌'} - ${results.language.message}`);
      
      return results;
    } catch (error) {
      this.logger.error(`API test failed: ${error.message}`, error.stack);
      throw new HttpException(
        `API test failed: ${error.message}`,
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Moderate text content before sending
   * POST /messages/moderate-text
   */
  @Post('moderate-text')
  @ApiOperation({
    summary: 'Moderate text content for inappropriate language',
    description:
      'Analyzes text for profanity, spam, toxic language, threats, and phishing URLs. ' +
      'Returns moderation result with confidence scores and recommended action.',
  })
  @ApiBody({ type: ModerateTextDto })
  @ApiResponse({
    status: 200,
    description: 'Text moderation completed',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        isSafe: { type: 'boolean' },
        categories: {
          type: 'object',
          properties: {
            toxic: { type: 'number' },
            profanity: { type: 'number' },
            threat: { type: 'number' },
            insult: { type: 'number' },
            identity_hate: { type: 'number' },
            spam: { type: 'number' },
            phishing: { type: 'number' },
          },
        },
        reasons: { type: 'array', items: { type: 'string' } },
        action: { type: 'string', enum: ['allow', 'block', 'review'] },
        sentiment: {
          type: 'object',
          properties: {
            score: { type: 'number' },
            magnitude: { type: 'number' },
          },
        },
      },
    },
  })
  @ApiResponse({
    status: 400,
    description: 'Message blocked due to policy violation',
  })
  async moderateText(@Body() dto: ModerateTextDto) {
    try {
      this.logger.log(
        `Moderating text for conversation: ${dto.conversationId || 'unknown'}`,
      );

      const result = await this.textModerationService.moderateText(dto.text);

      // If text is not safe and action is block, throw error
      if (!result.isSafe && result.action === 'block') {
        this.logger.warn(
          `Text blocked: ${result.reasons.join(', ')} - Text: ${dto.text.substring(0, 50)}...`,
        );

        throw new HttpException(
          {
            statusCode: HttpStatus.BAD_REQUEST,
            message: `Message blocked: ${result.reasons.join(', ')}`,
            error: 'Content Policy Violation',
            categories: result.categories,
            reasons: result.reasons,
          },
          HttpStatus.BAD_REQUEST,
        );
      }

      // If action is review, log for manual review but allow
      if (result.action === 'review') {
        this.logger.log(
          `Text flagged for review: ${result.reasons.join(', ')} - ConversationId: ${dto.conversationId}`,
        );
      }

      return {
        success: true,
        ...result,
      };
    } catch (error) {
      if (error instanceof HttpException) {
        throw error;
      }

      this.logger.error(
        `Text moderation failed: ${error.message}`,
        error.stack,
      );

      // Fail-open: Allow message on service error
      return {
        success: true,
        isSafe: true,
        categories: {
          toxic: 0,
          profanity: 0,
          threat: 0,
          insult: 0,
          identity_hate: 0,
          spam: 0,
          phishing: 0,
        },
        reasons: ['Moderation service error - flagged for manual review'],
        action: 'review',
      };
    }
  }

  /**
   * Batch moderate multiple texts
   * POST /messages/moderate-batch
   */
  @Post('moderate-batch')
  @ApiOperation({
    summary: 'Moderate multiple text messages in batch',
    description: 'Batch moderation for improved performance when checking multiple messages.',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        texts: {
          type: 'array',
          items: { type: 'string' },
          description: 'Array of text messages to moderate',
        },
        conversationId: {
          type: 'string',
          description: 'Conversation ID for context',
        },
      },
    },
  })
  @ApiResponse({
    status: 200,
    description: 'Batch moderation completed',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        results: { type: 'array' },
      },
    },
  })
  async moderateBatch(
    @Body('texts') texts: string[],
    @Body('conversationId') conversationId?: string,
  ) {
    try {
      if (!texts || texts.length === 0) {
        throw new HttpException(
          'No texts provided for moderation',
          HttpStatus.BAD_REQUEST,
        );
      }

      this.logger.log(
        `Batch moderating ${texts.length} texts for conversation: ${conversationId || 'unknown'}`,
      );

      const results = await this.textModerationService.moderateTexts(texts);

      return {
        success: true,
        results,
      };
    } catch (error) {
      this.logger.error(
        `Batch moderation failed: ${error.message}`,
        error.stack,
      );

      throw new HttpException(
        error.message || 'Batch moderation failed',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  /**
   * Analyze sentiment for all conversations in an integration (Admin Dashboard Analytics)
   * POST /messages/analyze-integration-sentiment
   */
  @Post('analyze-integration-sentiment')
  @ApiOperation({
    summary: 'Analyze sentiment of all conversations in an integration (Admin Analytics)',
    description:
      'Fetches all conversations and messages for a specific integrationId from Firestore, ' +
      'then uses Google Cloud Natural Language API to analyze sentiment per conversation. ' +
      'This is for admin dashboard insights, NOT for real-time message blocking.',
  })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        integrationId: {
          type: 'string',
          description: 'Integration ID (e.g., Instagram, WhatsApp) to fetch all conversations',
        },
        limit: {
          type: 'number',
          description: 'Maximum number of conversations to analyze (default: 50)',
        },
      },
      required: ['integrationId'],
    },
  })
  @ApiResponse({
    status: 200,
    description: 'Sentiment analysis results for all conversations',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        integrationId: { type: 'string' },
        totalConversations: { type: 'number' },
        conversations: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              conversationId: { type: 'string' },
              messageCount: { type: 'number' },
              analysis: {
                type: 'object',
                properties: {
                  overallSentiment: {
                    type: 'object',
                    properties: {
                      score: { type: 'number', description: 'Score from -1 (negative) to +1 (positive)' },
                      magnitude: { type: 'number', description: 'Strength of emotion' },
                      label: {
                        type: 'string',
                        enum: ['very_positive', 'positive', 'neutral', 'negative', 'very_negative'],
                      },
                    },
                  },
                  messageCount: { type: 'number' },
                  sentimentDistribution: {
                    type: 'object',
                    properties: {
                      positive: { type: 'number' },
                      neutral: { type: 'number' },
                      negative: { type: 'number' },
                    },
                  },
                  categories: {
                    type: 'array',
                    items: { type: 'string' },
                    description: 'Content categories detected',
                  },
                  warnings: {
                    type: 'array',
                    items: { type: 'string' },
                    description: 'Potential issues flagged for review',
                  },
                },
              },
            },
          },
        },
      },
    },
  })
  @ApiResponse({
    status: 400,
    description: 'Bad request - missing integrationId',
  })
  @ApiResponse({
    status: 404,
    description: 'No conversations found for this integration',
  })
  async analyzeIntegrationSentiment(
    @Body('integrationId') integrationId: string,
    @Body('limit') limit?: number,
  ) {
    try {
      if (!integrationId) {
        throw new HttpException(
          'integrationId is required',
          HttpStatus.BAD_REQUEST,
        );
      }

      const conversationLimit = limit || 50;

      this.logger.log(
        `Fetching conversations for integration: ${integrationId} (limit: ${conversationLimit})`,
      );

      // Step 1: Fetch all conversations for this integration
      const conversations = await this.firestoreService.getDocuments(
        'conversations',
        [{ field: 'integrationId', operator: '==', value: integrationId }],
        { field: 'lastMessageAt', direction: 'desc' },
        conversationLimit,
      );

      if (!conversations || conversations.length === 0) {
        throw new HttpException(
          'No conversations found for this integration',
          HttpStatus.NOT_FOUND,
        );
      }

      this.logger.log(`Found ${conversations.length} conversations`);

      // Step 2: For each conversation, fetch messages and analyze sentiment
      const conversationAnalyses = await Promise.all(
        conversations.map(async (conversation: any) => {
          try {
            // Fetch messages for this conversation
            const messages = await this.firestoreService.getDocuments(
              'messages',
              [
                { field: 'conversationId', operator: '==', value: conversation.id },
                { field: 'integrationId', operator: '==', value: integrationId },
              ],
              { field: 'createdAt', direction: 'asc' },
            );

            // Extract text messages
            const messageTexts = messages
              .filter((msg: any) => msg.type === 'text' && msg.text)
              .map((msg: any) => msg.text);

            if (messageTexts.length === 0) {
              return {
                conversationId: conversation.id,
                messageCount: 0,
                analysis: null,
                error: 'No text messages found',
              };
            }

            // Analyze sentiment
            const analysis = await this.textModerationService.analyzeConversationSentiment(
              messageTexts,
            );

            return {
              conversationId: conversation.id,
              messageCount: messageTexts.length,
              analysis,
            };
          } catch (error) {
            this.logger.error(
              `Failed to analyze conversation ${conversation.id}: ${error.message}`,
            );
            return {
              conversationId: conversation.id,
              messageCount: 0,
              analysis: null,
              error: error.message,
            };
          }
        }),
      );

      // Filter out conversations with errors
      const successfulAnalyses = conversationAnalyses.filter(
        (conv) => conv.analysis !== null,
      );

      this.logger.log(
        `Successfully analyzed ${successfulAnalyses.length}/${conversations.length} conversations`,
      );

      return {
        success: true,
        integrationId,
        totalConversations: conversations.length,
        analyzedConversations: successfulAnalyses.length,
        conversations: conversationAnalyses,
      };
    } catch (error) {
      this.logger.error(
        `Integration sentiment analysis failed: ${error.message}`,
        error.stack,
      );

      throw new HttpException(
        error.message || 'Integration sentiment analysis failed',
        error.status || HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }
}

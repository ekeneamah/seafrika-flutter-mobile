import { 
  Controller, 
  Post, 
  Get, 
  Body, 
  Query, 
  HttpStatus, 
  HttpException, 
  Logger,
  Headers
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiQuery, ApiBody } from '@nestjs/swagger';
import { FacebookWebhookService } from './facebook-webhook.service';
import { FacebookWebhookDto } from './dto/facebook-webhook.dto';

@ApiTags('Facebook Webhooks')
@Controller('webhooks/facebook')
export class FacebookWebhookController {
  private readonly logger = new Logger(FacebookWebhookController.name);

  constructor(
    private readonly facebookWebhookService: FacebookWebhookService,
  ) {}

  @Get()
  @ApiOperation({ 
    summary: 'Verify Facebook webhook',
    description: 'Webhook verification endpoint for Facebook Graph API'
  })
  @ApiQuery({ 
    name: 'hub.mode', 
    description: 'Webhook verification mode' 
  })
  @ApiQuery({ 
    name: 'hub.verify_token', 
    description: 'Webhook verification token' 
  })
  @ApiQuery({ 
    name: 'hub.challenge', 
    description: 'Webhook verification challenge' 
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Webhook verified successfully' 
  })
  @ApiResponse({ 
    status: 403, 
    description: 'Webhook verification failed' 
  })
  async verifyWebhook(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') verifyToken: string,
    @Query('hub.challenge') challenge: string,
  ): Promise<string> {
    this.logger.log('Facebook webhook verification request received');
    this.logger.log(`Mode: ${mode}, Verify Token: ${verifyToken}, Challenge: ${challenge}`);

    // Get expected verify token from environment variables
    const expectedVerifyToken = process.env.FACEBOOK_WEBHOOK_VERIFY_TOKEN || 'seafrika_facebook_webhook_2024';

    if (mode === 'subscribe' && verifyToken === expectedVerifyToken) {
      this.logger.log('Facebook webhook verified successfully');
      return challenge;
    } else {
      this.logger.warn('Facebook webhook verification failed');
      throw new HttpException(
        'Webhook verification failed',
        HttpStatus.FORBIDDEN,
      );
    }
  }

  @Post()
  @ApiOperation({ 
    summary: 'Receive Facebook webhook',
    description: 'Endpoint to receive Facebook Graph API webhook events'
  })
  @ApiBody({ 
    type: FacebookWebhookDto,
    description: 'Facebook webhook payload'
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Webhook processed successfully' 
  })
  @ApiResponse({ 
    status: 400, 
    description: 'Invalid webhook payload' 
  })
  @ApiResponse({ 
    status: 401, 
    description: 'Webhook signature verification failed' 
  })
  async receiveWebhook(
    @Body() webhookData: FacebookWebhookDto,
    @Headers('x-hub-signature-256') signature?: string,
  ): Promise<{ status: string }> {
    this.logger.log('Facebook webhook received');
    this.logger.log(`Webhook object: ${webhookData.object}`);
    this.logger.log(`Number of entries: ${webhookData.entry?.length || 0}`);

    // Verify webhook signature if provided
    if (signature) {
      const isValid = await this.verifyWebhookSignature(JSON.stringify(webhookData), signature);
      if (!isValid) {
        this.logger.warn('Facebook webhook signature verification failed');
        throw new HttpException(
          'Webhook signature verification failed',
          HttpStatus.UNAUTHORIZED,
        );
      }
    }

    // Process webhook data based on object type
    try {
      if (webhookData.object === 'page') {
        // Handle page events (posts, comments, reactions, etc.)
        await this.facebookWebhookService.processFacebookWebhook(webhookData);
        this.logger.log('Facebook page webhook processed successfully');
      } else if (webhookData.object === 'messaging') {
        // Handle Messenger events (messages, postbacks, delivery, read, etc.)
        await this.facebookWebhookService.processMessengerWebhook(webhookData);
        this.logger.log('Facebook Messenger webhook processed successfully');
      } else if (webhookData.object === 'instagram') {
        // Handle Instagram events (comments, mentions, messages)
        await this.processInstagramWebhook(webhookData);
        this.logger.log('Instagram webhook processed successfully');
      } else {
        this.logger.warn(`Unsupported Facebook webhook object type: ${webhookData.object}`);
      }
    } catch (error) {
      this.logger.error('Failed to process Facebook webhook:', error);
      throw new HttpException(
        'Failed to process webhook',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }

    return { status: 'ok' };
  }

  @Post('messenger')
  @ApiOperation({ 
    summary: 'Receive Messenger webhook',
    description: 'Dedicated endpoint for Facebook Messenger webhook events'
  })
  @ApiBody({ 
    description: 'Messenger webhook payload'
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Messenger webhook processed successfully' 
  })
  async receiveMessengerWebhook(
    @Body() webhookData: any,
    @Headers('x-hub-signature-256') signature?: string,
  ): Promise<{ status: string }> {
    this.logger.log('Messenger webhook received');
    this.logger.log(`Number of entries: ${webhookData.entry?.length || 0}`);

    // Verify webhook signature if provided
    if (signature) {
      const isValid = await this.verifyWebhookSignature(JSON.stringify(webhookData), signature);
      if (!isValid) {
        this.logger.warn('Messenger webhook signature verification failed');
        throw new HttpException(
          'Webhook signature verification failed',
          HttpStatus.UNAUTHORIZED,
        );
      }
    }

    try {
      // Process Messenger-specific events
      await this.facebookWebhookService.processMessengerWebhook(webhookData);
      this.logger.log('Messenger webhook processed successfully');
    } catch (error) {
      this.logger.error('Failed to process Messenger webhook:', error);
      throw new HttpException(
        'Failed to process Messenger webhook',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }

    return { status: 'ok' };
  }

  @Get('messenger')
  @ApiOperation({ 
    summary: 'Verify Messenger webhook',
    description: 'Webhook verification endpoint for Facebook Messenger'
  })
  @ApiQuery({ 
    name: 'hub.mode', 
    description: 'Webhook verification mode' 
  })
  @ApiQuery({ 
    name: 'hub.verify_token', 
    description: 'Webhook verification token' 
  })
  @ApiQuery({ 
    name: 'hub.challenge', 
    description: 'Webhook verification challenge' 
  })
  @ApiResponse({ 
    status: 200, 
    description: 'Messenger webhook verified successfully' 
  })
  @ApiResponse({ 
    status: 403, 
    description: 'Messenger webhook verification failed' 
  })
  async verifyMessengerWebhook(
    @Query('hub.mode') mode: string,
    @Query('hub.verify_token') verifyToken: string,
    @Query('hub.challenge') challenge: string,
  ): Promise<string> {
    this.logger.log('Messenger webhook verification request received');
    this.logger.log(`Mode: ${mode}, Verify Token: ${verifyToken}, Challenge: ${challenge}`);

    // Get expected verify token from environment variables
    const expectedVerifyToken = process.env.MESSENGER_WEBHOOK_VERIFY_TOKEN || 
                                 process.env.FACEBOOK_WEBHOOK_VERIFY_TOKEN || 
                                 'seafrika_messenger_webhook_2024';

    if (mode === 'subscribe' && verifyToken === expectedVerifyToken) {
      this.logger.log('Messenger webhook verified successfully');
      return challenge;
    } else {
      this.logger.warn('Messenger webhook verification failed');
      throw new HttpException(
        'Messenger webhook verification failed',
        HttpStatus.FORBIDDEN,
      );
    }
  }

  private async processInstagramWebhook(webhookData: any): Promise<void> {
    this.logger.log('Processing Instagram webhook events');
    
    for (const entry of webhookData.entry) {
      if (entry.changes) {
        for (const change of entry.changes) {
          this.logger.log(`Instagram webhook change: ${change.field}`);
          
          switch (change.field) {
            case 'comments':
              this.logger.log('Instagram comment event received');
              break;
            case 'mentions':
              this.logger.log('Instagram mention event received');
              break;
            case 'messages':
              this.logger.log('Instagram message event received');
              break;
            default:
              this.logger.log(`Unhandled Instagram webhook field: ${change.field}`);
          }
        }
      }
    }
  }

  private async verifyWebhookSignature(payload: string, signature: string): Promise<boolean> {
    try {
      const crypto = require('crypto');
      const appSecret = process.env.FACEBOOK_APP_SECRET;
      
      if (!appSecret) {
        this.logger.warn('Facebook app secret not configured');
        return false;
      }

      // Create expected signature
      const expectedSignature = 'sha256=' + crypto
        .createHmac('sha256', appSecret)
        .update(payload)
        .digest('hex');

      // Compare signatures
      const isValid = crypto.timingSafeEqual(
        Buffer.from(signature),
        Buffer.from(expectedSignature)
      );

      if (isValid) {
        this.logger.log('Facebook webhook signature verified successfully');
      } else {
        this.logger.warn('Facebook webhook signature verification failed');
      }

      return isValid;
    } catch (error) {
      this.logger.error('Error verifying Facebook webhook signature:', error);
      return false;
    }
  }
}

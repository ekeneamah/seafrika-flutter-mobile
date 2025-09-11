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

    // Process webhook data
    if (webhookData.object === 'page') {
      try {
        await this.facebookWebhookService.processFacebookWebhook(webhookData);
        this.logger.log('Facebook webhook processed successfully');
      } catch (error) {
        this.logger.error('Failed to process Facebook webhook:', error);
        throw new HttpException(
          'Failed to process webhook',
          HttpStatus.INTERNAL_SERVER_ERROR,
        );
      }
    } else {
      this.logger.warn(`Unsupported Facebook webhook object type: ${webhookData.object}`);
    }

    return { status: 'ok' };
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

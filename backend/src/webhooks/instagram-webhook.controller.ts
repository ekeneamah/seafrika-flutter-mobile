import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  HttpStatus,
  HttpException,
  Logger,
  Headers,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { InstagramWebhookService } from './instagram-webhook.service';
import { InstagramWebhookDto } from './dto/instagram-webhook.dto';

@ApiTags('Instagram Webhook')
@Controller('webhooks/instagram')
export class InstagramWebhookController {
  private readonly logger = new Logger(InstagramWebhookController.name);

  constructor(
    private readonly instagramWebhookService: InstagramWebhookService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Verify Instagram webhook subscription' })
  @ApiResponse({ status: 200, description: 'Webhook verified successfully' })
  @ApiResponse({ status: 403, description: 'Verification failed' })
  async verifyWebhook(
    @Query('hub.mode') mode: string,
    @Query('hub.challenge') challenge: string,
    @Query('hub.verify_token') verifyToken: string,
  ) {
    this.logger.log(`Webhook verification attempt: mode=${mode}, token=${verifyToken}`);

    // Verify the webhook subscription
    if (mode === 'subscribe') {
      const isValid = await this.instagramWebhookService.verifyWebhook(verifyToken);
      
      if (isValid) {
        this.logger.log('Webhook verification successful');
        return challenge;
      } else {
        this.logger.error('Webhook verification failed: Invalid verify token');
        throw new HttpException('Forbidden', HttpStatus.FORBIDDEN);
      }
    }

    throw new HttpException('Bad Request', HttpStatus.BAD_REQUEST);
  }

  @Post()
  @ApiOperation({ summary: 'Receive Instagram webhook notifications' })
  @ApiResponse({ status: 200, description: 'Webhook processed successfully' })
  @ApiResponse({ status: 400, description: 'Invalid webhook data' })
  async handleWebhook(
    @Body() webhookData: InstagramWebhookDto,
    @Headers('x-hub-signature-256') signature: string,
    @Req() req: any,
  ) {
    this.logger.log('Received Instagram webhook notification');

    try {
      // Get raw body from request
      const rawBody = req.rawBody || req.body;
      
      // Verify the webhook signature
      const isValidSignature = await this.instagramWebhookService.verifySignature(
        rawBody,
        signature,
      );

      if (!isValidSignature) {
        this.logger.error('Invalid webhook signature');
        throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
      }

      // Process the webhook data
      await this.instagramWebhookService.processWebhook(webhookData);

      this.logger.log('Webhook processed successfully');
      return { status: 'success' };
    } catch (error) {
      this.logger.error('Error processing webhook:', error);
      throw new HttpException(
        'Internal Server Error',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
  }

  @Get('test')
  @ApiOperation({ summary: 'Test webhook endpoint' })
  @ApiResponse({ status: 200, description: 'Webhook test successful' })
  async testWebhook() {
    return {
      status: 'ok',
      message: 'Instagram webhook endpoint is working',
      timestamp: new Date().toISOString(),
    };
  }
}

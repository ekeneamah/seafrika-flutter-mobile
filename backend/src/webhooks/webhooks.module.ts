import { Module } from '@nestjs/common';
import { InstagramWebhookController } from './instagram-webhook.controller';
import { WebhookManagementController } from './webhook-management.controller';
import { FacebookConfigController } from './facebook-config.controller';
import { InstagramWebhookService } from './instagram-webhook.service';
import { FacebookConfigService } from './facebook-config.service';
import { FirestoreModule } from '../firestore/firestore.module';

@Module({
  imports: [FirestoreModule],
  controllers: [
    InstagramWebhookController, 
    WebhookManagementController,
    FacebookConfigController,
  ],
  providers: [
    InstagramWebhookService,
    FacebookConfigService,
  ],
  exports: [
    InstagramWebhookService,
    FacebookConfigService,
  ],
})
export class WebhooksModule {}

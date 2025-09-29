import { Module } from '@nestjs/common';
import { FacebookController } from './facebook/facebook.controller';
import { InstagramController } from './instagram/instagram.controller';
import { MessengerController } from './messenger/messenger.controller';
import { MetaIntegrationService } from './shared/meta-integration.service';
import { MessengerService } from './messenger/messenger.service';
import { FirestoreModule } from '../firestore/firestore.module';
import { WebhooksModule } from '../webhooks/webhooks.module';

@Module({
  imports: [FirestoreModule, WebhooksModule],
  controllers: [FacebookController, InstagramController, MessengerController],
  providers: [MetaIntegrationService, MessengerService],
  exports: [MetaIntegrationService, MessengerService],
})
export class IntegrationsModule {}

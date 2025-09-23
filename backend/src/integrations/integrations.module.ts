import { Module } from '@nestjs/common';
import { FacebookController } from './facebook/facebook.controller';
import { InstagramController } from './instagram/instagram.controller';
import { MetaIntegrationService } from './shared/meta-integration.service';
import { FirestoreModule } from '../firestore/firestore.module';
import { WebhooksModule } from '../webhooks/webhooks.module';

@Module({
  imports: [FirestoreModule, WebhooksModule],
  controllers: [FacebookController, InstagramController],
  providers: [MetaIntegrationService],
  exports: [MetaIntegrationService],
})
export class IntegrationsModule {}

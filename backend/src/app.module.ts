import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { AuthModule } from './auth/auth.module';
import { ProductsModule } from './products/products.module';
import { FirebaseModule } from './firebase/firebase.module';
import { FirestoreModule } from './firestore/firestore.module';
import { WebhooksModule } from './webhooks/webhooks.module';
import { PrivacyModule } from './privacy/privacy.module';
import { IntegrationsModule } from './integrations/integrations.module';
import { QueueModule } from './messages/queue/queue.module';
import { ReactionsModule } from './messages/reactions/reactions.module';
import { SearchModule } from './search/search.module';
import { BulkMessageModule } from './messages/bulk/bulk-message.module';
import { AttachmentsModule } from './attachments/attachments.module';
import { MessagesModule } from './messages/messages.module';
import { ThreadsModule } from './messages/threads/threads.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import configuration from './config/configuration';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: '.env',
      load: [configuration],
    }),
    ScheduleModule.forRoot(),
    FirebaseModule,
    FirestoreModule,
    AuthModule,
    ProductsModule,
    WebhooksModule,
    PrivacyModule,
    IntegrationsModule,
    QueueModule,
    ReactionsModule,
    SearchModule,
    BulkMessageModule,
    AttachmentsModule,
    MessagesModule,
    ThreadsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}

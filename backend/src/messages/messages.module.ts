import { Module } from '@nestjs/common';
import { MessagesController } from './messages.controller';
import { TextModerationService } from './text-moderation.service';
import { GoogleApiTestService } from './google-api-test.service';
import { FirestoreModule } from '../firestore/firestore.module';
import { DraftsModule } from './drafts/drafts.module';

@Module({
  imports: [FirestoreModule, DraftsModule],
  controllers: [MessagesController],
  providers: [TextModerationService, GoogleApiTestService],
  exports: [TextModerationService],
})
export class MessagesModule {}

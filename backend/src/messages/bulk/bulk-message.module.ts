import { Module } from '@nestjs/common';
import { BulkMessageController } from './bulk-message.controller';
import { BulkMessageService } from './bulk-message.service';
import { FirestoreModule } from '../../firestore/firestore.module';

@Module({
  imports: [FirestoreModule],
  controllers: [BulkMessageController],
  providers: [BulkMessageService],
  exports: [BulkMessageService],
})
export class BulkMessageModule {}

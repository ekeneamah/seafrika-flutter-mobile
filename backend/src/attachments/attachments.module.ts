import { Module } from '@nestjs/common';
import { ContentModerationService } from './content-moderation.service';
import { ImageProcessorService } from './image-processor.service';
import { FirebaseStorageService } from './firebase-storage.service';
import { DocumentProcessorService } from './processors/document.processor';
import { VideoProcessorService } from './processors/video.processor';
import { AttachmentsController } from './attachments.controller';

@Module({
  providers: [
    ContentModerationService,
    ImageProcessorService,
    FirebaseStorageService,
    DocumentProcessorService,
    VideoProcessorService,
  ],
  controllers: [AttachmentsController],
  exports: [
    ContentModerationService,
    ImageProcessorService,
    FirebaseStorageService,
    DocumentProcessorService,
    VideoProcessorService,
  ],
})
export class AttachmentsModule {}

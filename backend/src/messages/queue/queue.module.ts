import { Module } from '@nestjs/common';
import { QueueController } from './queue.controller';
import { QueueService } from './queue.service';
import { QueueSchedulerService } from '../scheduler/queue-scheduler.service';

@Module({
  controllers: [QueueController],
  providers: [QueueService, QueueSchedulerService],
  exports: [QueueService],
})
export class QueueModule {}

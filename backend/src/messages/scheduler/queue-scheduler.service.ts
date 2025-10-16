import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { QueueService } from '../queue/queue.service';

@Injectable()
export class QueueSchedulerService {
  constructor(private readonly queueService: QueueService) {}

  /**
   * Process queue every 5 minutes
   */
  @Cron(CronExpression.EVERY_5_MINUTES)
  async handleQueueProcessing() {
    console.log('⏰ [Queue Scheduler] Starting queue processing...');

    try {
      const result = await this.queueService.processQueue();
      console.log(
        `✅ [Queue Scheduler] Processed ${result.processed} messages (✅ ${result.succeeded} sent, ❌ ${result.failed} failed)`,
      );
    } catch (error) {
      console.error('❌ [Queue Scheduler] Error processing queue:', error);
    }
  }

  /**
   * Clean up old queue items every day at 3 AM
   */
  @Cron('0 3 * * *')
  async handleQueueCleanup() {
    console.log('🧹 [Queue Scheduler] Starting queue cleanup...');

    try {
      const deleted = await this.queueService.cleanupOldQueue();
      console.log(`✅ [Queue Scheduler] Cleaned up ${deleted} old queue items`);
    } catch (error) {
      console.error('❌ [Queue Scheduler] Error cleaning up queue:', error);
    }
  }
}

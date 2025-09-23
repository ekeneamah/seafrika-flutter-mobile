import { Injectable, Logger } from '@nestjs/common';
import { FirestoreService } from '../../firestore/firestore.service';
import { MetaService } from '../meta/meta.service';
import fetch from 'node-fetch';

@Injectable()
export class InstagramMetricsService {
  private readonly logger = new Logger(InstagramMetricsService.name);

  constructor(
    private readonly firestoreService: FirestoreService,
    private readonly metaService: MetaService,
  ) {}

  /**
   * Sync all Instagram metrics (can be called manually or via cron)
   */
  async syncAllInstagramMetrics() {
    this.logger.log('Starting Instagram metrics sync...');
    
    try {
      // Get all active Instagram integrations
      const integrations = await this.firestoreService.getDocuments('integrations', [
        { field: 'channel', operator: '==', value: 'instagram' },
        { field: 'status', operator: '==', value: 'active' }
      ]);

      this.logger.log(`Found ${integrations.length} active Instagram integrations to sync`);

      const updatePromises = integrations.map(integration => 
        this.updateInstagramMetrics(integration.id, integration)
      );

      const results = await Promise.allSettled(updatePromises);
      
      const successful = results.filter(r => r.status === 'fulfilled').length;
      const failed = results.filter(r => r.status === 'rejected').length;

      this.logger.log(`Instagram metrics sync completed: ${successful} successful, ${failed} failed`);
    } catch (error) {
      this.logger.error('Failed to sync Instagram metrics:', error);
    }
  }

  /**
   * Update metrics for a specific Instagram integration
   */
  async updateInstagramMetrics(integrationId: string, integration: any) {
    try {
      const accessToken = integration.credentials?.access_token;
      const instagramId = integration.accountInfo?.instagramId;

      if (!accessToken || !instagramId || accessToken === 'backend_managed') {
        this.logger.debug(`Skipping integration ${integrationId}: no valid access token`);
        return;
      }

      // Fetch fresh metrics from Instagram Graph API
      const response = await fetch(
        `https://graph.facebook.com/v18.0/${instagramId}?fields=followers_count,follows_count,media_count,name,username,biography,profile_picture_url,website&access_token=${accessToken}`
      );

      if (!response.ok) {
        this.logger.warn(`Instagram API failed for integration ${integrationId}: ${response.status} - ${await response.text()}`);
        return;
      }

      const metrics = await response.json();
      
      // Update the integration's accountInfo with fresh metrics
      const updatedAccountInfo = {
        ...integration.accountInfo,
        followers_count: metrics.followers_count || integration.accountInfo.followers_count,
        follows_count: metrics.follows_count || integration.accountInfo.follows_count,
        media_count: metrics.media_count || integration.accountInfo.media_count,
        name: metrics.name || integration.accountInfo.name,
        biography: metrics.biography,
        profile_picture_url: metrics.profile_picture_url,
        website: metrics.website,
        lastMetricsSync: new Date().toISOString(),
      };

      // Update the integration document
      await this.firestoreService.updateDocument('integrations', integrationId, {
        accountInfo: updatedAccountInfo,
        lastSyncAt: new Date(),
        updatedAt: new Date(),
      });

      this.logger.log(`Updated metrics for integration ${integrationId}: followers=${metrics.followers_count}, following=${metrics.follows_count}, posts=${metrics.media_count}`);

      // Store metrics history for trend analysis
      await this.storeMetricsHistory(integrationId, integration.businessId, metrics);

    } catch (error) {
      this.logger.error(`Failed to update metrics for integration ${integrationId}:`, error);
      throw error;
    }
  }

  /**
   * Store metrics history for trend analysis
   */
  private async storeMetricsHistory(integrationId: string, businessId: string, metrics: any) {
    try {
      await this.firestoreService.createDocument('instagram_metrics_history', {
        integrationId,
        businessId,
        followers_count: metrics.followers_count,
        follows_count: metrics.follows_count,
        media_count: metrics.media_count,
        timestamp: new Date(),
        createdAt: new Date(),
      });
    } catch (error) {
      this.logger.warn(`Failed to store metrics history for integration ${integrationId}:`, error);
      // Don't throw - this is optional
    }
  }

  /**
   * Manual sync for specific integration (called from frontend)
   */
  async syncInstagramMetricsById(integrationId: string): Promise<any> {
    try {
      const integrationDoc = await this.firestoreService.getDocument('integrations', integrationId);
      
      if (!integrationDoc || (integrationDoc as any).channel !== 'instagram') {
        throw new Error('Integration not found or not an Instagram integration');
      }

      await this.updateInstagramMetrics(integrationId, integrationDoc);
      
      // Return updated integration data
      const updatedIntegration = await this.firestoreService.getDocument('integrations', integrationId);
      return (updatedIntegration as any).accountInfo;
      
    } catch (error) {
      this.logger.error(`Manual sync failed for integration ${integrationId}:`, error);
      throw error;
    }
  }

  /**
   * Get metrics history for trend analysis
   */
  async getMetricsHistory(integrationId: string, days: number = 30): Promise<any[]> {
    try {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const history = await this.firestoreService.getDocuments('instagram_metrics_history', [
        { field: 'integrationId', operator: '==', value: integrationId },
        { field: 'timestamp', operator: '>=', value: startDate }
      ]);

      return history.sort((a, b) => a.timestamp.toDate().getTime() - b.timestamp.toDate().getTime());
    } catch (error) {
      this.logger.error(`Failed to get metrics history for integration ${integrationId}:`, error);
      throw error;
    }
  }
}
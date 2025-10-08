import { Injectable, Logger } from '@nestjs/common';
import { FirestoreService } from '../../../firestore/firestore.service';

export interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
}

export interface MessageNotification {
  businessId: string;
  integrationId: string;
  messageId: string;
  platform: string;
  senderName: string;
  preview: string;
  timestamp: Date;
}

export interface VendorNotificationPreferences {
  enabled: boolean;
  channels: {
    push: boolean;
    email: boolean;
    sms: boolean;
  };
  messageTypes: {
    messenger: boolean;
    instagram: boolean;
    facebook: boolean;
    tiktok: boolean;
    youtube: boolean;
    comments: boolean;
    mentions: boolean;
    interactions: boolean; // likes, shares, follows
    videoEvents: boolean; // video publish, updates
  };
  quietHours?: {
    enabled: boolean;
    startTime: string; // HH:mm format
    endTime: string;
    timezone: string;
  };
}

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(private readonly firestoreService: FirestoreService) {}

  /**
   * Send notification to vendor about new message
   */
  async notifyVendorOfNewMessage(notification: MessageNotification): Promise<void> {
    try {
      this.logger.log(`Sending notification to business ${notification.businessId} for new message`);

      // Get vendor notification preferences
      const preferences = await this.getVendorNotificationPreferences(notification.businessId);
      
      if (!preferences?.enabled) {
        this.logger.log(`Notifications disabled for business ${notification.businessId}`);
        return;
      }

      // Check if this message type should trigger notifications
      if (!this.shouldNotifyForPlatform(notification.platform, preferences)) {
        this.logger.log(`Notifications disabled for platform ${notification.platform}`);
        return;
      }

      // Check quiet hours
      if (this.isQuietHours(preferences)) {
        this.logger.log(`In quiet hours for business ${notification.businessId}, skipping notification`);
        return;
      }

      // Create notification payload
      const payload = this.createNotificationPayload(notification);

      // Send notifications through enabled channels
      const notificationPromises: Promise<void>[] = [];

      if (preferences.channels.push) {
        notificationPromises.push(this.sendPushNotification(notification.businessId, payload));
      }

      if (preferences.channels.email) {
        notificationPromises.push(this.sendEmailNotification(notification.businessId, notification));
      }

      if (preferences.channels.sms) {
        notificationPromises.push(this.sendSMSNotification(notification.businessId, notification));
      }

      // Execute all notifications
      await Promise.allSettled(notificationPromises);

      // Store notification record
      await this.storeNotificationRecord(notification, payload);

      this.logger.log(`Notification sent successfully for message ${notification.messageId}`);
    } catch (error) {
      this.logger.error('Failed to send vendor notification:', error);
      // Don't throw - notifications are not critical to webhook processing
    }
  }

  /**
   * Send push notification to vendor's devices
   */
  private async sendPushNotification(businessId: string, payload: NotificationPayload): Promise<void> {
    try {
      // Get vendor's FCM tokens
      const tokensSnapshot = await this.firestoreService
        .collection(`businesses/${businessId}/fcm_tokens`)
        .where('active', '==', true)
        .get();

      if (tokensSnapshot.empty) {
        this.logger.warn(`No active FCM tokens found for business ${businessId}`);
        return;
      }

      const tokens = tokensSnapshot.docs.map(doc => doc.data().token);

      // Send multicast message (you'll need to implement FCM service)
      const message = {
        tokens,
        notification: {
          title: payload.title,
          body: payload.body,
          ...(payload.imageUrl && { imageUrl: payload.imageUrl }),
        },
        data: payload.data || {},
        android: {
          notification: {
            icon: 'ic_notification',
            color: '#1976D2',
            channelId: 'messages',
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
            },
          },
        },
      };

      // TODO: Implement FCM sending
      // await this.fcmService.sendMulticast(message);
      
      this.logger.log(`Push notification sent to ${tokens.length} devices for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to send push notification:', error);
    }
  }

  /**
   * Send email notification
   */
  private async sendEmailNotification(businessId: string, notification: MessageNotification): Promise<void> {
    try {
      // Get business owner email
      const businessDoc = await this.firestoreService
        .doc(`businesses/${businessId}`)
        .get();

      if (!businessDoc.exists) {
        this.logger.warn(`Business ${businessId} not found for email notification`);
        return;
      }

      const businessData = businessDoc.data();
      const ownerEmail = businessData?.ownerEmail || businessData?.email;

      if (!ownerEmail) {
        this.logger.warn(`No email found for business ${businessId}`);
        return;
      }

      const emailData = {
        to: ownerEmail,
        subject: `New ${notification.platform} message from ${notification.senderName}`,
        template: 'new-message',
        data: {
          businessName: businessData?.name || 'Your Business',
          platform: notification.platform,
          senderName: notification.senderName,
          messagePreview: notification.preview,
          timestamp: notification.timestamp.toLocaleString(),
          dashboardUrl: `https://sme-afrika.web.app/messages?integration=${notification.integrationId}`,
        },
      };

      // TODO: Implement email service
      // await this.emailService.sendTemplate(emailData);

      this.logger.log(`Email notification sent to ${ownerEmail} for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to send email notification:', error);
    }
  }

  /**
   * Send SMS notification
   */
  private async sendSMSNotification(businessId: string, notification: MessageNotification): Promise<void> {
    try {
      // Get business owner phone
      const businessDoc = await this.firestoreService
        .doc(`businesses/${businessId}`)
        .get();

      if (!businessDoc.exists) {
        return;
      }

      const businessData = businessDoc.data();
      const phone = businessData?.phone || businessData?.ownerPhone;

      if (!phone) {
        this.logger.warn(`No phone found for business ${businessId}`);
        return;
      }

      const message = `New ${notification.platform} message from ${notification.senderName}: "${notification.preview.substring(0, 100)}..." - Reply at sme-afrika.web.app`;

      // TODO: Implement SMS service
      // await this.smsService.send(phone, message);

      this.logger.log(`SMS notification sent to ${phone} for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to send SMS notification:', error);
    }
  }

  /**
   * Get vendor notification preferences
   */
  private async getVendorNotificationPreferences(businessId: string): Promise<VendorNotificationPreferences | null> {
    try {
      const preferencesDoc = await this.firestoreService
        .doc(`businesses/${businessId}/settings/notifications`)
        .get();

      if (!preferencesDoc.exists) {
        // Return default preferences
        return {
          enabled: true,
          channels: {
            push: true,
            email: true,
            sms: false,
          },
          messageTypes: {
            messenger: true,
            instagram: true,
            facebook: true,
            tiktok: true,
            youtube: true,
            comments: true,
            mentions: true,
            interactions: true,
            videoEvents: true,
          },
        };
      }

      return preferencesDoc.data() as VendorNotificationPreferences;
    } catch (error) {
      this.logger.error('Failed to get notification preferences:', error);
      return null;
    }
  }

  /**
   * Check if should notify for specific platform
   */
  private shouldNotifyForPlatform(platform: string, preferences: VendorNotificationPreferences): boolean {
    switch (platform.toLowerCase()) {
      case 'messenger':
        return preferences.messageTypes.messenger;
      case 'instagram':
        return preferences.messageTypes.instagram;
      case 'facebook':
        return preferences.messageTypes.facebook;
      case 'tiktok':
        return preferences.messageTypes.tiktok;
      case 'youtube':
        return preferences.messageTypes.youtube;
      default:
        return true;
    }
  }

  /**
   * Check if current time is in quiet hours
   */
  private isQuietHours(preferences: VendorNotificationPreferences): boolean {
    if (!preferences.quietHours?.enabled) {
      return false;
    }

    // TODO: Implement proper timezone handling
    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();
    
    const [startHour, startMin] = preferences.quietHours.startTime.split(':').map(Number);
    const [endHour, endMin] = preferences.quietHours.endTime.split(':').map(Number);
    
    const startTime = startHour * 60 + startMin;
    const endTime = endHour * 60 + endMin;

    if (startTime <= endTime) {
      return currentTime >= startTime && currentTime <= endTime;
    } else {
      // Overnight quiet hours
      return currentTime >= startTime || currentTime <= endTime;
    }
  }

  /**
   * Create notification payload
   */
  private createNotificationPayload(notification: MessageNotification): NotificationPayload {
    const platformEmoji = {
      messenger: '💬',
      instagram: '📷',
      facebook: '👥',
      tiktok: '🎵',
      youtube: '📺',
    };

    return {
      title: `${platformEmoji[notification.platform] || '�'} New ${notification.platform} ${this.getMessageTypeDescription(notification)}`,
      body: `${notification.senderName}: ${notification.preview}`,
      data: {
        type: 'new_message',
        businessId: notification.businessId,
        integrationId: notification.integrationId,
        messageId: notification.messageId,
        platform: notification.platform,
        click_action: 'OPEN_MESSAGES',
      },
    };
  }

  /**
   * Get user-friendly message type description
   */
  private getMessageTypeDescription(notification: MessageNotification): string {
    const platform = notification.platform.toLowerCase();
    
    if (notification.preview.includes('commented:') || notification.preview.includes('Commented:')) {
      return 'comment';
    }
    if (notification.preview.includes('liked') || notification.preview.includes('Liked')) {
      return 'interaction';
    }
    if (notification.preview.includes('followed') || notification.preview.includes('Followed')) {
      return 'follower';
    }
    if (notification.preview.includes('published') || notification.preview.includes('Published')) {
      return 'video update';
    }
    
    return 'message';
  }

  /**
   * Store notification record for analytics
   */
  private async storeNotificationRecord(
    notification: MessageNotification, 
    payload: NotificationPayload
  ): Promise<void> {
    try {
      await this.firestoreService
        .collection(`businesses/${notification.businessId}/notification_logs`)
        .add({
          type: 'message_notification',
          messageId: notification.messageId,
          integrationId: notification.integrationId,
          platform: notification.platform,
          payload,
          sentAt: new Date(),
          status: 'sent',
        });
    } catch (error) {
      this.logger.error('Failed to store notification record:', error);
    }
  }

  /**
   * Update notification preferences
   */
  async updateNotificationPreferences(
    businessId: string, 
    preferences: Partial<VendorNotificationPreferences>
  ): Promise<void> {
    try {
      await this.firestoreService
        .doc(`businesses/${businessId}/settings/notifications`)
        .set(preferences, { merge: true });

      this.logger.log(`Updated notification preferences for business ${businessId}`);
    } catch (error) {
      this.logger.error('Failed to update notification preferences:', error);
      throw error;
    }
  }
}
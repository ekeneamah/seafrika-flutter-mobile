import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { FirebaseAdminService } from './firebase-admin.service';
import * as admin from 'firebase-admin';

export interface NotificationData {
  title: string;
  body: string;
  imageUrl?: string;
  icon?: string;
  badge?: string;
  sound?: string;
  tag?: string;
  color?: string;
  clickAction?: string;
}

export interface PushNotificationOptions {
  data?: { [key: string]: string };
  android?: admin.messaging.AndroidConfig;
  apns?: admin.messaging.ApnsConfig;
  webpush?: admin.messaging.WebpushConfig;
  fcmOptions?: admin.messaging.FcmOptions;
  condition?: string;
  topic?: string;
  priority?: 'normal' | 'high';
  timeToLive?: number;
}

@Injectable()
export class FirebaseMessagingService {
  private readonly logger = new Logger(FirebaseMessagingService.name);

  constructor(private firebaseAdmin: FirebaseAdminService) {}

  /**
   * Send notification to single device
   */
  async sendToDevice(
    token: string,
    notification: NotificationData,
    options: PushNotificationOptions = {}
  ): Promise<string> {
    try {
      const message: admin.messaging.Message = {
        token,
        notification: {
          title: notification.title,
          body: notification.body,
          imageUrl: notification.imageUrl,
        },
        data: options.data,
        android: options.android || {
          priority: options.priority || 'high',
          ttl: options.timeToLive || 3600000, // 1 hour default
          notification: {
            icon: notification.icon,
            color: notification.color,
            sound: notification.sound || 'default',
            tag: notification.tag,
            clickAction: notification.clickAction,
          },
        },
        apns: options.apns || {
          payload: {
            aps: {
              badge: notification.badge ? parseInt(notification.badge) : undefined,
              sound: notification.sound || 'default',
            },
          },
        },
        webpush: options.webpush,
        fcmOptions: options.fcmOptions,
      };

      const messaging = await this.firebaseAdmin.getMessaging();
      const response = await messaging.send(message);
      this.logger.log(`Notification sent successfully to device: ${token}`);
      return response;
    } catch (error) {
      this.logger.error('Error sending notification to device:', error.message);
      throw new BadRequestException('Failed to send notification');
    }
  }

  /**
   * Send notification to multiple devices
   */
  async sendToMultipleDevices(
    tokens: string[],
    notification: NotificationData,
    options: PushNotificationOptions = {}
  ): Promise<admin.messaging.BatchResponse> {
    try {
      const message: admin.messaging.MulticastMessage = {
        tokens,
        notification: {
          title: notification.title,
          body: notification.body,
          imageUrl: notification.imageUrl,
        },
        data: options.data,
        android: options.android || {
          priority: options.priority || 'high',
          ttl: options.timeToLive || 3600000,
          notification: {
            icon: notification.icon,
            color: notification.color,
            sound: notification.sound || 'default',
            tag: notification.tag,
            clickAction: notification.clickAction,
          },
        },
        apns: options.apns || {
          payload: {
            aps: {
              badge: notification.badge ? parseInt(notification.badge) : undefined,
              sound: notification.sound || 'default',
            },
          },
        },
        webpush: options.webpush,
        fcmOptions: options.fcmOptions,
      };

      const messaging = await this.firebaseAdmin.getMessaging();
      const response = await messaging.sendEachForMulticast(message);
      this.logger.log(`Notifications sent to ${tokens.length} devices. Success: ${response.successCount}, Failure: ${response.failureCount}`);
      return response;
    } catch (error) {
      this.logger.error('Error sending notifications to devices:', error.message);
      throw new BadRequestException('Failed to send notifications');
    }
  }

  /**
   * Send notification to topic
   */
  async sendToTopic(
    topic: string,
    notification: NotificationData,
    options: PushNotificationOptions = {}
  ): Promise<string> {
    try {
      const message: admin.messaging.Message = {
        topic,
        notification: {
          title: notification.title,
          body: notification.body,
          imageUrl: notification.imageUrl,
        },
        data: options.data,
        android: options.android || {
          priority: options.priority || 'high',
          ttl: options.timeToLive || 3600000,
          notification: {
            icon: notification.icon,
            color: notification.color,
            sound: notification.sound || 'default',
            tag: notification.tag,
            clickAction: notification.clickAction,
          },
        },
        apns: options.apns || {
          payload: {
            aps: {
              badge: notification.badge ? parseInt(notification.badge) : undefined,
              sound: notification.sound || 'default',
            },
          },
        },
        webpush: options.webpush,
        fcmOptions: options.fcmOptions,
      };

      const messaging = await this.firebaseAdmin.getMessaging();
      const response = await messaging.send(message);
      this.logger.log(`Notification sent successfully to topic: ${topic}`);
      return response;
    } catch (error) {
      this.logger.error('Error sending notification to topic:', error.message);
      throw new BadRequestException('Failed to send notification to topic');
    }
  }

  /**
   * Send notification with condition
   */
  async sendWithCondition(
    condition: string,
    notification: NotificationData,
    options: PushNotificationOptions = {}
  ): Promise<string> {
    try {
      const message: admin.messaging.Message = {
        condition,
        notification: {
          title: notification.title,
          body: notification.body,
          imageUrl: notification.imageUrl,
        },
        data: options.data,
        android: options.android,
        apns: options.apns,
        webpush: options.webpush,
        fcmOptions: options.fcmOptions,
      };

      const messaging = await this.firebaseAdmin.getMessaging();
      const response = await messaging.send(message);
      this.logger.log(`Notification sent successfully with condition: ${condition}`);
      return response;
    } catch (error) {
      this.logger.error('Error sending notification with condition:', error.message);
      throw new BadRequestException('Failed to send notification with condition');
    }
  }

  /**
   * Subscribe tokens to topic
   */
  async subscribeToTopic(tokens: string[], topic: string): Promise<any> {
    try {
      const messaging = await this.firebaseAdmin.getMessaging();
      const response = await messaging.subscribeToTopic(tokens, topic);
      this.logger.log(`Tokens subscribed to topic ${topic}. Success: ${response.successCount}, Failure: ${response.failureCount}`);
      return response;
    } catch (error) {
      this.logger.error('Error subscribing to topic:', error.message);
      throw new BadRequestException('Failed to subscribe to topic');
    }
  }

  /**
   * Unsubscribe tokens from topic
   */
  async unsubscribeFromTopic(tokens: string[], topic: string): Promise<any> {
    try {
      const messaging = await this.firebaseAdmin.getMessaging();
      const response = await messaging.unsubscribeFromTopic(tokens, topic);
      this.logger.log(`Tokens unsubscribed from topic ${topic}. Success: ${response.successCount}, Failure: ${response.failureCount}`);
      return response;
    } catch (error) {
      this.logger.error('Error unsubscribing from topic:', error.message);
      throw new BadRequestException('Failed to unsubscribe from topic');
    }
  }

  /**
   * Send data-only message
   */
  async sendDataMessage(
    token: string,
    data: { [key: string]: string },
    options: PushNotificationOptions = {}
  ): Promise<string> {
    try {
      const message: admin.messaging.Message = {
        token,
        data,
        android: options.android || {
          priority: options.priority || 'high',
          ttl: options.timeToLive || 3600000,
        },
        apns: options.apns,
        webpush: options.webpush,
        fcmOptions: options.fcmOptions,
      };

      const messaging = await this.firebaseAdmin.getMessaging();
      const response = await messaging.send(message);
      this.logger.log(`Data message sent successfully to device: ${token}`);
      return response;
    } catch (error) {
      this.logger.error('Error sending data message:', error.message);
      throw new BadRequestException('Failed to send data message');
    }
  }

  /**
   * Send silent notification (background processing)
   */
  async sendSilentNotification(
    token: string,
    data: { [key: string]: string },
    options: PushNotificationOptions = {}
  ): Promise<string> {
    try {
      const message: admin.messaging.Message = {
        token,
        data,
        android: options.android || {
          priority: 'high',
          data,
        },
        apns: options.apns || {
          payload: {
            aps: {
              contentAvailable: true,
            },
          },
          headers: {
            'apns-push-type': 'background',
            'apns-priority': '5',
          },
        },
        webpush: options.webpush,
        fcmOptions: options.fcmOptions,
      };

      const messaging = await this.firebaseAdmin.getMessaging();
      const response = await messaging.send(message);
      this.logger.log(`Silent notification sent successfully to device: ${token}`);
      return response;
    } catch (error) {
      this.logger.error('Error sending silent notification:', error.message);
      throw new BadRequestException('Failed to send silent notification');
    }
  }

  /**
   * Validate FCM token
   */
  async validateToken(token: string): Promise<boolean> {
    try {
      const messaging = await this.firebaseAdmin.getMessaging();
      await messaging.send({
        token,
        data: { test: 'true' },
      }, true); // dry run
      return true;
    } catch (error) {
      this.logger.warn(`Invalid FCM token: ${token}`);
      return false;
    }
  }
}

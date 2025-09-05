import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import { ServiceAccount } from 'firebase-admin';

@Injectable()
export class FirebaseAdminService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseAdminService.name);
  private firebaseApp: admin.app.App;
  private initializationPromise: Promise<void>;

  constructor(private configService: ConfigService) {}

  async onModuleInit() {
    // Store the initialization promise to ensure we don't initialize multiple times
    if (!this.initializationPromise) {
      this.initializationPromise = this.initializeFirebase();
    }
    await this.initializationPromise;
  }

  private async initializeFirebase() {
    try {
      this.logger.log('Starting Firebase Admin SDK initialization...');
      
      // Check if already initialized
      if (admin.apps.length > 0) {
        this.firebaseApp = admin.app();
        this.logger.log('Using existing Firebase Admin app');
        return;
      }

      const projectId = this.configService.get<string>('FIREBASE_PROJECT_ID') || 'sme-afrika';
      const privateKey = this.configService.get<string>('FIREBASE_PRIVATE_KEY');
      const clientEmail = this.configService.get<string>('FIREBASE_CLIENT_EMAIL');
      const serviceAccountPath = this.configService.get<string>('GOOGLE_APPLICATION_CREDENTIALS');

      this.logger.log(`Project ID: ${projectId}`);
      this.logger.log(`Client Email: ${clientEmail ? 'Provided' : 'Not provided'}`);
      this.logger.log(`Private Key: ${privateKey ? 'Provided' : 'Not provided'}`);
      this.logger.log(`Service Account Path: ${serviceAccountPath || 'Not provided'}`);

      let serviceAccount: ServiceAccount | undefined;

      // Try different initialization methods
      if (serviceAccountPath) {
        try {
          serviceAccount = require(serviceAccountPath);
          this.logger.log('Successfully loaded Firebase service account from file');
        } catch (error) {
          this.logger.warn(`Service account file not found at ${serviceAccountPath}, trying environment variables`);
        }
      }

      if (!serviceAccount && privateKey && clientEmail) {
        try {
          serviceAccount = this.getServiceAccountFromEnv();
          this.logger.log('Using Firebase service account from environment variables');
        } catch (error) {
          this.logger.warn('Failed to create service account from env vars:', error.message);
        }
      }

      // Initialize with service account or default credentials
      if (serviceAccount) {
        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: projectId,
          storageBucket: `${projectId}.firebasestorage.app`,
        });
        this.logger.log('Firebase Admin SDK initialized with service account');
      } else {
        // Fallback for Cloud Functions (uses default service account)
        this.firebaseApp = admin.initializeApp({
          projectId: projectId,
          storageBucket: `${projectId}.firebasestorage.app`,
        });
        this.logger.log('Firebase Admin SDK initialized with default credentials (Cloud Functions)');
      }

      this.logger.log('Firebase Admin SDK initialized successfully');
    } catch (error) {
      this.logger.error('Failed to initialize Firebase Admin SDK:', error.message);
      this.logger.error('Error details:', error);
      throw error;
    }
  }

  private getServiceAccountFromEnv(): ServiceAccount {
    const projectId = this.configService.get<string>('FIREBASE_PROJECT_ID');
    const privateKey = this.configService.get<string>('FIREBASE_PRIVATE_KEY');
    const clientEmail = this.configService.get<string>('FIREBASE_CLIENT_EMAIL');

    if (!projectId || !privateKey || !clientEmail) {
      throw new Error(
        'Firebase credentials missing. Provide either GOOGLE_APPLICATION_CREDENTIALS file path or FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, and FIREBASE_CLIENT_EMAIL environment variables.'
      );
    }

    return {
      projectId,
      privateKey: privateKey.replace(/\\n/g, '\n'), // Handle escaped newlines
      clientEmail,
    };
  }

  /**
   * Get Firebase Admin App instance
   */
  async getApp(): Promise<admin.app.App> {
    // Ensure initialization is complete
    if (!this.firebaseApp) {
      if (!this.initializationPromise) {
        this.initializationPromise = this.initializeFirebase();
      }
      await this.initializationPromise;
    }
    
    if (!this.firebaseApp) {
      throw new Error('Firebase Admin SDK failed to initialize');
    }
    return this.firebaseApp;
  }

  /**
   * Get Firestore instance
   */
  async getFirestore(): Promise<admin.firestore.Firestore> {
    const app = await this.getApp();
    return app.firestore();
  }

  /**
   * Get Firebase Auth instance
   */
  async getAuth(): Promise<admin.auth.Auth> {
    const app = await this.getApp();
    return app.auth();
  }

  /**
   * Get Firebase Storage instance
   */
  async getStorage(): Promise<admin.storage.Storage> {
    const app = await this.getApp();
    return app.storage();
  }

  /**
   * Get Firebase Messaging instance
   */
  async getMessaging(): Promise<admin.messaging.Messaging> {
    const app = await this.getApp();
    return app.messaging();
  }

  /**
   * Verify Firebase ID token
   */
  async verifyIdToken(idToken: string): Promise<admin.auth.DecodedIdToken> {
    try {
      const auth = await this.getAuth();
      return await auth.verifyIdToken(idToken);
    } catch (error) {
      this.logger.error('Error verifying ID token:', error.message);
      throw error;
    }
  }

  /**
   * Create custom token for user
   */
  async createCustomToken(uid: string, additionalClaims?: object): Promise<string> {
    try {
      const auth = await this.getAuth();
      return await auth.createCustomToken(uid, additionalClaims);
    } catch (error) {
      this.logger.error('Error creating custom token:', error.message);
      throw error;
    }
  }

  /**
   * Get user by UID
   */
  async getUserByUid(uid: string): Promise<admin.auth.UserRecord> {
    try {
      const auth = await this.getAuth();
      return await auth.getUser(uid);
    } catch (error) {
      this.logger.error('Error getting user by UID:', error.message);
      throw error;
    }
  }

  /**
   * Create new user
   */
  async createUser(userProperties: admin.auth.CreateRequest): Promise<admin.auth.UserRecord> {
    try {
      const auth = await this.getAuth();
      return await auth.createUser(userProperties);
    } catch (error) {
      this.logger.error('Error creating user:', error.message);
      throw error;
    }
  }

  /**
   * Update user
   */
  async updateUser(uid: string, properties: admin.auth.UpdateRequest): Promise<admin.auth.UserRecord> {
    try {
      const auth = await this.getAuth();
      return await auth.updateUser(uid, properties);
    } catch (error) {
      this.logger.error('Error updating user:', error.message);
      throw error;
    }
  }

  /**
   * Delete user
   */
  async deleteUser(uid: string): Promise<void> {
    try {
      const auth = await this.getAuth();
      await auth.deleteUser(uid);
      this.logger.log(`User ${uid} deleted successfully`);
    } catch (error) {
      this.logger.error('Error deleting user:', error.message);
      throw error;
    }
  }

  /**
   * Send push notification
   */
  async sendNotification(
    tokens: string | string[],
    notification: admin.messaging.Notification,
    data?: { [key: string]: string }
  ): Promise<admin.messaging.BatchResponse | string> {
    try {
      const messaging = await this.getMessaging();
      const message: admin.messaging.MulticastMessage | admin.messaging.Message = {
        notification,
        data,
        ...(Array.isArray(tokens) ? { tokens } : { token: tokens })
      };

      if (Array.isArray(tokens)) {
        return await messaging.sendEachForMulticast(message as admin.messaging.MulticastMessage);
      } else {
        return await messaging.send(message as admin.messaging.Message);
      }
    } catch (error) {
      this.logger.error('Error sending notification:', error.message);
      throw error;
    }
  }

  /**
   * Upload file to Firebase Storage
   */
  async uploadFile(
    filePath: string,
    destination: string,
    metadata?: { [key: string]: string }
  ): Promise<string> {
    try {
      const storage = await this.getStorage();
      const bucket = storage.bucket();
      const [file] = await bucket.upload(filePath, {
        destination,
        metadata: {
          metadata
        }
      });

      // Make file publicly accessible (optional)
      await file.makePublic();

      return `https://storage.googleapis.com/${bucket.name}/${destination}`;
    } catch (error) {
      this.logger.error('Error uploading file:', error.message);
      throw error;
    }
  }
}

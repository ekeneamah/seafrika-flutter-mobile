import { Injectable, Logger, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { FirebaseAdminService } from './firebase-admin.service';
import * as admin from 'firebase-admin';

export interface CreateUserData {
  email: string;
  password?: string;
  displayName?: string;
  phoneNumber?: string;
  photoURL?: string;
  disabled?: boolean;
}

export interface UpdateUserData {
  email?: string;
  displayName?: string;
  phoneNumber?: string;
  photoURL?: string;
  disabled?: boolean;
}

@Injectable()
export class FirebaseAuthService {
  private readonly logger = new Logger(FirebaseAuthService.name);

  constructor(private firebaseAdmin: FirebaseAdminService) {}

  /**
   * Verify Firebase ID token and return user data
   */
  async verifyToken(idToken: string): Promise<admin.auth.DecodedIdToken> {
    try {
      const decodedToken = await this.firebaseAdmin.verifyIdToken(idToken);
      this.logger.log(`Token verified for user: ${decodedToken.uid}`);
      return decodedToken;
    } catch (error) {
      this.logger.error('Token verification failed:', error.message);
      throw new UnauthorizedException('Invalid or expired token');
    }
  }

  /**
   * Create a new user with email and password
   */
  async createUser(userData: CreateUserData): Promise<admin.auth.UserRecord> {
    try {
      const userRecord = await this.firebaseAdmin.createUser({
        email: userData.email,
        password: userData.password,
        displayName: userData.displayName,
        phoneNumber: userData.phoneNumber,
        photoURL: userData.photoURL,
        disabled: userData.disabled || false,
      });

      this.logger.log(`User created successfully: ${userRecord.uid}`);
      return userRecord;
    } catch (error) {
      this.logger.error('Error creating user:', error.message);
      
      if (error.code === 'auth/email-already-exists') {
        throw new BadRequestException('Email already exists');
      }
      if (error.code === 'auth/invalid-email') {
        throw new BadRequestException('Invalid email format');
      }
      if (error.code === 'auth/weak-password') {
        throw new BadRequestException('Password is too weak');
      }
      
      throw new BadRequestException('Failed to create user');
    }
  }

  /**
   * Get user by UID
   */
  async getUserByUid(uid: string): Promise<admin.auth.UserRecord> {
    try {
      return await this.firebaseAdmin.getUserByUid(uid);
    } catch (error) {
      this.logger.error('Error getting user by UID:', error.message);
      throw new BadRequestException('User not found');
    }
  }

  /**
   * Get user by email
   */
  async getUserByEmail(email: string): Promise<admin.auth.UserRecord> {
    try {
      const auth = await this.firebaseAdmin.getAuth();
      return await auth.getUserByEmail(email);
    } catch (error) {
      this.logger.error('Error getting user by email:', error.message);
      throw new BadRequestException('User not found');
    }
  }

  /**
   * Update user data
   */
  async updateUser(uid: string, userData: UpdateUserData): Promise<admin.auth.UserRecord> {
    try {
      const userRecord = await this.firebaseAdmin.updateUser(uid, userData);
      this.logger.log(`User updated successfully: ${uid}`);
      return userRecord;
    } catch (error) {
      this.logger.error('Error updating user:', error.message);
      throw new BadRequestException('Failed to update user');
    }
  }

  /**
   * Delete user
   */
  async deleteUser(uid: string): Promise<void> {
    try {
      await this.firebaseAdmin.deleteUser(uid);
      this.logger.log(`User deleted successfully: ${uid}`);
    } catch (error) {
      this.logger.error('Error deleting user:', error.message);
      throw new BadRequestException('Failed to delete user');
    }
  }

  /**
   * Create custom token for user
   */
  async createCustomToken(uid: string, additionalClaims?: object): Promise<string> {
    try {
      const customToken = await this.firebaseAdmin.createCustomToken(uid, additionalClaims);
      this.logger.log(`Custom token created for user: ${uid}`);
      return customToken;
    } catch (error) {
      this.logger.error('Error creating custom token:', error.message);
      throw new BadRequestException('Failed to create custom token');
    }
  }

  /**
   * Set custom user claims
   */
  async setCustomClaims(uid: string, claims: object): Promise<void> {
    try {
      const auth = await this.firebaseAdmin.getAuth();
      await auth.setCustomUserClaims(uid, claims);
      this.logger.log(`Custom claims set for user: ${uid}`);
    } catch (error) {
      this.logger.error('Error setting custom claims:', error.message);
      throw new BadRequestException('Failed to set custom claims');
    }
  }

  /**
   * Revoke refresh tokens for user
   */
  async revokeRefreshTokens(uid: string): Promise<void> {
    try {
      const auth = await this.firebaseAdmin.getAuth();
      await auth.revokeRefreshTokens(uid);
      this.logger.log(`Refresh tokens revoked for user: ${uid}`);
    } catch (error) {
      this.logger.error('Error revoking refresh tokens:', error.message);
      throw new BadRequestException('Failed to revoke refresh tokens');
    }
  }

  /**
   * Generate email verification link
   */
  async generateEmailVerificationLink(email: string): Promise<string> {
    try {
      const auth = await this.firebaseAdmin.getAuth();
      const link = await auth.generateEmailVerificationLink(email);
      this.logger.log(`Email verification link generated for: ${email}`);
      return link;
    } catch (error) {
      this.logger.error('Error generating email verification link:', error.message);
      throw new BadRequestException('Failed to generate email verification link');
    }
  }

  /**
   * Generate password reset link
   */
  async generatePasswordResetLink(email: string): Promise<string> {
    try {
      const auth = await this.firebaseAdmin.getAuth();
      const link = await auth.generatePasswordResetLink(email);
      this.logger.log(`Password reset link generated for: ${email}`);
      return link;
    } catch (error) {
      this.logger.error('Error generating password reset link:', error.message);
      throw new BadRequestException('Failed to generate password reset link');
    }
  }

  /**
   * List users with pagination
   */
  async listUsers(maxResults: number = 1000, pageToken?: string): Promise<admin.auth.ListUsersResult> {
    try {
      const auth = await this.firebaseAdmin.getAuth();
      return await auth.listUsers(maxResults, pageToken);
    } catch (error) {
      this.logger.error('Error listing users:', error.message);
      throw new BadRequestException('Failed to list users');
    }
  }

  /**
   * Disable user account
   */
  async disableUser(uid: string): Promise<admin.auth.UserRecord> {
    return this.updateUser(uid, { disabled: true });
  }

  /**
   * Enable user account
   */
  async enableUser(uid: string): Promise<admin.auth.UserRecord> {
    return this.updateUser(uid, { disabled: false });
  }
}

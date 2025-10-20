import { Injectable, Logger } from '@nestjs/common';
import * as admin from 'firebase-admin';
import * as fs from 'fs/promises';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';

export interface UploadedFile {
  name: string;
  url: string;
  downloadUrl: string;
  size: number;
  contentType: string;
}

@Injectable()
export class FirebaseStorageService {
  private readonly logger = new Logger(FirebaseStorageService.name);
  private storage: admin.storage.Storage;

  constructor() {
    this.storage = admin.storage();
    this.logger.log('Firebase Storage initialized');
  }

  /**
   * Upload file to Firebase Storage with secure naming
   * @param localPath Local file path
   * @param remotePath Remote path in Firebase Storage (e.g., 'messages/conv123/attachments/')
   * @param contentType MIME type
   * @returns Uploaded file info with URLs
   */
  async uploadFile(
    localPath: string,
    remotePath: string,
    contentType: string,
  ): Promise<UploadedFile> {
    try {
      const filename = path.basename(localPath);
      const destination = path.join(remotePath, filename).replace(/\\/g, '/');

      this.logger.log(`Uploading ${filename} to ${destination}`);

      const bucket = this.storage.bucket();
      const fileStats = await fs.stat(localPath);

      // Upload file
      await bucket.upload(localPath, {
        destination,
        metadata: {
          contentType,
          metadata: {
            uploadedAt: new Date().toISOString(),
            uploadedBy: 'backend-service',
          },
        },
        // Make file publicly readable (with authentication required)
        // predefinedAcl: 'publicRead', // Use only if you want public access
      });

      const file = bucket.file(destination);

      // Generate signed URL (valid for 7 days)
      const [signedUrl] = await file.getSignedUrl({
        action: 'read',
        expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
      });

      // Get permanent public URL (if file is public)
      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${destination}`;

      this.logger.log(
        `Successfully uploaded ${filename} (${(fileStats.size / 1024).toFixed(2)}KB)`,
      );

      return {
        name: filename,
        url: publicUrl,
        downloadUrl: signedUrl,
        size: fileStats.size,
        contentType,
      };
    } catch (error) {
      this.logger.error(`Failed to upload file ${localPath}:`, error.message);
      throw error;
    }
  }

  /**
   * Upload multiple files in parallel
   */
  async uploadMultipleFiles(
    files: Array<{ localPath: string; remotePath: string; contentType: string }>,
  ): Promise<UploadedFile[]> {
    return Promise.all(
      files.map((file) =>
        this.uploadFile(file.localPath, file.remotePath, file.contentType),
      ),
    );
  }

  /**
   * Generate secure remote path for attachment
   * @param conversationId Conversation ID
   * @param type 'images' or 'videos'
   * @returns Remote path like 'messages/conv123/attachments/images/'
   */
  generateRemotePath(conversationId: string, type: 'images' | 'videos' | 'files'): string {
    return `messages/${conversationId}/attachments/${type}/`;
  }

  /**
   * Generate unique filename to prevent overwrites
   * @param originalName Original filename
   * @param variant Optional variant name (thumbnail, medium, full)
   * @returns Unique filename with UUID
   */
  generateUniqueFilename(originalName: string, variant?: string): string {
    const ext = path.extname(originalName);
    const basename = path.basename(originalName, ext);
    const uuid = uuidv4().substring(0, 8); // Short UUID
    
    if (variant) {
      return `${basename}_${variant}_${uuid}${ext}`;
    }
    return `${basename}_${uuid}${ext}`;
  }

  /**
   * Delete file from Firebase Storage
   */
  async deleteFile(remotePath: string): Promise<void> {
    try {
      const bucket = this.storage.bucket();
      await bucket.file(remotePath).delete();
      this.logger.log(`Deleted file: ${remotePath}`);
    } catch (error) {
      this.logger.error(`Failed to delete file ${remotePath}:`, error.message);
      throw error;
    }
  }

  /**
   * Get file metadata from Firebase Storage
   */
  async getFileMetadata(remotePath: string): Promise<any> {
    try {
      const bucket = this.storage.bucket();
      const [metadata] = await bucket.file(remotePath).getMetadata();
      return metadata;
    } catch (error) {
      this.logger.error(`Failed to get metadata for ${remotePath}:`, error.message);
      throw error;
    }
  }
}

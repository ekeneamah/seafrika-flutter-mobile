import { Injectable, Logger, BadRequestException, OnModuleInit } from '@nestjs/common';
import { FirebaseAdminService } from './firebase-admin.service';
import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';

export interface UploadFileOptions {
  destination?: string;
  metadata?: { [key: string]: string };
  makePublic?: boolean;
  generateSignedUrl?: boolean;
  signedUrlExpiration?: Date;
}

export interface UploadResult {
  fileName: string;
  filePath: string;
  publicUrl?: string;
  signedUrl?: string;
  metadata?: { [key: string]: string };
}

@Injectable()
export class FirebaseStorageService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseStorageService.name);
  private bucket: any;

  constructor(private firebaseAdmin: FirebaseAdminService) {}

  async onModuleInit() {
    const storage = await this.firebaseAdmin.getStorage();
    this.bucket = storage.bucket();
  }

  /**
   * Upload file from buffer
   */
  async uploadFromBuffer(
    buffer: Buffer,
    originalName: string,
    mimeType: string,
    options: UploadFileOptions = {}
  ): Promise<UploadResult> {
    try {
      const fileName = options.destination || `${uuidv4()}-${originalName}`;
      const file = this.bucket.file(fileName);

      const stream = file.createWriteStream({
        metadata: {
          contentType: mimeType,
          metadata: options.metadata || {},
        },
      });

      return new Promise((resolve, reject) => {
        stream.on('error', (error) => {
          this.logger.error('Upload error:', error.message);
          reject(new BadRequestException('Failed to upload file'));
        });

        stream.on('finish', async () => {
          try {
            const result: UploadResult = {
              fileName,
              filePath: `gs://${this.bucket.name}/${fileName}`,
              metadata: options.metadata,
            };

            // Make file public if requested
            if (options.makePublic) {
              await file.makePublic();
              result.publicUrl = `https://storage.googleapis.com/${this.bucket.name}/${fileName}`;
            }

            // Generate signed URL if requested
            if (options.generateSignedUrl) {
              const [signedUrl] = await file.getSignedUrl({
                action: 'read',
                expires: options.signedUrlExpiration || new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours default
              });
              result.signedUrl = signedUrl;
            }

            this.logger.log(`File uploaded successfully: ${fileName}`);
            resolve(result);
          } catch (error) {
            this.logger.error('Error processing uploaded file:', error.message);
            reject(new BadRequestException('Failed to process uploaded file'));
          }
        });

        stream.end(buffer);
      });
    } catch (error) {
      this.logger.error('Error uploading file:', error.message);
      throw new BadRequestException('Failed to upload file');
    }
  }

  /**
   * Upload file from local path
   */
  async uploadFromPath(
    filePath: string,
    options: UploadFileOptions = {}
  ): Promise<UploadResult> {
    try {
      const fileName = options.destination || `${uuidv4()}-${filePath.split('/').pop()}`;
      
      const [file] = await this.bucket.upload(filePath, {
        destination: fileName,
        metadata: {
          metadata: options.metadata || {},
        },
      });

      const result: UploadResult = {
        fileName,
        filePath: `gs://${this.bucket.name}/${fileName}`,
        metadata: options.metadata,
      };

      // Make file public if requested
      if (options.makePublic) {
        await file.makePublic();
        result.publicUrl = `https://storage.googleapis.com/${this.bucket.name}/${fileName}`;
      }

      // Generate signed URL if requested
      if (options.generateSignedUrl) {
        const [signedUrl] = await file.getSignedUrl({
          action: 'read',
          expires: options.signedUrlExpiration || new Date(Date.now() + 24 * 60 * 60 * 1000),
        });
        result.signedUrl = signedUrl;
      }

      this.logger.log(`File uploaded successfully: ${fileName}`);
      return result;
    } catch (error) {
      this.logger.error('Error uploading file from path:', error.message);
      throw new BadRequestException('Failed to upload file');
    }
  }

  /**
   * Delete file
   */
  async deleteFile(fileName: string): Promise<void> {
    try {
      await this.bucket.file(fileName).delete();
      this.logger.log(`File deleted successfully: ${fileName}`);
    } catch (error) {
      this.logger.error('Error deleting file:', error.message);
      throw new BadRequestException('Failed to delete file');
    }
  }

  /**
   * Get file metadata
   */
  async getFileMetadata(fileName: string): Promise<any> {
    try {
      const [metadata] = await this.bucket.file(fileName).getMetadata();
      return metadata;
    } catch (error) {
      this.logger.error('Error getting file metadata:', error.message);
      throw new BadRequestException('Failed to get file metadata');
    }
  }

  /**
   * Check if file exists
   */
  async fileExists(fileName: string): Promise<boolean> {
    try {
      const [exists] = await this.bucket.file(fileName).exists();
      return exists;
    } catch (error) {
      this.logger.error('Error checking file existence:', error.message);
      return false;
    }
  }

  /**
   * Get signed URL for file
   */
  async getSignedUrl(
    fileName: string,
    action: 'read' | 'write' | 'delete' = 'read',
    expiration: Date = new Date(Date.now() + 24 * 60 * 60 * 1000)
  ): Promise<string> {
    try {
      const [signedUrl] = await this.bucket.file(fileName).getSignedUrl({
        action,
        expires: expiration,
      });
      return signedUrl;
    } catch (error) {
      this.logger.error('Error generating signed URL:', error.message);
      throw new BadRequestException('Failed to generate signed URL');
    }
  }

  /**
   * Make file public
   */
  async makeFilePublic(fileName: string): Promise<string> {
    try {
      await this.bucket.file(fileName).makePublic();
      const publicUrl = `https://storage.googleapis.com/${this.bucket.name}/${fileName}`;
      this.logger.log(`File made public: ${fileName}`);
      return publicUrl;
    } catch (error) {
      this.logger.error('Error making file public:', error.message);
      throw new BadRequestException('Failed to make file public');
    }
  }

  /**
   * List files in bucket
   */
  async listFiles(prefix?: string, maxResults?: number): Promise<any[]> {
    try {
      const [files] = await this.bucket.getFiles({
        prefix,
        maxResults,
      });

      return files.map(file => ({
        name: file.name,
        bucket: file.bucket.name,
        generation: file.generation,
        metageneration: file.metageneration,
      }));
    } catch (error) {
      this.logger.error('Error listing files:', error.message);
      throw new BadRequestException('Failed to list files');
    }
  }

  /**
   * Download file as buffer
   */
  async downloadFile(fileName: string): Promise<Buffer> {
    try {
      const [buffer] = await this.bucket.file(fileName).download();
      return buffer;
    } catch (error) {
      this.logger.error('Error downloading file:', error.message);
      throw new BadRequestException('Failed to download file');
    }
  }

  /**
   * Copy file
   */
  async copyFile(sourceFileName: string, destinationFileName: string): Promise<void> {
    try {
      await this.bucket.file(sourceFileName).copy(this.bucket.file(destinationFileName));
      this.logger.log(`File copied: ${sourceFileName} -> ${destinationFileName}`);
    } catch (error) {
      this.logger.error('Error copying file:', error.message);
      throw new BadRequestException('Failed to copy file');
    }
  }

  /**
   * Move file
   */
  async moveFile(sourceFileName: string, destinationFileName: string): Promise<void> {
    try {
      await this.bucket.file(sourceFileName).move(destinationFileName);
      this.logger.log(`File moved: ${sourceFileName} -> ${destinationFileName}`);
    } catch (error) {
      this.logger.error('Error moving file:', error.message);
      throw new BadRequestException('Failed to move file');
    }
  }
}

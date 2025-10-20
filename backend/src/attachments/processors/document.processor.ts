import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { promises as fs } from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';

export interface DocumentMetadata {
  fileName: string;
  fileSize: number;
  mimeType: string;
  extension: string;
  pages?: number;
  isEncrypted?: boolean;
}

export interface ProcessedDocument {
  filePath: string;
  metadata: DocumentMetadata;
  thumbnailPath?: string;
}

@Injectable()
export class DocumentProcessorService {
  private readonly logger = new Logger(DocumentProcessorService.name);

  // Allowed document types with their magic bytes signatures
  private readonly ALLOWED_TYPES = {
    'application/pdf': {
      extensions: ['.pdf'],
      magicBytes: [[0x25, 0x50, 0x44, 0x46]], // %PDF
      maxSize: 25 * 1024 * 1024, // 25MB
    },
    'application/msword': {
      extensions: ['.doc'],
      magicBytes: [[0xD0, 0xCF, 0x11, 0xE0]], // DOC
      maxSize: 25 * 1024 * 1024,
    },
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': {
      extensions: ['.docx'],
      magicBytes: [[0x50, 0x4B, 0x03, 0x04]], // ZIP-based (DOCX)
      maxSize: 25 * 1024 * 1024,
    },
    'application/vnd.ms-excel': {
      extensions: ['.xls'],
      magicBytes: [[0xD0, 0xCF, 0x11, 0xE0]], // XLS
      maxSize: 25 * 1024 * 1024,
    },
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': {
      extensions: ['.xlsx'],
      magicBytes: [[0x50, 0x4B, 0x03, 0x04]], // ZIP-based (XLSX)
      maxSize: 25 * 1024 * 1024,
    },
    'application/vnd.ms-powerpoint': {
      extensions: ['.ppt'],
      magicBytes: [[0xD0, 0xCF, 0x11, 0xE0]], // PPT
      maxSize: 25 * 1024 * 1024,
    },
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': {
      extensions: ['.pptx'],
      magicBytes: [[0x50, 0x4B, 0x03, 0x04]], // ZIP-based (PPTX)
      maxSize: 25 * 1024 * 1024,
    },
    'text/plain': {
      extensions: ['.txt'],
      magicBytes: [], // TXT files don't have magic bytes
      maxSize: 10 * 1024 * 1024, // 10MB for text files
    },
    'application/rtf': {
      extensions: ['.rtf'],
      magicBytes: [[0x7B, 0x5C, 0x72, 0x74, 0x66]], // {\rtf
      maxSize: 10 * 1024 * 1024,
    },
  };

  /**
   * Process document: validate, extract metadata
   */
  async processDocument(inputPath: string): Promise<ProcessedDocument> {
    this.logger.log(`Processing document: ${inputPath}`);

    try {
      // 1. Validate file exists
      await fs.access(inputPath);

      // 2. Validate file type and size
      const isValid = await this.validateDocumentFile(inputPath);
      if (!isValid.valid) {
        throw new BadRequestException(isValid.reason);
      }

      // 3. Extract metadata
      const metadata = await this.extractMetadata(inputPath);

      // 4. Check for malicious content patterns
      await this.scanForMaliciousContent(inputPath, metadata.mimeType);

      this.logger.log(`Document processed successfully: ${metadata.fileName}`);

      return {
        filePath: inputPath,
        metadata,
      };
    } catch (error) {
      this.logger.error(`Error processing document: ${error.message}`);
      throw error;
    }
  }

  /**
   * Validate document file type using magic bytes and size limits
   */
  async validateDocumentFile(
    filePath: string,
  ): Promise<{ valid: boolean; reason?: string }> {
    try {
      const stats = await fs.stat(filePath);
      const buffer = Buffer.alloc(8);
      const fileHandle = await fs.open(filePath, 'r');
      await fileHandle.read(buffer, 0, 8, 0);
      await fileHandle.close();

      const ext = path.extname(filePath).toLowerCase();

      // Find matching type
      let matchedType: string | null = null;
      let matchedConfig: any = null;

      for (const [mimeType, config] of Object.entries(this.ALLOWED_TYPES)) {
        if (config.extensions.includes(ext)) {
          // Check magic bytes if defined
          if (config.magicBytes.length > 0) {
            const matches = config.magicBytes.some((signature) =>
              signature.every((byte, index) => buffer[index] === byte),
            );

            if (matches) {
              matchedType = mimeType;
              matchedConfig = config;
              break;
            }
          } else {
            // No magic bytes (e.g., TXT files)
            matchedType = mimeType;
            matchedConfig = config;
            break;
          }
        }
      }

      if (!matchedType) {
        return {
          valid: false,
          reason: `Unsupported document type. Allowed: ${Object.values(this.ALLOWED_TYPES)
            .flatMap((c) => c.extensions)
            .join(', ')}`,
        };
      }

      // Check file size
      if (stats.size > matchedConfig.maxSize) {
        return {
          valid: false,
          reason: `File too large. Maximum size: ${matchedConfig.maxSize / 1024 / 1024}MB`,
        };
      }

      // Additional validation for specific types
      if (matchedType === 'application/pdf') {
        const isValidPdf = await this.validatePdfStructure(filePath);
        if (!isValidPdf) {
          return { valid: false, reason: 'Invalid or corrupted PDF file' };
        }
      }

      return { valid: true };
    } catch (error) {
      return { valid: false, reason: `Validation error: ${error.message}` };
    }
  }

  /**
   * Validate PDF structure
   */
  private async validatePdfStructure(filePath: string): Promise<boolean> {
    try {
      const content = await fs.readFile(filePath, 'utf-8');

      // Check for PDF header
      if (!content.startsWith('%PDF-')) {
        return false;
      }

      // Check for EOF marker
      if (!content.includes('%%EOF')) {
        return false;
      }

      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Extract document metadata
   */
  private async extractMetadata(filePath: string): Promise<DocumentMetadata> {
    const stats = await fs.stat(filePath);
    const ext = path.extname(filePath).toLowerCase();
    const fileName = path.basename(filePath);

    // Find MIME type
    let mimeType = 'application/octet-stream';
    for (const [mime, config] of Object.entries(this.ALLOWED_TYPES)) {
      if (config.extensions.includes(ext)) {
        mimeType = mime;
        break;
      }
    }

    const metadata: DocumentMetadata = {
      fileName,
      fileSize: stats.size,
      mimeType,
      extension: ext,
    };

    // Extract additional metadata for PDFs
    if (mimeType === 'application/pdf') {
      try {
        const pdfMetadata = await this.extractPdfMetadata(filePath);
        Object.assign(metadata, pdfMetadata);
      } catch (error) {
        this.logger.warn(`Could not extract PDF metadata: ${error.message}`);
      }
    }

    return metadata;
  }

  /**
   * Extract PDF metadata (page count, encryption status)
   */
  private async extractPdfMetadata(
    filePath: string,
  ): Promise<Partial<DocumentMetadata>> {
    try {
      const content = await fs.readFile(filePath, 'utf-8');

      // Count pages (simple approach - count /Page objects)
      const pageMatches = content.match(/\/Type\s*\/Page[^s]/g);
      const pages = pageMatches ? pageMatches.length : undefined;

      // Check if encrypted
      const isEncrypted = content.includes('/Encrypt');

      return { pages, isEncrypted };
    } catch (error) {
      return {};
    }
  }

  /**
   * Scan for malicious content patterns
   */
  private async scanForMaliciousContent(
    filePath: string,
    mimeType: string,
  ): Promise<void> {
    try {
      // Read file content
      const buffer = await fs.readFile(filePath);

      // Check for executable code patterns in PDFs
      if (mimeType === 'application/pdf') {
        const content = buffer.toString('utf-8');

        // Check for JavaScript in PDF
        if (content.includes('/JavaScript') || content.includes('/JS')) {
          this.logger.warn(`PDF contains JavaScript: ${filePath}`);
          throw new BadRequestException(
            'PDF files with JavaScript are not allowed',
          );
        }

        // Check for embedded files
        if (content.includes('/EmbeddedFile')) {
          this.logger.warn(`PDF contains embedded files: ${filePath}`);
          throw new BadRequestException(
            'PDF files with embedded files are not allowed',
          );
        }

        // Check for launch actions
        if (content.includes('/Launch')) {
          this.logger.warn(`PDF contains launch actions: ${filePath}`);
          throw new BadRequestException(
            'PDF files with launch actions are not allowed',
          );
        }
      }

      // Check for macros in Office documents
      if (
        mimeType === 'application/msword' ||
        mimeType === 'application/vnd.ms-excel' ||
        mimeType === 'application/vnd.ms-powerpoint'
      ) {
        // Check for VBA macros signature
        if (buffer.includes('_VBA_PROJECT')) {
          this.logger.warn(`Office document contains macros: ${filePath}`);
          throw new BadRequestException(
            'Office documents with macros are not allowed',
          );
        }
      }
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      this.logger.warn(
        `Could not scan for malicious content: ${error.message}`,
      );
    }
  }

  /**
   * Clean up temporary files
   */
  async cleanupFiles(filePaths: string[]): Promise<void> {
    for (const filePath of filePaths) {
      try {
        await fs.unlink(filePath);
        this.logger.log(`Cleaned up file: ${filePath}`);
      } catch (error) {
        this.logger.warn(`Failed to cleanup file ${filePath}: ${error.message}`);
      }
    }
  }
}

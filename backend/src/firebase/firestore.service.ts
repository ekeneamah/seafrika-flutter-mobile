import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { FirebaseAdminService } from './firebase-admin.service';
import * as admin from 'firebase-admin';

export interface FirestoreQuery {
  collection: string;
  where?: Array<{
    field: string;
    operator: FirebaseFirestore.WhereFilterOp;
    value: any;
  }>;
  orderBy?: Array<{
    field: string;
    direction?: 'asc' | 'desc';
  }>;
  limit?: number;
  startAfter?: any;
}

@Injectable()
export class FirestoreService implements OnModuleInit {
  private readonly logger = new Logger(FirestoreService.name);
  private firestore: FirebaseFirestore.Firestore;

  constructor(private firebaseAdmin: FirebaseAdminService) {}

  async onModuleInit() {
    this.firestore = await this.firebaseAdmin.getFirestore();
    this.logger.log('Firebase Firestore service initialized');
  }

  /**
   * Get Firestore instance
   */
  getFirestore(): FirebaseFirestore.Firestore {
    return this.firestore;
  }

  /**
   * Create a document in a collection
   */
  async createDocument(collection: string, data: any, documentId?: string): Promise<string> {
    try {
      const collectionRef = this.firestore.collection(collection);
      
      if (documentId) {
        await collectionRef.doc(documentId).set(data);
        return documentId;
      } else {
        const docRef = await collectionRef.add(data);
        return docRef.id;
      }
    } catch (error) {
      this.logger.error(`Error creating document in ${collection}:`, error.message);
      throw error;
    }
  }

  /**
   * Get a document by ID
   */
  async getDocument(collection: string, documentId: string): Promise<any> {
    try {
      const docRef = this.firestore.collection(collection).doc(documentId);
      const doc = await docRef.get();
      
      if (!doc.exists) {
        return null;
      }
      
      return { id: doc.id, ...doc.data() };
    } catch (error) {
      this.logger.error(`Error getting document ${documentId} from ${collection}:`, error.message);
      throw error;
    }
  }

  /**
   * Update a document
   */
  async updateDocument(collection: string, documentId: string, data: any): Promise<void> {
    try {
      const docRef = this.firestore.collection(collection).doc(documentId);
      await docRef.update(data);
    } catch (error) {
      this.logger.error(`Error updating document ${documentId} in ${collection}:`, error.message);
      throw error;
    }
  }

  /**
   * Delete a document
   */
  async deleteDocument(collection: string, documentId: string): Promise<void> {
    try {
      const docRef = this.firestore.collection(collection).doc(documentId);
      await docRef.delete();
    } catch (error) {
      this.logger.error(`Error deleting document ${documentId} from ${collection}:`, error.message);
      throw error;
    }
  }

  /**
   * Query documents with filters
   */
  async queryDocuments(queryOptions: FirestoreQuery): Promise<any[]> {
    try {
      let query: FirebaseFirestore.Query = this.firestore.collection(queryOptions.collection);

      // Apply where clauses
      if (queryOptions.where) {
        for (const condition of queryOptions.where) {
          query = query.where(condition.field, condition.operator, condition.value);
        }
      }

      // Apply order by
      if (queryOptions.orderBy) {
        for (const order of queryOptions.orderBy) {
          query = query.orderBy(order.field, order.direction || 'asc');
        }
      }

      // Apply limit
      if (queryOptions.limit) {
        query = query.limit(queryOptions.limit);
      }

      // Apply start after for pagination
      if (queryOptions.startAfter) {
        query = query.startAfter(queryOptions.startAfter);
      }

      const snapshot = await query.get();
      const documents = [];

      snapshot.forEach(doc => {
        documents.push({ id: doc.id, ...doc.data() });
      });

      return documents;
    } catch (error) {
      this.logger.error(`Error querying documents from ${queryOptions.collection}:`, error.message);
      throw error;
    }
  }

  /**
   * Get all documents from a collection
   */
  async getAllDocuments(collection: string, limit?: number): Promise<any[]> {
    try {
      let query: FirebaseFirestore.Query = this.firestore.collection(collection);
      
      if (limit) {
        query = query.limit(limit);
      }

      const snapshot = await query.get();
      const documents = [];

      snapshot.forEach(doc => {
        documents.push({ id: doc.id, ...doc.data() });
      });

      return documents;
    } catch (error) {
      this.logger.error(`Error getting all documents from ${collection}:`, error.message);
      throw error;
    }
  }

  /**
   * Batch write operations
   */
  async batchWrite(operations: Array<{
    operation: 'create' | 'update' | 'delete';
    collection: string;
    documentId?: string;
    data?: any;
  }>): Promise<void> {
    try {
      const batch = this.firestore.batch();

      for (const op of operations) {
        const docRef = op.documentId 
          ? this.firestore.collection(op.collection).doc(op.documentId)
          : this.firestore.collection(op.collection).doc();

        switch (op.operation) {
          case 'create':
            batch.set(docRef, op.data);
            break;
          case 'update':
            batch.update(docRef, op.data);
            break;
          case 'delete':
            batch.delete(docRef);
            break;
        }
      }

      await batch.commit();
    } catch (error) {
      this.logger.error('Error executing batch write:', error.message);
      throw error;
    }
  }

  /**
   * Run a transaction
   */
  async runTransaction(updateFunction: (transaction: FirebaseFirestore.Transaction) => Promise<any>): Promise<any> {
    try {
      return await this.firestore.runTransaction(updateFunction);
    } catch (error) {
      this.logger.error('Error running transaction:', error.message);
      throw error;
    }
  }

  /**
   * Listen to document changes
   */
  onDocumentSnapshot(
    collection: string, 
    documentId: string, 
    callback: (data: any) => void
  ): () => void {
    const docRef = this.firestore.collection(collection).doc(documentId);
    
    const unsubscribe = docRef.onSnapshot((doc) => {
      if (doc.exists) {
        callback({ id: doc.id, ...doc.data() });
      } else {
        callback(null);
      }
    }, (error) => {
      this.logger.error(`Error listening to document ${documentId}:`, error.message);
    });

    return unsubscribe;
  }

  /**
   * Listen to collection changes
   */
  onCollectionSnapshot(
    collection: string,
    callback: (data: any[]) => void,
    queryOptions?: Omit<FirestoreQuery, 'collection'>
  ): () => void {
    let query: FirebaseFirestore.Query = this.firestore.collection(collection);

    // Apply query options if provided
    if (queryOptions?.where) {
      for (const condition of queryOptions.where) {
        query = query.where(condition.field, condition.operator, condition.value);
      }
    }

    if (queryOptions?.orderBy) {
      for (const order of queryOptions.orderBy) {
        query = query.orderBy(order.field, order.direction || 'asc');
      }
    }

    if (queryOptions?.limit) {
      query = query.limit(queryOptions.limit);
    }

    const unsubscribe = query.onSnapshot((snapshot) => {
      const documents = [];
      snapshot.forEach(doc => {
        documents.push({ id: doc.id, ...doc.data() });
      });
      callback(documents);
    }, (error) => {
      this.logger.error(`Error listening to collection ${collection}:`, error.message);
    });

    return unsubscribe;
  }

  /**
   * Check if a document exists
   */
  async documentExists(collection: string, documentId: string): Promise<boolean> {
    try {
      const docRef = this.firestore.collection(collection).doc(documentId);
      const doc = await docRef.get();
      return doc.exists;
    } catch (error) {
      this.logger.error(`Error checking if document exists:`, error.message);
      throw error;
    }
  }

  /**
   * Get document count in a collection
   */
  async getCollectionCount(collection: string): Promise<number> {
    try {
      const snapshot = await this.firestore.collection(collection).get();
      return snapshot.size;
    } catch (error) {
      this.logger.error(`Error getting collection count:`, error.message);
      throw error;
    }
  }
}

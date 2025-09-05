import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirebaseAdminService } from '../firebase/firebase-admin.service';
import * as admin from 'firebase-admin';

@Injectable()
export class FirestoreService implements OnModuleInit {
  private firestore: admin.firestore.Firestore;
  private readonly logger = new Logger(FirestoreService.name);

  constructor(
    private configService: ConfigService,
    private firebaseAdmin: FirebaseAdminService,
  ) {}

  async onModuleInit() {
    // Get Firestore instance from Firebase Admin
    this.firestore = await this.firebaseAdmin.getFirestore();
    this.logger.log('Firestore service initialized with Firebase Admin');
  }

  getFirestore(): admin.firestore.Firestore {
    return this.firestore;
  }

  collection(name: string) {
    return this.firestore.collection(name);
  }

  doc(path: string) {
    return this.firestore.doc(path);
  }

  async createDocument(collection: string, data: any, id?: string) {
    try {
      const docRef = id 
        ? this.firestore.collection(collection).doc(id)
        : this.firestore.collection(collection).doc();
      
      await docRef.set({
        ...data,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      return { id: docRef.id, ...data };
    } catch (error) {
      this.logger.error(`Error creating document in ${collection}:`, error);
      throw error;
    }
  }

  async updateDocument(collection: string, id: string, data: any) {
    try {
      const docRef = this.firestore.collection(collection).doc(id);
      await docRef.update({
        ...data,
        updatedAt: new Date(),
      });
      return { id, ...data };
    } catch (error) {
      this.logger.error(`Error updating document ${id} in ${collection}:`, error);
      throw error;
    }
  }

  async getDocument(collection: string, id: string) {
    try {
      const doc = await this.firestore.collection(collection).doc(id).get();
      if (!doc.exists) {
        return null;
      }
      return { id: doc.id, ...doc.data() };
    } catch (error) {
      this.logger.error(`Error getting document ${id} from ${collection}:`, error);
      throw error;
    }
  }

  async deleteDocument(collection: string, id: string) {
    try {
      await this.firestore.collection(collection).doc(id).delete();
      return { success: true };
    } catch (error) {
      this.logger.error(`Error deleting document ${id} from ${collection}:`, error);
      throw error;
    }
  }

  async getDocuments(
    collection: string,
    where?: { field: string; operator: any; value: any }[],
    orderBy?: { field: string; direction: 'asc' | 'desc' },
    limit?: number
  ) {
    try {
      let query: any = this.firestore.collection(collection);

      if (where && where.length > 0) {
        where.forEach(condition => {
          query = query.where(condition.field, condition.operator, condition.value);
        });
      }

      if (orderBy) {
        query = query.orderBy(orderBy.field, orderBy.direction);
      }

      if (limit) {
        query = query.limit(limit);
      }

      const snapshot = await query.get();
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } catch (error) {
      this.logger.error(`Error getting documents from ${collection}:`, error);
      throw error;
    }
  }

  async runTransaction(callback: (transaction: any) => Promise<any>) {
    return this.firestore.runTransaction(callback);
  }

  async batch() {
    return this.firestore.batch();
  }
}

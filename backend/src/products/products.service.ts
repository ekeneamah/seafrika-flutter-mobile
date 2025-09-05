import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { FirestoreService } from '../firestore/firestore.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class ProductsService {
  constructor(private readonly firestoreService: FirestoreService) {}

  async create(createProductDto: CreateProductDto, userId: string): Promise<any> {
    const productId = uuidv4();
    const productData = {
      id: productId,
      ...createProductDto,
      createdBy: userId,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const docRef = this.firestoreService.collection('products').doc(productId);
    await docRef.set(productData);

    return { id: productId, ...productData };
  }

  async findAll(options: {
    businessId?: string;
    category?: string;
    search?: string;
    limit: number;
    page: number;
  }): Promise<any[]> {
    let query: any = this.firestoreService.collection('products');

    if (options.businessId) {
      query = query.where('businessId', '==', options.businessId);
    }

    if (options.category) {
      query = query.where('category', '==', options.category);
    }

    if (options.search) {
      // Simple text search - for better search, consider using Algolia or similar
      query = query.where('name', '>=', options.search)
                   .where('name', '<=', options.search + '\uf8ff');
    }

    const offset = (options.page - 1) * options.limit;
    query = query.limit(options.limit).offset(offset);

    const snapshot = await query.get();
    return snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
  }

  async findOne(id: string): Promise<any> {
    const docRef = this.firestoreService.collection('products').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new NotFoundException(`Product with ID ${id} not found`);
    }

    return { id: doc.id, ...doc.data() };
  }

  async update(id: string, updateProductDto: UpdateProductDto, userId: string): Promise<any> {
    const docRef = this.firestoreService.collection('products').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new NotFoundException(`Product with ID ${id} not found`);
    }

    const productData = doc.data();
    if (productData.createdBy !== userId) {
      throw new ForbiddenException('You can only update your own products');
    }

    const updateData = {
      ...updateProductDto,
      updatedAt: new Date(),
    };

    await docRef.update(updateData);
    
    const updatedDoc = await docRef.get();
    return { id: updatedDoc.id, ...updatedDoc.data() };
  }

  async remove(id: string, userId: string): Promise<void> {
    const docRef = this.firestoreService.collection('products').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new NotFoundException(`Product with ID ${id} not found`);
    }

    const productData = doc.data();
    if (productData.createdBy !== userId) {
      throw new ForbiddenException('You can only delete your own products');
    }

    await docRef.delete();
  }

  async findByBusiness(businessId: string): Promise<any[]> {
    const query: any = this.firestoreService.collection('products')
      .where('businessId', '==', businessId);

    const snapshot = await query.get();
    return snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
  }

  async getLowStockProducts(businessId: string): Promise<any[]> {
    const query: any = this.firestoreService.collection('products')
      .where('businessId', '==', businessId)
      .where('quantity', '<=', 10);

    const snapshot = await query.get();
    return snapshot.docs.map((doc: any) => ({ id: doc.id, ...doc.data() }));
  }
}

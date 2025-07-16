# Firestore Database Structure - Multi-Vendor Marketplace

## Overview
This document outlines the database structure for a multi-vendor marketplace application where business owners and their staff can manage their businesses, products, orders, and inventory.

## Collection Structure

### Users Collection (`users`)
- Document ID: `{userId}` (Auth UID)
```typescript
{
  id: string,                // Same as document ID
  firstName: string,
  lastName: string,
  email: string,
  phoneNumber: string?,
  profileImage: string?,     // URL to profile image
  role: 'admin' | 'user',    // Global role
  createdAt: timestamp,
  updatedAt: timestamp,
  isActive: boolean,
  fcmTokens: string[],      // For push notifications
  lastLoginAt: timestamp,
  settings: {
    notifications: boolean,
    language: string,
    theme: string
  }
}
```

### Businesses Collection (`businesses`)
- Document ID: `BIZ-{timestamp}`
```typescript
{
  id: string,               // Same as document ID
  name: string,            // Business name
  ownerId: string,         // Reference to users/{userId}
  adminIds: string[],      // References to users/{userId}
  memberIds: string[],     // References to users/{userId}
  logo: string?,          // URL to logo
  industry: string,       // Business industry/category
  country: string,       // Country of operation
  currency: string,      // Default currency
  contactEmail: string,
  contactPhone: string,
  address: {
    street: string,
    city: string,
    state: string,
    postalCode: string,
    country: string,
    location: {
      latitude: number,
      longitude: number
    }
  },
  settings: {
    taxRate: number,
    isVatRegistered: boolean,
    allowPartialPayments: boolean,
    orderNumberPrefix: string,
    invoiceNumberPrefix: string
  },
  businessHours: {
    monday: { open: string, close: string },
    // ... other days
  },
  createdAt: timestamp,
  updatedAt: timestamp,
  isActive: boolean,
  subscription: {
    plan: string,
    startDate: timestamp,
    endDate: timestamp,
    status: string
  }
}
```

### Stores Collection (`stores`)
- Document ID: `STR-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  name: string,
  type: 'physical' | 'online',
  managerIds: string[],    // References to users/{userId}
  staffIds: string[],      // References to users/{userId}
  logo: string?,
  contactEmail: string,
  contactPhone: string,
  address: {
    street: string,
    city: string,
    state: string,
    postalCode: string,
    country: string,
    location: {
      latitude: number,
      longitude: number
    }
  },
  businessHours: {
    monday: { open: string, close: string },
    // ... other days
  },
  settings: {
    allowsPickup: boolean,
    allowsDelivery: boolean,
    minimumOrder: number,
    deliveryRadius: number
  },
  createdAt: timestamp,
  updatedAt: timestamp,
  isActive: boolean
}
```

### Products Collection (`products`)
- Document ID: `PRD-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  storeId: string,        // Reference to stores/{storeId}
  name: string,
  description: string,
  sku: string,
  barcode: string?,
  category: string,
  subCategory: string?,
  brand: string?,
  images: string[],       // URLs to product images
  price: number,
  compareAtPrice: number?, // Original price if on sale
  cost: number,           // Cost price
  unit: string,          // e.g., 'piece', 'kg', 'liter'
  tags: string[],
  attributes: {
    [key: string]: string // Dynamic attributes
  },
  variants: [
    {
      id: string,
      name: string,
      sku: string,
      barcode: string?,
      price: number,
      compareAtPrice: number?,
      cost: number,
      attributes: {
        [key: string]: string
      },
      inventoryLevels: {
        [storeId: string]: {
          quantity: number,
          lowStockThreshold: number
        }
      }
    }
  ],
  tax: {
    taxable: boolean,
    taxRate: number?
  },
  inventoryTracking: boolean,
  lowStockThreshold: number,
  status: 'active' | 'draft' | 'archived',
  createdAt: timestamp,
  updatedAt: timestamp,
  metadata: {
    views: number,
    sales: number,
    rating: number
  }
}
```

### Inventory Collection (`inventory`)
- Document ID: `INV-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  storeId: string,        // Reference to stores/{storeId}
  productId: string,      // Reference to products/{productId}
  variantId: string?,     // For product variants
  quantity: number,
  lowStockThreshold: number,
  lastStockUpdate: timestamp,
  stockMovements: [
    {
      type: 'in' | 'out' | 'adjustment',
      quantity: number,
      reason: string,
      reference: string?, // Order ID or Purchase Order ID
      timestamp: timestamp,
      userId: string     // Who made the change
    }
  ]
}
```

### Orders Collection (`orders`)
- Document ID: `ORD-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  storeId: string,        // Reference to stores/{storeId}
  customerId: string,     // Reference to customers/{customerId}
  orderNumber: string,    // Formatted order number
  status: 'pending' | 'confirmed' | 'processing' | 'ready' | 'completed' | 'cancelled',
  items: [
    {
      productId: string,  // Reference to products/{productId}
      variantId: string?,
      name: string,
      sku: string,
      quantity: number,
      unitPrice: number,
      subtotal: number,
      tax: number,
      total: number
    }
  ],
  subtotal: number,
  tax: number,
  discount: number,
  total: number,
  payment: {
    status: 'pending' | 'paid' | 'partially_paid' | 'refunded',
    method: string,
    transactions: [
      {
        id: string,
        amount: number,
        status: string,
        timestamp: timestamp,
        reference: string
      }
    ]
  },
  delivery: {
    method: 'pickup' | 'delivery',
    address: {
      street: string,
      city: string,
      state: string,
      postalCode: string,
      country: string,
      location: {
        latitude: number,
        longitude: number
      }
    },
    status: string,
    trackingNumber: string?,
    carrier: string?,
    estimatedDelivery: timestamp?
  },
  notes: string?,
  createdAt: timestamp,
  updatedAt: timestamp,
  metadata: {
    source: string,      // Order source (pos, online, etc.)
    deviceId: string?,
    staffId: string?    // Who processed the order
  }
}
```

### Customers Collection (`customers`)
- Document ID: `CUS-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  firstName: string,
  lastName: string,
  email: string,
  phoneNumber: string,
  addresses: [
    {
      id: string,
      type: 'billing' | 'shipping',
      isDefault: boolean,
      street: string,
      city: string,
      state: string,
      postalCode: string,
      country: string
    }
  ],
  tags: string[],
  notes: string?,
  createdAt: timestamp,
  updatedAt: timestamp,
  metadata: {
    totalOrders: number,
    totalSpent: number,
    lastOrderDate: timestamp?
  }
}
```

### Staff Collection (`staff`)
- Document ID: `STF-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  userId: string,         // Reference to users/{userId}
  businessId: string,     // Reference to businesses/{businessId}
  storeIds: string[],     // References to stores/{storeId}
  role: 'manager' | 'staff' | 'cashier',
  permissions: string[],  // List of allowed actions
  status: 'active' | 'inactive',
  workingHours: {
    monday: { start: string, end: string },
    // ... other days
  },
  createdAt: timestamp,
  updatedAt: timestamp,
  metadata: {
    lastActive: timestamp,
    totalSales: number,
    totalOrders: number
  }
}
```

### Tasks Collection (`tasks`)
- Document ID: `TSK-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  storeId: string?,       // Reference to stores/{storeId}
  assignedTo: string[],   // References to users/{userId}
  title: string,
  description: string,
  priority: 'low' | 'medium' | 'high',
  status: 'pending' | 'in_progress' | 'completed' | 'cancelled',
  dueDate: timestamp,
  category: string,      // e.g., 'inventory', 'orders', 'maintenance'
  attachments: [{
    name: string,
    url: string,
    type: string,
    size: number
  }],
  checklist: [{
    id: string,
    text: string,
    isCompleted: boolean,
    completedAt: timestamp?,
    completedBy: string?  // Reference to users/{userId}
  }],
  comments: [{
    id: string,
    userId: string,      // Reference to users/{userId}
    text: string,
    timestamp: timestamp,
    attachments: [{
      name: string,
      url: string,
      type: string,
      size: number
    }]
  }],
  createdBy: string,     // Reference to users/{userId}
  createdAt: timestamp,
  updatedAt: timestamp,
  completedAt: timestamp?,
  metadata: {
    lastActivity: timestamp,
    commentCount: number,
    checklistTotal: number,
    checklistCompleted: number
  }
}
```

### Suppliers Collection (`suppliers`)
- Document ID: `SUP-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  name: string,
  code: string?,          // Custom supplier code
  contactPerson: {
    name: string,
    email: string,
    phone: string,
    position: string?
  },
  company: {
    registrationNumber: string?,
    taxId: string?,
    website: string?
  },
  address: {
    street: string,
    city: string,
    state: string,
    postalCode: string,
    country: string,
    location: {
      latitude: number,
      longitude: number
    }
  },
  paymentTerms: {
    type: 'prepaid' | 'net_days' | 'end_of_month',
    days: number?,
    notes: string?
  },
  currency: string,
  tags: string[],
  categories: string[],  // Product categories supplied
  status: 'active' | 'inactive',
  rating: number,       // Supplier rating (1-5)
  notes: string?,
  documents: [{
    id: string,
    name: string,
    type: string,
    url: string,
    uploadedAt: timestamp
  }],
  createdAt: timestamp,
  updatedAt: timestamp,
  metadata: {
    totalOrders: number,
    totalSpent: number,
    lastOrderDate: timestamp?,
    averageDeliveryDays: number,
    qualityRating: number,
    responseTimeRating: number
  }
}
```

### Purchase Orders Collection (`purchaseOrders`)
- Document ID: `PO-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  storeId: string,        // Reference to stores/{storeId}
  supplierId: string,     // Reference to suppliers/{supplierId}
  orderNumber: string,    // Formatted PO number
  status: 'draft' | 'sent' | 'confirmed' | 'partially_received' | 'completed' | 'cancelled',
  items: [{
    productId: string,    // Reference to products/{productId}
    variantId: string?,
    name: string,
    sku: string,
    quantity: number,
    receivedQuantity: number,
    unitPrice: number,
    subtotal: number,
    tax: number,
    total: number,
    notes: string?
  }],
  subtotal: number,
  tax: number,
  discount: number,
  shipping: number,
  total: number,
  currency: string,
  paymentTerms: {
    type: string,
    days: number?,
    notes: string?
  },
  expectedDeliveryDate: timestamp,
  deliveryAddress: {
    street: string,
    city: string,
    state: string,
    postalCode: string,
    country: string,
    notes: string?
  },
  documents: [{
    id: string,
    type: 'po' | 'invoice' | 'delivery_note' | 'other',
    name: string,
    url: string,
    uploadedAt: timestamp
  }],
  receipts: [{
    id: string,
    date: timestamp,
    items: [{
      productId: string,
      variantId: string?,
      quantity: number,
      notes: string?
    }],
    receivedBy: string,  // Reference to users/{userId}
    notes: string?
  }],
  notes: string?,
  createdBy: string,     // Reference to users/{userId}
  createdAt: timestamp,
  updatedAt: timestamp,
  metadata: {
    lastActivity: timestamp,
    receivedItemsCount: number,
    totalItemsCount: number
  }
}
```

### Reviews Collection (`reviews`)
- Document ID: `REV-{timestamp}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  storeId: string,        // Reference to stores/{storeId}
  productId: string?,     // Reference to products/{productId}
  orderId: string?,       // Reference to orders/{orderId}
  customerId: string,     // Reference to customers/{customerId}
  rating: number,         // 1-5 rating
  title: string?,
  content: string,
  images: [{
    url: string,
    thumbnail: string
  }],
  status: 'pending' | 'approved' | 'rejected' | 'hidden',
  response: {
    content: string,
    respondedBy: string,  // Reference to users/{userId}
    respondedAt: timestamp
  }?,
  flags: [{
    reason: string,
    flaggedBy: string,   // Reference to users/{userId}
    timestamp: timestamp
  }],
  helpful: {
    count: number,
    userIds: string[]    // References to users/{userId}
  },
  createdAt: timestamp,
  updatedAt: timestamp,
  metadata: {
    platform: string,    // Where the review was created
    verified: boolean,   // Whether the reviewer made a purchase
    edited: boolean
  }
}
```

### Analytics Collection (`analytics`)
- Document ID: `{businessId}_{timeframe}_{type}`
```typescript
{
  id: string,              // Same as document ID
  businessId: string,      // Reference to businesses/{businessId}
  storeId: string?,       // Reference to stores/{storeId}
  timeframe: 'daily' | 'weekly' | 'monthly' | 'yearly',
  type: 'sales' | 'inventory' | 'customers' | 'staff',
  date: timestamp,        // Start of the period
  metrics: {
    // Sales metrics
    totalSales: number,
    orderCount: number,
    averageOrderValue: number,
    returnsCount: number,
    returnsValue: number,
    
    // Inventory metrics
    stockValue: number,
    lowStockItems: number,
    outOfStockItems: number,
    inventoryTurnover: number,
    
    // Customer metrics
    newCustomers: number,
    repeatCustomers: number,
    customerRetentionRate: number,
    
    // Staff metrics
    staffProductivity: number,
    salesPerStaff: Map<string, number>,
    workingHours: Map<string, number>
  },
  topItems: [{
    productId: string,
    name: string,
    quantity: number,
    revenue: number
  }],
  categoryPerformance: [{
    category: string,
    sales: number,
    quantity: number,
    profit: number
  }],
  hourlyData: [{
    hour: number,
    sales: number,
    orders: number,
    customers: number
  }],
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## Security Rules Structure
```typescript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Common functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isSignedIn() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    function isBusinessOwner(businessId) {
      return isSignedIn() && 
        get(/databases/$(database)/documents/businesses/$(businessId)).data.ownerId == request.auth.uid;
    }
    
    function isBusinessAdmin(businessId) {
      return isSignedIn() && 
        get(/databases/$(database)/documents/businesses/$(businessId)).data.adminIds.hasAny([request.auth.uid]);
    }
    
    function isBusinessStaff(businessId) {
      return isSignedIn() && exists(/databases/$(database)/documents/staff/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/staff/$(request.auth.uid)).data.businessId == businessId;
    }
    
    // Business rules
    match /businesses/{businessId} {
      allow read: if isSignedIn() && (isAdmin() || isBusinessOwner(businessId) || 
                                    isBusinessAdmin(businessId) || isBusinessStaff(businessId));
      allow create: if isSignedIn();
      allow update: if isAdmin() || isBusinessOwner(businessId) || isBusinessAdmin(businessId);
      allow delete: if isAdmin() || isBusinessOwner(businessId);
    }
    
    // Store rules
    match /stores/{storeId} {
      allow read: if isSignedIn() && (isAdmin() || isBusinessOwner(resource.data.businessId) || 
                                    isBusinessAdmin(resource.data.businessId) || 
                                    isBusinessStaff(resource.data.businessId));
      allow create: if isSignedIn() && (isAdmin() || isBusinessOwner(request.resource.data.businessId) || 
                                      isBusinessAdmin(request.resource.data.businessId));
      allow update: if isAdmin() || isBusinessOwner(resource.data.businessId) || 
                                  isBusinessAdmin(resource.data.businessId);
      allow delete: if isAdmin() || isBusinessOwner(resource.data.businessId);
    }
    
    // Task rules
    match /tasks/{taskId} {
      allow read: if isSignedIn() && (isAdmin() || isBusinessOwner(resource.data.businessId) || 
                                      isBusinessAdmin(resource.data.businessId) || 
                                      isBusinessStaff(resource.data.businessId));
      allow create: if isSignedIn();
      allow update: if isAdmin() || isBusinessOwner(resource.data.businessId) || 
                                  isBusinessAdmin(resource.data.businessId) || 
                                  resource.data.assignedTo.hasAny([request.auth.uid]);
      allow delete: if isAdmin() || isBusinessOwner(resource.data.businessId);
    }
    
    // Supplier rules
    match /suppliers/{supplierId} {
      allow read: if isSignedIn() && (isAdmin() || isBusinessOwner(resource.data.businessId) || 
                                      isBusinessAdmin(resource.data.businessId));
      allow create: if isSignedIn();
      allow update: if isAdmin() || isBusinessOwner(resource.data.businessId) || 
                                  isBusinessAdmin(resource.data.businessId);
      allow delete: if isAdmin() || isBusinessOwner(resource.data.businessId);
    }
    
    // Purchase Order rules
    match /purchaseOrders/{orderId} {
      allow read: if isSignedIn() && (isAdmin() || isBusinessOwner(resource.data.businessId) || 
                                      isBusinessAdmin(resource.data.businessId));
      allow create: if isSignedIn();
      allow update: if isAdmin() || isBusinessOwner(resource.data.businessId) || 
                                  isBusinessAdmin(resource.data.businessId);
      allow delete: if isAdmin() || isBusinessOwner(resource.data.businessId);
    }
    
    // Similar rules for other collections...
  }
}
```

## Indexes
Important composite indexes needed:
```typescript
// Orders by business and date
collection: orders
fields: businessId ASC, createdAt DESC

// Products by business and category
collection: products
fields: businessId ASC, category ASC, name ASC

// Inventory by store and stock level
collection: inventory
fields: storeId ASC, quantity ASC

// Staff by business and role
collection: staff
fields: businessId ASC, role ASC

// Customers by business and total spent
collection: customers
fields: businessId ASC, metadata.totalSpent DESC

// Tasks by business and status
collection: tasks
fields: businessId ASC, status ASC, dueDate ASC

// Tasks by assignee
collection: tasks
fields: businessId ASC, assignedTo ASC, status ASC

// Purchase Orders by supplier
collection: purchaseOrders
fields: businessId ASC, supplierId ASC, status ASC

// Reviews by product
collection: reviews
fields: businessId ASC, productId ASC, createdAt DESC

// Reviews by rating
collection: reviews
fields: businessId ASC, rating DESC, createdAt DESC

// Analytics by timeframe
collection: analytics
fields: businessId ASC, timeframe ASC, type ASC, date DESC
```

## Best Practices Implemented
1. **Hierarchical Data**: Business-centric structure where each document references its parent business
2. **Denormalization**: Key fields duplicated for performance
3. **Document IDs**: Prefixed IDs for easy identification and querying
4. **Security**: Granular security rules based on user roles and business membership
5. **Scalability**: Subcollections used for large datasets
6. **Indexing**: Strategic indexes for common queries
7. **References**: Clear references between related documents
8. **Timestamps**: Consistent use of timestamps for auditing
9. **Status Fields**: Active/inactive flags for soft deletes
10. **Metadata**: Performance and analytics data stored in metadata objects
11. **Task Management**: Structured task system with assignments, checklists, and comments
12. **Supplier Relations**: Comprehensive supplier profiles with performance metrics
13. **Purchase Orders**: Complete procurement system with receipt tracking
14. **Review System**: Flexible review system supporting products and orders
15. **Analytics**: Detailed analytics with multiple timeframes and metric types

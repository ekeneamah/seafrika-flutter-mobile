# Application Screens Structure

## Authentication Screens
1. **Login Screen**
   - Email/Password login
   - Forgot password
   - Remember me option
   - Social login options (if applicable)

2. **Signup Screen**
   - Basic user information
   - Terms and conditions acceptance
   - Email verification

3. **Forgot Password Screen**
   - Email input
   - Reset password flow

4. **Email Verification Screen**
   - Verification status
   - Resend verification email option

## Business Management Screens
1. **Business List Screen** ✓
   - List of user's businesses
   - Create new business button
   - Business quick actions

2. **Business Creation/Edit Screen**
   - Basic business information
   - Business hours
   - Location and contact details
   - Tax and payment settings
   - Business logo upload

3. **Business Settings Screen**
   - Business profile settings
   - Payment methods configuration
   - Tax settings
   - Invoice/receipt customization
   - Business hours management
   - Delivery zones setup

4. **Staff Management Screen**
   - Staff list view
   - Add/Edit staff members
   - Role assignment
   - Permissions management
   - Working hours setup
   - Performance metrics

5. **Role Management Screen**
   - Define custom roles
   - Permission assignment
   - Role hierarchy setup

## Store Management Screens
1. **Store List Screen**
   - List of stores under business
   - Store status indicators
   - Quick actions

2. **Store Details Screen**
   - Store information
   - Operating hours
   - Staff assignments
   - Performance metrics

3. **Store Settings Screen**
   - Delivery/Pickup options
   - Working hours
   - Payment methods
   - Store-specific tax rules

## Inventory Management Screens
1. **Products List Screen**
   - Product grid/list view
   - Quick stock updates
   - Category filtering
   - Search functionality

2. **Product Detail Screen**
   - Product information
   - Variant management
   - Image gallery
   - Pricing history
   - Stock levels across stores

3. **Inventory Movement Screen**
   - Stock adjustments
   - Transfer between stores
   - Stock count
   - Movement history

4. **Stock Alert Screen**
   - Low stock notifications
   - Out of stock items
   - Reorder suggestions

5. **Category Management Screen**
   - Category hierarchy
   - Attribute management
   - Category-specific settings

## Order Management Screens
1. **Orders Dashboard**
   - Order status overview
   - Recent orders
   - Quick actions
   - Performance metrics

2. **Order List Screen**
   - Filterable order list
   - Status management
   - Bulk actions
   - Search functionality

3. **Order Detail Screen**
   - Order information
   - Customer details
   - Payment status
   - Delivery tracking
   - Order history
   - Invoice generation

4. **POS Screen**
   - Quick product search
   - Cart management
   - Payment processing
   - Receipt printing
   - Customer assignment

## Customer Management Screens
1. **Customer List Screen**
   - Customer directory
   - Quick filters
   - Search functionality
   - Customer groups

2. **Customer Detail Screen**
   - Customer information
   - Order history
   - Address book
   - Payment methods
   - Notes and tags

3. **Customer Groups Screen**
   - Group management
   - Automated assignments
   - Group-specific settings

## Analytics & Reporting Screens
1. **Business Dashboard**
   - Key performance indicators
   - Sales overview
   - Top products
   - Customer insights
   - Stock alerts

2. **Sales Reports Screen**
   - Period comparisons
   - Product performance
   - Category analysis
   - Staff performance

3. **Inventory Reports Screen**
   - Stock levels
   - Movement analysis
   - Valuation reports
   - Reorder suggestions

4. **Customer Reports Screen**
   - Customer segments
   - Purchase patterns
   - Lifetime value
   - Retention metrics

## Settings & Configuration Screens
1. **App Settings Screen**
   - Theme preferences
   - Notification settings
   - Language selection
   - App behavior

2. **Profile Settings Screen**
   - Personal information
   - Password change
   - Notification preferences
   - Connected accounts

3. **Integration Settings Screen**
   - Payment gateway setup
   - Delivery service integration
   - Accounting software connection
   - Email/SMS service configuration

## Additional Screens Needed

### Financial Management Screens
1. **Payment Management Screen**
   - Payment processing
   - Refund management
   - Payment method configuration
   - Transaction history

2. **Expense Tracking Screen**
   - Expense categories
   - Receipt upload
   - Budget tracking
   - Expense reports

### Marketing & Promotion Screens
1. **Discount Management Screen**
   - Create/edit promotions
   - Coupon management
   - Discount rules
   - Campaign tracking

2. **Customer Communication Screen**
   - Email campaigns
   - SMS notifications
   - Push notifications
   - Campaign analytics

### Support & Help Screens
1. **Help Center Screen**
   - FAQ sections
   - Tutorial videos
   - Documentation
   - Support ticket creation

2. **Feedback & Support Screen**
   - Issue reporting
   - Feature requests
   - Chat support
   - Knowledge base

## Necessary Modifications to Database

### Additional Collections Needed

1. **Roles Collection**
```typescript
{
  id: string,
  businessId: string,
  name: string,
  permissions: string[],
  createdAt: timestamp,
  updatedAt: timestamp
}
```

2. **Categories Collection**
```typescript
{
  id: string,
  businessId: string,
  name: string,
  parentId: string?,
  attributes: {
    name: string,
    type: string,
    required: boolean
  }[],
  level: number,
  order: number,
  isActive: boolean
}
```

3. **Discounts Collection**
```typescript
{
  id: string,
  businessId: string,
  name: string,
  type: 'percentage' | 'fixed',
  value: number,
  conditions: {
    minAmount?: number,
    productIds?: string[],
    categoryIds?: string[],
    customerIds?: string[],
    startDate?: timestamp,
    endDate?: timestamp
  },
  maxUses: number,
  usedCount: number,
  status: 'active' | 'inactive',
  createdAt: timestamp,
  updatedAt: timestamp
}
```

4. **Expenses Collection**
```typescript
{
  id: string,
  businessId: string,
  storeId: string,
  category: string,
  amount: number,
  description: string,
  date: timestamp,
  receiptUrl: string?,
  status: 'pending' | 'approved' | 'rejected',
  approvedBy: string?,
  createdBy: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

### Modifications to Existing Collections

1. **Products Collection**
Add:
```typescript
{
  seoMetadata: {
    title: string,
    description: string,
    keywords: string[]
  },
  variations: {
    name: string,
    options: string[]
  }[],
  relatedProducts: string[],
  warrantyInfo: string?,
  returnPolicy: string?
}
```

2. **Orders Collection**
Add:
```typescript
{
  timeline: {
    status: string,
    timestamp: timestamp,
    note: string,
    userId: string
  }[],
  returnRequest: {
    status: string,
    reason: string,
    items: {
      productId: string,
      quantity: number,
      reason: string
    }[],
    createdAt: timestamp
  }?
}
```

3. **Customers Collection**
Add:
```typescript
{
  segments: string[],
  preferences: {
    communicationPreferences: string[],
    favoriteCategories: string[],
    favoriteStores: string[]
  },
  loyaltyPoints: number,
  customerJourney: {
    firstPurchaseDate: timestamp,
    lastPurchaseDate: timestamp,
    averageOrderValue: number,
    purchaseFrequency: number
  }
}
```

4. **Business Collection**
Add:
```typescript
{
  integrations: {
    paymentGateways: {
      provider: string,
      config: Map<string, any>,
      isActive: boolean
    }[],
    delivery: {
      provider: string,
      config: Map<string, any>,
      isActive: boolean
    }[],
    accounting: {
      provider: string,
      config: Map<string, any>,
      isActive: boolean
    }?
  },
  notifications: {
    lowStock: boolean,
    newOrder: boolean,
    customerReviews: boolean,
    staffActivity: boolean
  }
}
```

These additions and modifications will support all the new screens and functionality while maintaining the existing data structure's integrity and scalability.

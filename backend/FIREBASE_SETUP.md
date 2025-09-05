# Firebase Integration Guide

This backend includes comprehensive Firebase integration with the following services:

## 🔥 Firebase Services Included

### 1. Firebase Authentication
- **Service**: `FirebaseAuthService`
- **Features**: User management, token verification, custom tokens
- **Endpoints**: `/api/firebase/auth/*`

### 2. Firebase Storage
- **Service**: `FirebaseStorageService` 
- **Features**: File upload/download, signed URLs, public files
- **Endpoints**: `/api/firebase/storage/*`

### 3. Firebase Messaging (FCM)
- **Service**: `FirebaseMessagingService`
- **Features**: Push notifications, topic management, data messages
- **Endpoints**: `/api/firebase/messaging/*`

### 4. Firestore Database
- **Service**: `FirestoreService`
- **Features**: CRUD operations, queries, real-time listeners, transactions
- **Usage**: Injected into other services as needed

## 🚀 Setup Instructions

### 1. Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Enable the following services:
   - Authentication
   - Firestore Database
   - Storage
   - Cloud Messaging

### 2. Service Account Key

1. Go to Project Settings > Service Accounts
2. Click "Generate new private key"
3. Download the JSON file
4. Extract the values for your `.env` file

### 3. Environment Configuration

Copy `.env.example` to `.env` and fill in your Firebase credentials:

```bash
cp .env.example .env
```

Required environment variables:
```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_STORAGE_BUCKET=your-project.appspot.com
```

### 4. Install Dependencies

Firebase dependencies are already installed:
```bash
npm install firebase-admin @google-cloud/firestore firebase-functions
```

## 📚 API Documentation

### Authentication Endpoints

```http
# Create user
POST /api/firebase/auth/users
Content-Type: application/json
{
  "email": "user@example.com",
  "password": "password123",
  "displayName": "John Doe"
}

# Verify token
POST /api/firebase/auth/verify-token
{
  "idToken": "eyJhbGciOiJSUzI1NiIs..."
}

# Create custom token
POST /api/firebase/auth/custom-token
{
  "uid": "user123",
  "claims": { "role": "admin" }
}
```

### Storage Endpoints

```http
# Upload file
POST /api/firebase/storage/upload
Content-Type: multipart/form-data
file: [binary file]
destination: "uploads/image.jpg"
makePublic: "true"

# Get signed URL
GET /api/firebase/storage/files/image.jpg/signed-url?action=read

# Delete file
DELETE /api/firebase/storage/files/image.jpg
```

### Messaging Endpoints

```http
# Send notification to device
POST /api/firebase/messaging/send-to-device
{
  "token": "fcm-device-token",
  "notification": {
    "title": "Hello",
    "body": "World!"
  }
}

# Send to topic
POST /api/firebase/messaging/send-to-topic
{
  "topic": "news",
  "notification": {
    "title": "Breaking News",
    "body": "Something important happened!"
  }
}
```

## 🛠️ Using Firebase Services in Your Code

### Inject Services

```typescript
import { Injectable } from '@nestjs/common';
import { FirebaseAuthService } from './firebase/firebase-auth.service';
import { FirestoreService } from './firebase/firestore.service';

@Injectable()
export class YourService {
  constructor(
    private firebaseAuth: FirebaseAuthService,
    private firestore: FirestoreService,
  ) {}

  async createUserAndProfile(userData: any) {
    // Create Firebase user
    const user = await this.firebaseAuth.createUser(userData);
    
    // Save profile to Firestore
    await this.firestore.createDocument('users', {
      uid: user.uid,
      email: user.email,
      createdAt: new Date(),
      ...userData
    }, user.uid);
    
    return user;
  }
}
```

### Firestore Queries

```typescript
// Simple query
const users = await this.firestore.queryDocuments({
  collection: 'users',
  where: [
    { field: 'active', operator: '==', value: true }
  ],
  orderBy: [
    { field: 'createdAt', direction: 'desc' }
  ],
  limit: 10
});

// Real-time listener
const unsubscribe = this.firestore.onCollectionSnapshot(
  'products',
  (products) => {
    console.log('Products updated:', products);
  },
  {
    where: [{ field: 'category', operator: '==', value: 'electronics' }],
    orderBy: [{ field: 'price', direction: 'asc' }]
  }
);
```

## 🔒 Security Rules

### Firestore Rules Example

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Public read for products
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### Storage Rules Example

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can upload to their own folder
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Public read for product images
    match /products/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## 🧪 Testing

Start the development server:
```bash
npm run start:dev
```

Visit the Swagger documentation at:
```
http://localhost:3000/api
```

Test the Firebase endpoints using the interactive API documentation.

## 🚢 Deployment

For Google Cloud Functions deployment, the Firebase Admin SDK is already configured and ready to deploy.

Make sure your production environment variables are set correctly in your deployment platform.

## 🔍 Troubleshooting

### Common Issues

1. **Invalid private key**: Make sure the private key in `.env` includes proper line breaks (`\n`)
2. **Permission denied**: Check your Firebase project permissions and service account roles
3. **Storage bucket not found**: Verify the bucket name in your environment variables
4. **FCM token invalid**: Ensure the device tokens are valid and not expired

### Debug Mode

Enable debug logging by setting:
```env
NODE_ENV=development
```

This will show detailed Firebase operation logs in the console.

# Backend Cleanup and Consolidation Guide

This document explains the backend cleanup and consolidation performed for the Meta integration system.

## 🎯 Overview

The backend has been cleaned up and consolidated to provide a clear, maintainable structure for Meta platform integrations (Facebook Pages, Messenger, Instagram Business).

## 📁 New Structure

### **Consolidated Files**
- `meta.service.ts` - Unified service for all Meta platforms
- `meta.controller.ts` - Unified controller handling OAuth and webhooks
- `webhooks.module.ts` - Updated module with clean dependencies

### **Archived Files** (to be removed/deprecated)
- `facebook-config.service.ts` - Replaced by `meta.service.ts`
- `facebook-config.controller.ts` - Replaced by `meta.controller.ts`
- `facebook-webhook.controller.ts` - Integrated into `meta.controller.ts`
- `facebook-webhook.service.ts` - Integrated into `meta.service.ts`
- `instagram-webhook.controller.ts` - Integrated into `meta.controller.ts`
- `instagram-webhook.service.ts` - Integrated into `meta.service.ts`
- `meta-webhook.controller.ts` - Replaced by webhook methods in `meta.controller.ts`

## 🔧 Key Improvements

### **1. Unified Meta Service (`meta.service.ts`)**

**Features:**
- **Multi-channel OAuth** with least-privilege scopes
- **Token management** with encryption
- **Page access token** retrieval and management
- **Webhook subscription** management
- **Credential storage** in Firestore
- **Signature verification** for webhooks

**Supported Channels:**
```typescript
- facebook_pages: Facebook Page management
- messenger: Messenger messaging  
- instagram: Instagram Business account management
```

**Key Methods:**
```typescript
generateAuthUrl(params) // Generate OAuth URL for multiple channels
exchangeCodeForTokens() // Exchange code for tokens and create integrations
storeCredentials() // Store encrypted credentials
subscribePageToWebhooks() // Subscribe pages to webhook events
verifyWebhookSignature() // Verify webhook authenticity
```

### **2. Unified Meta Controller (`meta.controller.ts`)**

**Endpoints:**
```
GET  /api/config/meta/auth-url        - Generate OAuth URL
GET  /api/config/meta/oauth/redirect  - Handle OAuth callback
GET  /webhooks/meta                   - Webhook verification
POST /webhooks/meta                   - Webhook event handler
```

**Features:**
- **Multi-channel OAuth** URL generation
- **Business context** integration
- **Webhook event routing** (Page, Messenger, Instagram)
- **Success/error pages** for OAuth flow
- **Comprehensive logging** and error handling

### **3. Clean Module Structure**

**Updated `webhooks.module.ts`:**
- Removed duplicate/redundant services
- Consolidated Meta-related functionality
- Clear separation of concerns
- Maintained WhatsApp as separate service

## 🗺️ API Endpoints Mapping

### **Before (Multiple Endpoints)**
```
/api/config/facebook/auth-url           - Facebook OAuth
/api/config/facebook/instagram/auth-url - Instagram OAuth  
/api/config/facebook/oauth/redirect     - Facebook callback
/webhooks/facebook                      - Facebook webhooks
/webhooks/instagram                     - Instagram webhooks
```

### **After (Unified Endpoints)**
```
/api/config/meta/auth-url               - Multi-channel OAuth
/api/config/meta/oauth/redirect         - Unified callback
/webhooks/meta                          - All Meta platform webhooks
```

## 🔄 Migration Path

### **Frontend Updates Required**
Update the MetaIntegrationService to use the new endpoints:

```dart
// OLD
static const String baseUrl = 'https://your-api/api/config/facebook';

// NEW  
static const String baseUrl = 'https://your-api/api/config/meta';
```

### **Environment Variables**
No changes required - same variables:
```bash
META_APP_ID=your_app_id
META_APP_SECRET=your_app_secret  
META_WEBHOOK_VERIFY_TOKEN=your_token
META_GRAPH_API_VERSION=v21.0
```

## 📊 Benefits

### **For Developers**
- **Single codebase** for all Meta integrations
- **Consistent patterns** and error handling
- **Easier testing** and debugging
- **Better maintainability**

### **For Users**
- **Unified experience** across Meta platforms
- **Fewer OAuth flows** required
- **Comprehensive integration** setup
- **Better error messages** and feedback

## 🧹 Cleanup Steps

### **1. Archive Old Files**
Move the following files to an `archived/` directory:
```
facebook-config.service.ts
facebook-config.controller.ts  
facebook-webhook.controller.ts
facebook-webhook.service.ts
instagram-webhook.controller.ts
instagram-webhook.service.ts
meta-webhook.controller.ts (the old one)
```

### **2. Update Imports**
Any remaining references to the old services should be updated to use `MetaService`.

### **3. Database Migration**
If you have existing integrations in Firestore, you may need to migrate them to the new structure:

**Old Structure:**
```
integrations/{id}
  platformId: 'instagram' | 'facebook'
  ...
```

**New Structure:**
```
meta_credentials/{id}
  businessId: string
  accessToken: string (encrypted)
  pages: PageAccessToken[]
  ...

integrations/{id}  
  businessId: string
  channel: 'facebook_pages' | 'messenger' | 'instagram'
  platformId: 'facebook' | 'messenger' | 'instagram'
  accountInfo: {...}
  ...
```

## 🧪 Testing

### **1. OAuth Flow Testing**
```bash
# Test multi-channel OAuth URL generation
curl "http://localhost:3000/api/config/meta/auth-url?channels=facebook_pages,instagram&redirect_uri=http://localhost:3000/callback"

# Test OAuth callback
curl "http://localhost:3000/api/config/meta/oauth/redirect?code=TEST_CODE&state=business_123_456789"
```

### **2. Webhook Testing**
```bash
# Test webhook verification
curl "http://localhost:3000/webhooks/meta?hub.mode=subscribe&hub.challenge=test&hub.verify_token=YOUR_TOKEN"

# Test webhook event
curl -X POST "http://localhost:3000/webhooks/meta" \
  -H "Content-Type: application/json" \
  -H "x-hub-signature-256: sha256=..." \
  -d '{"object": "page", "entry": [...]}'
```

## 🚀 Deployment

1. **Deploy the new consolidated backend**
2. **Update frontend to use new endpoints**
3. **Test OAuth and webhook flows**
4. **Monitor logs for any issues**
5. **Archive old files after successful deployment**

## 📝 Notes

- **Backward compatibility** is maintained for essential functionality
- **Webhook URLs** need to be updated in Meta app settings
- **OAuth redirect URIs** need to be updated in Meta app settings
- **Monitoring** should be updated to track the new endpoints

The backend is now much cleaner, more maintainable, and provides a better foundation for future Meta platform integrations!
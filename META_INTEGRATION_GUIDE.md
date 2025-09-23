# Meta Graph API Integration System

This document describes the comprehensive Meta Graph API integration system for managing Facebook Pages, Messenger DMs, and Instagram Business accounts.

## Overview

The system provides a unified approach to integrate with multiple Meta platforms using OAuth 2.0 with least-privilege scopes, webhook handling, and secure token management.

## Features

- **Multi-Channel OAuth**: Generate OAuth URLs for Facebook Pages, Messenger, and Instagram with appropriate scopes
- **Least-Privilege Security**: Request only the minimum required permissions for each platform
- **Unified Webhook Handling**: Single endpoint that routes events from all Meta platforms
- **Token Management**: Secure storage and retrieval of access tokens and Page access tokens
- **Idempotent Processing**: Prevent duplicate message processing with reliable event handling
- **HMAC Verification**: Validate webhook authenticity using Meta's signature verification

## Architecture

### Backend Components

#### 1. FacebookConfigService (`backend/src/webhooks/facebook-config.service.ts`)

Core service for OAuth and token management:

- `generateAuthUrl(channels, redirectUri, state?)` - Generate OAuth URLs with least-privilege scopes
- `exchangeCodeForTokenWithPages(code, redirectUri, channels)` - Exchange authorization code for tokens and Page access tokens
- `subscribePageToWebhooks(pageAccessToken, pageId, callbackUrl)` - Subscribe pages to webhook events

**Supported Channels:**
- `facebook_pages` - Facebook Page management
- `messenger` - Messenger messaging
- `instagram` - Instagram Business account management

#### 2. MetaWebhookController (`backend/src/webhooks/meta-webhook.controller.ts`)

Unified webhook endpoint for all Meta platforms:

- Signature verification using HMAC-SHA256
- Event routing based on payload structure
- Idempotent message processing
- Rate limiting and error handling

**Webhook URL:** `POST /webhooks/meta`

#### 3. FacebookConfigController (`backend/src/webhooks/facebook-config.controller.ts`)

OAuth flow management:

- `GET /api/config/facebook/auth-url` - Generate multi-channel OAuth URLs
- `GET /api/config/facebook/instagram/oauth/redirect` - Handle OAuth callbacks
- Integration creation for each connected platform

### Frontend Components

#### 1. MetaIntegrationService (`lib/services/meta_integration_service.dart`)

Flutter service for OAuth URL generation:

```dart
// Generate OAuth URL for multiple channels
final response = await MetaIntegrationService.generateOAuthUrl(
  channels: ['facebook_pages', 'messenger', 'instagram'],
  businessId: 'your-business-id',
  state: 'optional-state',
);

// Launch OAuth in browser
final uri = Uri.parse(response.authUrl);
await launchUrl(uri);
```

#### 2. MetaIntegrationScreen (`lib/screens/meta_integration_screen.dart`)

User interface for platform selection and OAuth initiation with:

- Individual platform connection buttons
- Capability descriptions for each platform
- Error handling and loading states
- OAuth URL generation and browser launch

## OAuth Scopes by Channel

### Facebook Pages
```
pages_show_list           # List user's pages
pages_manage_metadata     # Update page information
pages_manage_posts        # Create and manage posts
pages_manage_engagement   # Respond to comments
pages_read_engagement     # Read engagement metrics
```

### Messenger
```
pages_show_list           # List user's pages
pages_manage_metadata     # Manage page settings
pages_messaging           # Send/receive messages
```

### Instagram Business
```
instagram_basic           # Basic profile access
instagram_content_publish # Publish media content
instagram_manage_comments # Manage comments
instagram_manage_messages # Handle DMs
pages_show_list           # List connected pages
pages_manage_metadata     # Manage page metadata
business_management       # Manage business assets
```

## Webhook Events

The system handles the following webhook events:

### Facebook Pages
- `feed` - New posts and updates
- `mention` - Page mentions
- `page_changes` - Page setting changes

### Messenger
- `messages` - New messages
- `messaging_postbacks` - Button clicks
- `messaging_deliveries` - Delivery confirmations
- `messaging_reads` - Read receipts

### Instagram
- `messages` - DM messages
- `comments` - New comments
- `mentions` - Story/post mentions

## Setup Instructions

### 1. Meta App Configuration

1. Create a Meta app at [developers.facebook.com](https://developers.facebook.com)
2. Add the following products:
   - Facebook Login
   - Instagram Basic Display
   - Webhooks
   - Messenger

3. Configure OAuth redirect URIs:
   ```
   https://your-api-domain.com/api/config/facebook/instagram/oauth/redirect
   ```

4. Set webhook callback URL:
   ```
   https://your-api-domain.com/webhooks/meta
   ```

### 2. Environment Variables

Set the following environment variables in your backend:

```bash
# Meta App Configuration
META_APP_ID=your_meta_app_id
META_APP_SECRET=your_meta_app_secret
META_WEBHOOK_VERIFY_TOKEN=your_webhook_verify_token

# Optional: Graph API Version
META_GRAPH_API_VERSION=v21.0
```

### 3. Webhook Subscription

The system automatically subscribes pages to webhooks during the OAuth flow. Manual subscription can be done using:

```typescript
await this.facebookConfigService.subscribePageToWebhooks(
  pageAccessToken,
  pageId,
  'https://your-api-domain.com/webhooks/meta'
);
```

### 4. Frontend Configuration

Update the base URL in `MetaIntegrationService`:

```dart
static const String baseUrl = 'https://your-api-domain.com/api/config/facebook';
```

## Usage Examples

### Generate OAuth URL for All Platforms

```dart
final response = await MetaIntegrationService.generateAllPlatformsOAuthUrl(
  businessId: 'business-123',
  state: 'user-session-state',
);

print('Connect to: ${response.channelDescriptions}');
print('Required scopes: ${response.requiredScopes.join(", ")}');
```

### Platform-Specific OAuth

```dart
// Facebook Pages only
final fbResponse = await MetaIntegrationService.generateFacebookPagesOAuthUrl();

// Messenger only
final messengerResponse = await MetaIntegrationService.generateMessengerOAuthUrl();

// Instagram only
final igResponse = await MetaIntegrationService.generateInstagramOAuthUrl();
```

### Handle OAuth Callback

The backend automatically handles OAuth callbacks and:

1. Exchanges authorization code for access tokens
2. Retrieves Page access tokens for Facebook Pages
3. Creates appropriate integrations based on granted permissions
4. Subscribes pages to webhook events
5. Stores credentials securely in Firestore

## Security Features

### HMAC Signature Verification

All webhook payloads are verified using HMAC-SHA256:

```typescript
const expectedSignature = crypto
  .createHmac('sha256', this.configService.get('META_WEBHOOK_VERIFY_TOKEN'))
  .update(rawBody)
  .digest('hex');
```

### Idempotent Processing

Messages are tracked to prevent duplicate processing:

```typescript
const messageId = `${senderId}_${timestamp}_${messageText.substring(0, 10)}`;
if (await this.isMessageProcessed(messageId)) {
  return; // Skip already processed message
}
```

### Encrypted Storage

Credentials are stored encrypted in Firestore with:
- Access tokens encrypted before storage
- Page access tokens securely associated with business accounts
- Automatic token refresh handling

## Rate Limiting

The system respects Meta's rate limits:

- **Facebook Pages**: 200 calls per hour per access token
- **Messenger**: 10,000 API calls per page per 24 hours
- **Instagram**: 200 calls per hour per access token

Rate limit headers are monitored and backoff strategies are implemented.

## Error Handling

Comprehensive error handling includes:

- OAuth errors with user-friendly messages
- Webhook validation failures
- API rate limit responses
- Network connectivity issues
- Token expiration handling

## Testing

### Test OAuth Flow

1. Use the `MetaIntegrationScreen` to generate OAuth URLs
2. Complete OAuth in browser
3. Verify integrations are created in backend
4. Check webhook subscriptions are active

### Test Webhook Events

1. Send a test message to connected page/account
2. Verify webhook endpoint receives event
3. Check idempotent processing works
4. Validate event routing to correct handler

## App Review Requirements

Some features require Meta app review:

### Facebook Pages
- `pages_manage_posts` - Publishing posts
- `pages_read_engagement` - Reading engagement metrics

### Messenger
- `pages_messaging` - Sending messages

### Instagram
- `instagram_content_publish` - Publishing content
- `instagram_manage_comments` - Managing comments
- `instagram_manage_messages` - Managing DMs

Submit for review at [developers.facebook.com/docs/app-review](https://developers.facebook.com/docs/app-review)

## Troubleshooting

### Common Issues

1. **OAuth URL Generation Fails**
   - Check Meta app ID and secret
   - Verify redirect URI is registered
   - Ensure channels parameter is valid

2. **Webhook Not Receiving Events**
   - Verify webhook URL is accessible
   - Check HMAC signature verification
   - Confirm webhook subscriptions are active

3. **Token Exchange Fails**
   - Ensure authorization code is valid and not expired
   - Check redirect URI matches exactly
   - Verify app secret is correct

4. **Rate Limit Errors**
   - Implement exponential backoff
   - Monitor rate limit headers
   - Distribute calls across time

### Debug Mode

Enable debug logging by setting environment variable:

```bash
DEBUG_META_INTEGRATION=true
```

This will log all OAuth flows, webhook events, and API calls for troubleshooting.

## Support

For technical support:

1. Check Meta Developer Documentation: [developers.facebook.com/docs](https://developers.facebook.com/docs)
2. Review Graph API Explorer: [developers.facebook.com/tools/explorer](https://developers.facebook.com/tools/explorer)
3. Meta Developer Community: [developers.facebook.com/community](https://developers.facebook.com/community)

## License

This integration system follows the Meta Platform Policy and Terms of Service.
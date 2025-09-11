# Facebook Integration Capabilities

This document outlines the comprehensive Facebook integration capabilities implemented in the SeaFrika platform.

## Overview

The Facebook integration provides full-featured social media and messaging capabilities including:

1. **Facebook Page Management**
2. **Messenger Integration**  
3. **Content Sharing**
4. **Social Interactions**
5. **User Authentication**
6. **Real-time Webhooks**

## 1. Facebook Page Management

### Capabilities
- View page information and insights
- Get page posts with engagement metrics
- Manage page roles and permissions
- Access page analytics and insights

### API Endpoints
```
GET /integrations/facebook/{integrationId}/page-info
GET /integrations/facebook/{integrationId}/posts
GET /integrations/facebook/{integrationId}/insights
GET /integrations/facebook/{integrationId}/page-roles
```

### Features
- Page information (name, category, description, follower count)
- Post management (create, edit, delete, schedule)
- Comment moderation (hide/unhide, reply)
- Analytics and insights

## 2. Messenger Integration

### Capabilities
- Send and receive private messages
- Handle message attachments (images, videos, files)
- Process postback actions and quick replies
- Auto-responder based on business hours
- Message delivery and read receipts

### API Endpoints
```
POST /integrations/facebook/{integrationId}/send-message
GET /integrations/facebook/{integrationId}/conversations
GET /integrations/facebook/{integrationId}/conversations/{conversationId}/messages
```

### Webhook Endpoints
```
GET /webhooks/facebook/messenger (verification)
POST /webhooks/facebook/messenger (events)
```

### Supported Events
- **Messages**: Text, images, videos, audio, location shares
- **Postbacks**: Button clicks, menu selections
- **Delivery**: Message delivery confirmations
- **Read**: Message read receipts
- **Referrals**: Track message origins

### Auto-Responder Features
- Business hours detection
- Away messages
- Greeting messages
- Help responses
- Intent recognition (hours, location, menu, support)

## 3. Content Sharing

### Capabilities
- Share posts to Facebook timeline
- Share content to Facebook pages
- Upload and attach media (photos, videos)
- Schedule posts for later publishing
- Set post privacy levels

### API Endpoints
```
POST /integrations/facebook/{integrationId}/posts
POST /integrations/facebook/{integrationId}/share-timeline
POST /integrations/facebook/{integrationId}/upload-media
```

### Supported Content Types
- Text posts with messages
- Link shares with previews
- Photo uploads (single or multiple)
- Video uploads
- Scheduled posts

### Privacy Options
- EVERYONE (public)
- ALL_FRIENDS 
- FRIENDS_OF_FRIENDS
- SELF (only me)
- CUSTOM (specific groups)

## 4. Social Interactions

### Capabilities
- Like/unlike posts and comments
- Add emoji reactions
- Reply to comments
- Share posts
- Mention handling

### API Endpoints
```
POST /integrations/facebook/{integrationId}/posts/{postId}/like
POST /integrations/facebook/{integrationId}/posts/{postId}/reaction
POST /integrations/facebook/{integrationId}/posts/{postId}/comments
```

### Supported Reactions
- LIKE 👍
- LOVE ❤️
- WOW 😮
- HAHA 😂
- SAD 😢
- ANGRY 😠
- THANKFUL 🙏

### Comment Management
- Auto-moderation for offensive content
- Business hours-based auto-replies
- Hide/unhide comments
- Reply to comments as page

## 5. User Authentication

### Capabilities
- Facebook Login integration
- User profile information
- Page access and permissions
- Token management

### API Endpoints
```
GET /integrations/facebook/user-profile?accessToken={token}
GET /integrations/facebook/user-pages?accessToken={token}
```

### User Data Available
- Basic profile (name, email, picture)
- Extended profile (birthday, location, about)
- Managed pages
- Page permissions and roles

## 6. Real-time Webhooks

### Webhook URLs
```
https://your-domain.com/webhooks/facebook
https://your-domain.com/webhooks/facebook/messenger
```

### Supported Events

#### Page Events
- **feed**: New posts, post edits, post deletions
- **mention**: Page mentions in posts or comments
- **conversations**: New conversations

#### Messenger Events  
- **messages**: Incoming messages
- **messaging_postbacks**: Button/menu interactions
- **message_deliveries**: Delivery confirmations
- **message_reads**: Read receipts
- **messaging_referrals**: Referral tracking

#### Instagram Events (via Facebook)
- **comments**: Instagram comment events
- **mentions**: Instagram mention events  
- **messages**: Instagram direct messages

### Webhook Security
- Signature verification using SHA256 HMAC
- Verify token validation
- HTTPS required for production

## Setup Requirements

### Facebook App Configuration

1. **Required Products**:
   - Facebook Login
   - Messenger
   - Marketing API (optional)
   - App Events (optional)

2. **Required Permissions**:
   - `pages_show_list`: Access user's pages
   - `pages_manage_metadata`: Manage page information
   - `pages_read_engagement`: Read page insights
   - `pages_manage_posts`: Create and manage posts
   - `pages_messaging`: Send/receive messages
   - `pages_manage_instant_articles`: (if using Instant Articles)

3. **Webhook Configuration**:
   - Webhook URL: `https://your-domain.com/webhooks/facebook`
   - Verify Token: Set in environment variable `FACEBOOK_WEBHOOK_VERIFY_TOKEN`
   - Subscribe to fields: `feed`, `mention`, `conversations`, `messages`, `messaging_postbacks`

### Environment Variables

```env
# Facebook App Credentials
FACEBOOK_APP_ID=your_app_id
FACEBOOK_APP_SECRET=your_app_secret

# Webhook Configuration
FACEBOOK_WEBHOOK_VERIFY_TOKEN=your_verify_token
MESSENGER_WEBHOOK_VERIFY_TOKEN=your_messenger_verify_token
```

## Business Logic Features

### Auto-Moderation
- Keyword filtering for offensive content
- Auto-hide inappropriate comments
- Escalation to human moderators

### Business Hours Integration
- Configurable business hours per day
- Auto-away messages outside hours
- Different responses for holidays

### Analytics Integration
- Track engagement metrics
- Message response times
- Customer interaction patterns
- Popular content analysis

### Customer Service Features
- Conversation threading
- Customer history tracking
- Escalation to support agents
- Quick reply templates

## Usage Examples

### Send a Message
```typescript
const result = await facebookService.sendMessage(
  'integration-id',
  'recipient-user-id',
  'Hello! How can we help you today?'
);
```

### Create a Post
```typescript
const post = await facebookService.createPost(
  'integration-id',
  'Check out our new products!',
  'https://example.com/products',
  ['media-id-1', 'media-id-2']
);
```

### Add Reaction
```typescript
const reaction = await facebookService.addReaction(
  'integration-id',
  'post-id',
  'LOVE'
);
```

### Subscribe to Webhooks
```typescript
const subscription = await facebookService.subscribeToPageWebhooks(
  'integration-id',
  ['feed', 'mention', 'conversations', 'messages']
);
```

## Best Practices

1. **Rate Limiting**: Respect Facebook's API rate limits
2. **Error Handling**: Implement retry logic for failed requests
3. **Webhook Verification**: Always verify webhook signatures
4. **Data Privacy**: Follow Facebook's data usage policies
5. **User Consent**: Ensure proper permission requests
6. **Token Management**: Refresh tokens before expiration

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure all required permissions are granted
2. **Invalid Token**: Check token expiration and refresh if needed
3. **Webhook Not Receiving**: Verify webhook URL and SSL certificate
4. **Message Not Sending**: Check recipient ID and page messaging permissions

### Debug Endpoints

Use Facebook's Graph API Explorer to test endpoints:
- https://developers.facebook.com/tools/explorer/

### Webhook Testing

Use Facebook's Webhook Testing tool:
- https://developers.facebook.com/tools/webhooks/

## Security Considerations

1. **Secure Storage**: Store tokens securely, never in plain text
2. **HTTPS Only**: All webhook endpoints must use HTTPS
3. **Signature Verification**: Always verify webhook signatures
4. **Token Rotation**: Implement token refresh mechanisms
5. **Access Control**: Limit integration access to authorized users

This comprehensive Facebook integration enables businesses to:
- Manage their Facebook presence effectively
- Provide excellent customer service via Messenger
- Share engaging content automatically
- Track and respond to social interactions
- Maintain professional communication standards

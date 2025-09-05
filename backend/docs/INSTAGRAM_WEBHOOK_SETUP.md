# Instagram Webhook Setup Guide

This guide will help you set up Instagram webhooks for your Seafrika application to receive real-time notifications about Instagram activities.

## Prerequisites

1. **Facebook Developer Account**: You need a Facebook Developer account
2. **Facebook App**: Create a Facebook app with Instagram Basic Display API
3. **Instagram Business Account**: The Instagram account must be a Business account
4. **HTTPS Endpoint**: Your webhook endpoint must be accessible via HTTPS

## Step 1: Create Facebook App

1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Click "Create App" and select "Business" type
3. Fill in your app details
4. Add "Instagram Basic Display" product to your app

## Step 2: Configure Instagram Basic Display

1. In your Facebook app dashboard, go to Instagram Basic Display
2. Create a new Instagram App
3. Add your Instagram Business account
4. Note down your:
   - App ID
   - App Secret
   - Instagram App ID

## Step 3: Configure Environment Variables

Add these variables to your `.env` file:

```bash
# Instagram Webhook Configuration
INSTAGRAM_APP_ID=your-instagram-app-id
INSTAGRAM_APP_SECRET=your-instagram-app-secret
INSTAGRAM_VERIFY_TOKEN=your-custom-verify-token
INSTAGRAM_ACCESS_TOKEN=your-instagram-access-token

# Facebook App Configuration
FACEBOOK_APP_ID=your-facebook-app-id
FACEBOOK_APP_SECRET=your-facebook-app-secret
```

## Step 4: Deploy Your Application

Deploy your NestJS application to a server with HTTPS support. Popular options:
- Google Cloud Functions (recommended for this setup)
- Heroku
- AWS Lambda
- Your own server with SSL certificate

## Step 5: Set Up Webhook Subscription

### Using Facebook Graph API Explorer

1. Go to [Graph API Explorer](https://developers.facebook.com/tools/explorer/)
2. Select your app and get a User Access Token with `instagram_basic` scope
3. Make a POST request to subscribe to webhooks:

```
POST /{instagram-user-id}/subscribed_apps
```

### Using cURL

```bash
curl -X POST \
  "https://graph.facebook.com/v18.0/{INSTAGRAM_USER_ID}/subscribed_apps" \
  -d "access_token={ACCESS_TOKEN}"
```

## Step 6: Configure Webhook Endpoint

1. In Facebook App Dashboard, go to Instagram Basic Display
2. Navigate to Webhooks section
3. Add webhook URL: `https://your-domain.com/api/webhooks/instagram`
4. Enter your verify token (same as `INSTAGRAM_VERIFY_TOKEN`)
5. Subscribe to desired fields:
   - `media` - New posts, media updates
   - `comments` - New comments on your media
   - `mentions` - When your account is mentioned
   - `story_insights` - Story performance data

## Available Webhook Endpoints

### Main Webhook Endpoints
- **GET** `/api/webhooks/instagram` - Webhook verification
- **POST** `/api/webhooks/instagram` - Receive webhook notifications
- **GET** `/api/webhooks/instagram/test` - Test endpoint

### Management Endpoints
- **GET** `/api/webhooks/management/instagram/events/{accountId}` - Get webhook events
- **GET** `/api/webhooks/management/instagram/media/{accountId}` - Get media events
- **GET** `/api/webhooks/management/status` - Get webhook service status

## Webhook Event Types

### Media Events
Triggered when:
- New post is published
- Post is updated
- Post is deleted

### Comment Events
Triggered when:
- New comment on your media
- Comment is updated
- Comment is deleted

### Mention Events
Triggered when:
- Your account is mentioned in posts
- Your account is mentioned in comments
- Your account is mentioned in stories

### Story Insights
Triggered when:
- Story performance data is available
- Story insights are updated

## Data Storage

All webhook events are automatically stored in Firestore collections:
- `instagram_webhook_events` - Raw webhook events
- `instagram_media_events` - Media-related events
- `instagram_comment_events` - Comment-related events
- `instagram_mention_events` - Mention-related events
- `instagram_story_insights` - Story insights data

## Testing Your Webhook

1. **Test endpoint**: Visit `https://your-domain.com/api/webhooks/instagram/test`
2. **Manual verification**: Use Facebook's webhook testing tool
3. **Trigger events**: Post on Instagram and check if events are received

## Security Features

- **Signature Verification**: All webhooks are verified using HMAC-SHA256
- **Token Verification**: Verify token prevents unauthorized subscriptions
- **HTTPS Required**: All webhook endpoints require HTTPS
- **Rate Limiting**: Built-in protection against spam

## Troubleshooting

### Common Issues

1. **Webhook verification fails**
   - Check your verify token matches in both Facebook and your app
   - Ensure your endpoint returns the challenge exactly as received

2. **Signature verification fails**
   - Verify your app secret is correct
   - Ensure raw body is passed to signature verification

3. **No events received**
   - Check your Instagram account is a Business account
   - Verify webhook subscription is active
   - Test with a simple post

### Debug Endpoints

- **GET** `/api/webhooks/management/status` - Check service status
- **GET** `/api/docs` - API documentation
- Check application logs for detailed error information

## Example Usage

### Get Recent Instagram Events
```javascript
const response = await axios.get(
  'https://your-api.com/api/webhooks/management/instagram/events/INSTAGRAM_ACCOUNT_ID'
);
```

### Get Media Events
```javascript
const response = await axios.get(
  'https://your-api.com/api/webhooks/management/instagram/media/INSTAGRAM_ACCOUNT_ID?limit=20'
);
```

## Next Steps

1. Set up additional webhook subscriptions for other platforms (Facebook, TikTok)
2. Implement business logic for processing different event types
3. Create notification system for important events
4. Set up analytics dashboard for social media insights

For more information, visit the [Instagram Basic Display API documentation](https://developers.facebook.com/docs/instagram-basic-display-api/).

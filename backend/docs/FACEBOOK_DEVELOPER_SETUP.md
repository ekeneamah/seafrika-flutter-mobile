# Facebook Developer Configuration for Instagram Webhooks

This guide provides step-by-step instructions to configure Facebook Developer settings for Instagram webhooks in your Seafrika application.

## Prerequisites

- Facebook account
- Instagram Business account
- Your backend deployed to an HTTPS endpoint

## Step 1: Create Facebook App

### 1.1 Access Facebook Developer Console
1. Go to [Facebook for Developers](https://developers.facebook.com/)
2. Click "My Apps" in the top navigation
3. Click "Create App"

### 1.2 Choose App Type
1. Select **"Business"** as your app type
2. Click "Next"

### 1.3 App Details
Fill in the following information:
- **App Name**: `Seafrika Instagram Integration`
- **App Contact Email**: Your business email
- **Business Account**: Select or create a business account
- Click "Create App"

## Step 2: Add Instagram Basic Display Product

### 2.1 Add Product
1. In your app dashboard, scroll to "Add Products to Your App"
2. Find **"Instagram Basic Display"** and click "Set Up"

### 2.2 Basic Settings
1. Go to Instagram Basic Display > Basic Display
2. Note your **Instagram App ID** and **Instagram App Secret**
3. Add these to your environment variables

## Step 3: Configure Instagram App Settings

### 3.1 Client OAuth Settings
Add the following URLs in the Instagram Basic Display settings:

**Valid OAuth Redirect URIs:**
```
https://your-domain.com/auth/instagram/callback
https://localhost:3000/auth/instagram/callback (for development)
```

**Deauthorize Callback URL:**
```
https://your-domain.com/auth/instagram/deauthorize
```

**Data Deletion Request URL:**
```
https://your-domain.com/auth/instagram/delete-data
```

### 3.2 Instagram Testers
1. Go to Instagram Basic Display > Basic Display
2. Click "Add or Remove Instagram Testers"
3. Add Instagram accounts that will test your integration

## Step 4: Set Up Webhooks

### 4.1 Configure Webhook Settings
1. In Instagram Basic Display, go to the **Webhooks** section
2. Click "Subscribe to Object"

### 4.2 Webhook Configuration
Fill in the webhook details:

**Callback URL:**
```
https://your-domain.com/api/webhooks/instagram
```

**Verify Token:**
```
your-custom-verify-token-123
```

**Subscription Fields:**
Select the events you want to receive:
- ☑️ `media` - Posts and media updates
- ☑️ `comments` - Comments on your media
- ☑️ `mentions` - Mentions of your account
- ☑️ `story_insights` - Story performance data

## Step 5: Environment Configuration

### 5.1 Update Your .env File
Add these environment variables to your backend:

```bash
# Facebook App Configuration
FACEBOOK_APP_ID=your-facebook-app-id
FACEBOOK_APP_SECRET=your-facebook-app-secret

# Instagram Configuration
INSTAGRAM_APP_ID=your-instagram-app-id
INSTAGRAM_APP_SECRET=your-instagram-app-secret
INSTAGRAM_VERIFY_TOKEN=your-custom-verify-token-123

# Instagram Access Token (you'll get this after user authorization)
INSTAGRAM_ACCESS_TOKEN=your-instagram-access-token
```

### 5.2 Security Notes
- **Never commit these values to version control**
- Use different tokens for development and production
- Rotate tokens regularly for security

## Step 6: Generate Instagram Access Token

### 6.1 User Authorization
Create an authorization URL for Instagram users:

```
https://api.instagram.com/oauth/authorize
  ?client_id={INSTAGRAM_APP_ID}
  &redirect_uri={REDIRECT_URI}
  &scope=user_profile,user_media
  &response_type=code
```

### 6.2 Exchange Code for Token
After user authorization, exchange the code for an access token:

```bash
curl -X POST \
  'https://api.instagram.com/oauth/access_token' \
  -d 'client_id={INSTAGRAM_APP_ID}' \
  -d 'client_secret={INSTAGRAM_APP_SECRET}' \
  -d 'grant_type=authorization_code' \
  -d 'redirect_uri={REDIRECT_URI}' \
  -d 'code={AUTHORIZATION_CODE}'
```

## Step 7: Test Your Configuration

### 7.1 Verify Webhook Endpoint
Test your webhook endpoint:

```bash
curl "https://your-domain.com/api/webhooks/instagram/test"
```

Expected response:
```json
{
  "status": "ok",
  "message": "Instagram webhook endpoint is working",
  "timestamp": "2025-09-05T13:40:00.000Z"
}
```

### 7.2 Test Webhook Verification
Facebook will call your verification endpoint:

```bash
curl "https://your-domain.com/api/webhooks/instagram?hub.mode=subscribe&hub.challenge=test123&hub.verify_token=your-custom-verify-token-123"
```

Should return: `test123`

## Step 8: Deploy and Subscribe

### 8.1 Deploy Your Backend
Ensure your backend is deployed to an HTTPS endpoint. Recommended platforms:

**Google Cloud Functions (Recommended):**
```bash
cd backend
npm run build
gcloud functions deploy seafrikaApi \
  --runtime=nodejs20 \
  --trigger-http \
  --allow-unauthenticated \
  --source=dist \
  --entry-point=seafrikaApi
```

**Heroku:**
```bash
git push heroku main
```

### 8.2 Subscribe to Webhooks
Use Facebook Graph API to subscribe:

```bash
curl -X POST \
  "https://graph.facebook.com/v18.0/{INSTAGRAM_USER_ID}/subscribed_apps" \
  -d "access_token={INSTAGRAM_ACCESS_TOKEN}"
```

## Step 9: Monitor and Debug

### 9.1 Check Webhook Events
Monitor incoming events:

```bash
curl "https://your-domain.com/api/webhooks/management/status"
```

### 9.2 View Event History
Get recent webhook events:

```bash
curl "https://your-domain.com/api/webhooks/management/instagram/events/{INSTAGRAM_ACCOUNT_ID}"
```

### 9.3 Facebook Webhook Testing
1. Go to Facebook Developer Console
2. Navigate to Webhooks section
3. Use "Test" button to send sample webhooks

## Common Configuration Issues

### Issue 1: Webhook Verification Fails
**Problem:** Facebook can't verify your webhook URL

**Solutions:**
- Ensure your endpoint is accessible via HTTPS
- Check that INSTAGRAM_VERIFY_TOKEN matches exactly
- Verify your endpoint returns the challenge parameter

### Issue 2: Signature Verification Fails
**Problem:** Webhook signature validation fails

**Solutions:**
- Ensure INSTAGRAM_APP_SECRET is correct
- Check that raw request body is used for signature calculation
- Verify HMAC-SHA256 implementation

### Issue 3: No Events Received
**Problem:** Webhooks are not being delivered

**Solutions:**
- Confirm webhook subscription is active
- Check that Instagram account is a Business account
- Verify required permissions are granted

## Testing Checklist

- [ ] Facebook app created and configured
- [ ] Instagram Basic Display product added
- [ ] Webhook URL configured in Facebook
- [ ] Environment variables set correctly
- [ ] Backend deployed to HTTPS endpoint
- [ ] Webhook verification test passes
- [ ] Test Instagram post triggers webhook
- [ ] Events stored in Firestore correctly
- [ ] API documentation accessible

## Next Steps

After successful configuration:

1. **Implement Business Logic**: Process webhook events for your specific needs
2. **Add Error Handling**: Implement retry logic and error notifications
3. **Scale Considerations**: Add rate limiting and queue processing
4. **Analytics Dashboard**: Create insights from webhook data
5. **User Management**: Handle multiple Instagram accounts per business

## Support Resources

- [Instagram Basic Display API Documentation](https://developers.facebook.com/docs/instagram-basic-display-api/)
- [Facebook Webhooks Guide](https://developers.facebook.com/docs/webhooks/)
- [Graph API Explorer](https://developers.facebook.com/tools/explorer/)
- [Facebook App Review Process](https://developers.facebook.com/docs/app-review/)

For technical support, check the application logs and use the debug endpoints provided in your API.

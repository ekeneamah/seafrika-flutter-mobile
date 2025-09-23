# Meta Products Setup Guide for Facebook App

This guide walks you through setting up Meta products (Facebook Login, Instagram Basic Display, Webhooks, Messenger) in the Facebook Developers portal to enable the Meta integration features in your app.

## Prerequisites

- A Facebook account
- A Meta Developer account (register at [developers.facebook.com](https://developers.facebook.com))
- Your app's backend deployed with accessible webhook endpoints

## Step 1: Create a Meta App

1. **Go to Facebook Developers**
   - Visit [developers.facebook.com](https://developers.facebook.com)
   - Click "My Apps" → "Create App"

2. **Choose App Type**
   - Select "Business" (recommended for production apps)
   - Click "Next"

3. **App Details**
   - **App Name**: Enter your app name (e.g., "Seafrika Vendor Platform")
   - **App Contact Email**: Your business email
   - **Business Manager Account**: Select or create one
   - Click "Create App"

4. **Note Your App Credentials**
   - Go to "Settings" → "Basic"
   - Copy your **App ID** and **App Secret** (keep secret safe!)

## Step 2: Add Required Products

### A. Facebook Login

1. **Add Facebook Login Product**
   - In your app dashboard, click "Add Product"
   - Find "Facebook Login" and click "Set Up"

2. **Configure Settings**
   - Go to "Facebook Login" → "Settings"
   - **Valid OAuth Redirect URIs**: Add your redirect URI:
     ```
     https://your-api-domain.com/api/config/facebook/instagram/oauth/redirect
     ```
   - **Deauthorize Callback URL**: (Optional)
     ```
     https://your-api-domain.com/api/config/facebook/deauth
     ```

3. **Quick Start**
   - Select "Web" platform
   - Enter your website URL: `https://your-frontend-domain.com`

### B. Instagram Basic Display

1. **Add Instagram Basic Display**
   - Click "Add Product" → "Instagram Basic Display" → "Set Up"

2. **Configure Settings**
   - Go to "Instagram Basic Display" → "Basic Display"
   - **Valid OAuth Redirect URIs**: Add the same redirect URI:
     ```
     https://your-api-domain.com/api/config/facebook/instagram/oauth/redirect
     ```

3. **Instagram App Review**
   - For production, you'll need to submit for app review
   - Add test users in "Roles" → "Instagram Testers"

### C. Webhooks

1. **Add Webhooks Product**
   - Click "Add Product" → "Webhooks" → "Set Up"

2. **Configure Webhook**
   - **Callback URL**: Your webhook endpoint:
     ```
     https://your-api-domain.com/webhooks/meta
     ```
   - **Verify Token**: Enter a secure token (save this for your backend env vars):
     ```
     your_webhook_verify_token_123
     ```
   - Click "Verify and Save"

3. **Subscribe to Page Events**
   - In Webhooks settings, find "Page" subscription
   - Subscribe to these fields:
     - `feed` (for new posts)
     - `mention` (for page mentions)
     - `messages` (for Messenger)
     - `messaging_postbacks` (for button clicks)
     - `messaging_deliveries` (for delivery confirmations)

### D. Messenger

1. **Add Messenger Product**
   - Click "Add Product" → "Messenger" → "Set Up"

2. **Configure Webhooks**
   - Go to "Messenger" → "Settings"
   - **Callback URL**: Same as above:
     ```
     https://your-api-domain.com/webhooks/meta
     ```
   - **Verify Token**: Same token as above
   - Subscribe to these webhook fields:
     - `messages`
     - `messaging_postbacks`
     - `messaging_deliveries`
     - `messaging_reads`

## Step 3: Configure App Settings

### Basic Settings

1. **Go to Settings → Basic**
2. **App Domains**: Add your domains:
   ```
   your-frontend-domain.com
   your-api-domain.com
   ```
3. **Privacy Policy URL**: `https://your-domain.com/privacy`
4. **Terms of Service URL**: `https://your-domain.com/terms`

### Advanced Settings

1. **Go to Settings → Advanced**
2. **Security Settings**:
   - Enable "Require App Secret for Server API calls"
   - Enable "Client OAuth Login"
   - Enable "Web OAuth Login"

## Step 4: Set App Permissions

### Required Permissions for App Review

For production use, you'll need to request these permissions:

#### Facebook Login & Pages
- `pages_show_list` - List user's pages
- `pages_manage_metadata` - Manage page information
- `pages_manage_posts` - Create and manage posts
- `pages_manage_engagement` - Respond to comments
- `pages_read_engagement` - Read engagement metrics

#### Messenger
- `pages_messaging` - Send and receive messages

#### Instagram
- `instagram_basic` - Basic profile access
- `instagram_content_publish` - Publish content
- `instagram_manage_comments` - Manage comments
- `instagram_manage_messages` - Handle DMs

## Step 5: Environment Configuration

### Backend Environment Variables

Add these to your backend environment:

```bash
# Meta App Configuration
META_APP_ID=your_app_id_here
META_APP_SECRET=your_app_secret_here
META_WEBHOOK_VERIFY_TOKEN=your_webhook_verify_token_123

# Optional: Specify Graph API version
META_GRAPH_API_VERSION=v21.0

# Your domain configuration
FRONTEND_DOMAIN=https://your-frontend-domain.com
API_DOMAIN=https://your-api-domain.com
```

### Frontend Configuration

Update the base URL in your Flutter app:

```dart
// In lib/services/meta_integration_service.dart
static const String baseUrl = 'https://your-api-domain.com/api/config/facebook';
```

## Step 6: Testing Setup

### 1. Add Test Users

1. **Go to Roles → Test Users**
2. **Create Test Users** for Facebook and Instagram
3. **Grant Permissions** to test users for your pages

### 2. Create Test Pages

1. **Create test Facebook Pages** for development
2. **Connect Instagram Business accounts** to test pages
3. **Add test users as page admins**

### 3. Test Integration Flow

1. **Navigate to Meta Integration**:
   ```dart
   // In your app
   Navigator.of(context).pushNamed('/meta-integration');
   ```

2. **Test OAuth Flow**:
   - Tap "Connect All Platforms"
   - Complete OAuth in browser
   - Verify integrations are created

3. **Test Webhooks**:
   - Send a message to your page
   - Check backend logs for webhook events
   - Verify idempotent processing

## Step 7: Production Deployment

### App Review Process

1. **Prepare for Review**
   - Complete app information
   - Add privacy policy and terms
   - Provide detailed use case descriptions

2. **Submit for Review**
   - Go to "App Review" → "Permissions and Features"
   - Request advanced permissions
   - Provide screencast demonstrating functionality

3. **Review Requirements**
   - Explain how you use each permission
   - Show user consent flows
   - Demonstrate data usage

### Go Live

1. **App Modes**
   - Development Mode: Limited to test users
   - Live Mode: Available to all users

2. **Switch to Live**
   - Go to "Settings" → "Basic"
   - Toggle "App Mode" to "Live"
   - Confirm the switch

## Step 8: Monitoring & Maintenance

### Webhook Monitoring

1. **Check Webhook Health**
   - Go to "Webhooks" in your app dashboard
   - Monitor delivery success rates
   - Check for failed deliveries

2. **Debug Failed Webhooks**
   - Use webhook debugger in Facebook Developer Tools
   - Check response codes and timing

### API Usage Monitoring

1. **Monitor Rate Limits**
   - Check "Analytics" → "App Insights"
   - Monitor API call volumes
   - Set up alerts for rate limit approaches

2. **Error Monitoring**
   - Implement logging for API errors
   - Monitor token expiration issues
   - Track user authorization failures

## Navigation to Meta Integration Screen

### Option 1: Through Navigation Drawer

The Meta Integration screen has been added to your app's navigation drawer:

1. **Open the app**
2. **Tap the menu icon** (hamburger menu) in the top-left
3. **Scroll down** and tap "Social Media Integration"
4. **Choose your integration** options

### Option 2: Direct Navigation (for developers)

```dart
// Navigate programmatically
Navigator.of(context).pushNamed('/meta-integration');

// Or using your app router
Navigator.of(context).pushNamed(AppRouter.metaIntegration);
```

### Option 3: Add to Main Tabs (Optional)

You can also add it as a main tab by modifying `main_screen.dart`:

```dart
// Add to _tabs list
const MetaIntegrationScreen(),

// Add to _tabItems
{
  'icon': Icons.share_outlined,
  'activeIcon': Icons.share,
  'label': 'Social',
  'color': AppTheme.secondary,
},
```

## Troubleshooting Common Issues

### OAuth Issues

1. **Invalid Redirect URI**
   - Ensure redirect URI exactly matches Facebook app settings
   - Check for trailing slashes or case sensitivity

2. **Scope Not Granted**
   - User may have denied permissions
   - Check if permissions require app review

3. **Token Exchange Fails**
   - Verify app secret is correct
   - Check authorization code hasn't expired (10 minutes)

### Webhook Issues

1. **Webhook Not Receiving Events**
   - Verify webhook URL is publicly accessible
   - Check HTTPS certificate is valid
   - Ensure webhook verification succeeds

2. **Signature Verification Fails**
   - Check webhook verify token matches
   - Ensure raw body is used for signature calculation
   - Verify HMAC SHA256 implementation

### Permission Issues

1. **Insufficient Permissions**
   - Check granted scopes in user token
   - Verify page access tokens have required permissions
   - Ensure user is admin of Facebook page

2. **App Review Required**
   - Some permissions require app review
   - Submit app for review with proper justification
   - Use test users during development

## Support Resources

- **Meta Developer Documentation**: [developers.facebook.com/docs](https://developers.facebook.com/docs)
- **Graph API Explorer**: [developers.facebook.com/tools/explorer](https://developers.facebook.com/tools/explorer)
- **Webhook Debugger**: [developers.facebook.com/tools/webhooks](https://developers.facebook.com/tools/webhooks)
- **Community Support**: [developers.facebook.com/community](https://developers.facebook.com/community)

## Security Best Practices

1. **App Secret Security**
   - Never expose app secret in client-side code
   - Use environment variables for secrets
   - Rotate secrets regularly

2. **Webhook Security**
   - Always verify webhook signatures
   - Use HTTPS for all webhook endpoints
   - Implement rate limiting

3. **Token Management**
   - Store tokens encrypted
   - Implement token refresh logic
   - Monitor for token expiration

4. **User Data Protection**
   - Follow data minimization principles
   - Implement proper consent flows
   - Comply with privacy regulations (GDPR, CCPA)

This completes the setup guide for Meta products integration. Follow these steps carefully to ensure a smooth integration experience!
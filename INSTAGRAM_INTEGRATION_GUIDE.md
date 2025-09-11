# Instagram Integration Implementation

## Overview

This implementation provides a complete Instagram Business media integration using:

**Backend**: NestJS with Instagram Graph API (via Facebook Pages)  
**Frontend**: Flutter with pagination and real-time updates

## ✅ Recent Fix: Graph API Error Resolution

**Issue Fixed**: Instagram API error `(#100) Tried accessing nonexisting field (media) on node type (User)`

**Root Cause**: Using Facebook User ID instead of Instagram Business Account ID for `/media` calls.

**Solution Implemented**: 
- Auto-discovery of Instagram Business Account ID from connected Facebook Pages
- Use Page tokens for Instagram API calls instead of User tokens
- Caching of discovered Instagram user ID for performance

## Backend Environment Variables

Add these to your `.env` file:

```bash
# Facebook/Instagram Integration
FACEBOOK_APP_ID=your_facebook_app_id
FACEBOOK_APP_SECRET=your_facebook_app_secret
FACEBOOK_VERIFY_TOKEN=your_webhook_verify_token

# Firebase Configuration
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----"

# API Configuration
NODE_ENV=production
JWT_SECRET=your_jwt_secret
```

## API Endpoints

### Get Instagram Media
```
GET /api/integrations/instagram/:integrationId/media
```

**Headers:**
- `Authorization: Bearer <firebase_id_token>`

**Query Parameters:**
- `limit` (optional): Number of items to return (default: 25, max: 50)
- `after` (optional): Pagination cursor for next page

**Response:**
```json
{
  "data": [
    {
      "id": "instagram_media_id",
      "media_type": "IMAGE|VIDEO|CAROUSEL_ALBUM",
      "media_url": "https://...",
      "thumbnail_url": "https://...",
      "caption": "Post caption",
      "timestamp": "2025-09-09T11:07:00+0000",
      "permalink": "https://www.instagram.com/p/.../",
      "like_count": 0,
      "comments_count": 0
    }
  ],
  "paging": {
    "cursors": {
      "after": "cursor_string"
    },
    "next": "https://graph.facebook.com/..."
  }
}
```

### Get Instagram Comments
```
GET /api/integrations/instagram/:integrationId/media/:postId/comments
```

**Headers:**
- `Authorization: Bearer <firebase_id_token>`

**Query Parameters:**
- `limit` (optional): Number of comments to return (default: 25, max: 50)
- `after` (optional): Pagination cursor for next page

**Response:**
```json
{
  "data": [
    {
      "id": "comment_id",
      "text": "Comment text",
      "username": "commenter_username",
      "timestamp": "2025-09-09T11:07:00+0000",
      "like_count": 5,
      "replies_count": 2
    }
  ],
  "paging": {
    "cursors": {
      "after": "cursor_string"
    },
    "next": "https://graph.facebook.com/..."
  }
}
```

### Reply to Instagram Comment
```
POST /api/integrations/instagram/:integrationId/media/:postId/comments/:commentId/replies
```

**Headers:**
- `Authorization: Bearer <firebase_id_token>`
- `Content-Type: application/json`

**Body:**
```json
{
  "message": "Your reply message (max 1000 characters)"
}
```

**Response:**
```json
{
  "id": "reply_id",
  "message": "Reply posted successfully"
}
```

### Create Instagram Post
```
POST /api/integrations/instagram/:integrationId/media
```

**Headers:**
- `Authorization: Bearer <firebase_id_token>`
- `Content-Type: application/json`

**Body (Image Post):**
```json
{
  "image_url": "https://example.com/image.jpg",
  "caption": "Your caption (optional, max 2200 characters)",
  "media_type": "IMAGE"
}
```

**Body (Video Post):**
```json
{
  "video_url": "https://example.com/video.mp4",
  "caption": "Your caption (optional, max 2200 characters)",
  "media_type": "VIDEO"
}
```

**Body (Carousel Post):**
```json
{
  "media_type": "CAROUSEL_ALBUM",
  "caption": "Your caption (optional, max 2200 characters)",
  "children": [
    {
      "media_url": "https://example.com/image1.jpg",
      "media_type": "IMAGE"
    },
    {
      "media_url": "https://example.com/image2.jpg",
      "media_type": "IMAGE"
    }
  ]
}
```

**Response:**
```json
{
  "id": "media_id",
  "permalink": "https://www.instagram.com/p/ABC123/",
  "message": "Post created successfully"
}
```

## Frontend Configuration

### API Configuration
Update `lib/config/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'https://your-backend-url.com';
  // ... other configurations
}
```

### Provider Setup
The integration service is already configured in `service_providers.dart`:

```dart
final integrationServiceProvider = Provider<IntegrationService?>((ref) {
  final businessId = ref.watch(selectedBusinessIdProvider);
  if (businessId == null) return null;
  return IntegrationService(
    firestore: ref.watch(firebaseFirestoreProvider),
    businessId: businessId,
  );
});
```

## Features Implemented

### Backend (NestJS)
- ✅ Secure JWT authentication via Firebase ID tokens
- ✅ Integration validation (platform, status, credentials)
- ✅ Instagram Graph API integration
- ✅ Pagination support with cursors
- ✅ Error handling with appropriate HTTP status codes
- ✅ Rate limiting detection
- ✅ Token expiry validation
- ✅ Instagram comments API endpoint
- ✅ Auto-discovery of Instagram Business Account ID
- ✅ Comment reply functionality
- ✅ Post creation with image/video/carousel support
- ✅ Media container creation and publishing

### Frontend (Flutter)
- ✅ Pull-to-refresh functionality
- ✅ Infinite scroll with "Load More"
- ✅ Loading states and error handling
- ✅ Video thumbnail support
- ✅ Share functionality using system share
- ✅ URL launching for "View on Instagram"
- ✅ Responsive UI with loading indicators
- ✅ Comments viewing in bottom sheet modal
- ✅ User-friendly error messages with help dialog
- ✅ Reply to comments functionality
- ✅ Create new posts with image/video support
- ✅ Floating action button for post creation

## Required Permissions

During Instagram OAuth, ensure these permissions are requested:

**Core Permissions:**
- `pages_show_list`: Access to Facebook Pages
- `pages_manage_metadata`: Manage page information
- `business_management`: Business management
- `instagram_basic`: Basic Instagram access

**Content & Media:**
- `instagram_content_publish`: Publish content
- `instagram_manage_comments`: Manage comments and replies

**Analytics (Optional):**
- `read_insights`: Access to insights data
- `instagram_manage_insights`: Detailed Instagram insights

## Database Structure

Integration documents in Firestore:

```json
{
  "id": "integration_id",
  "businessId": "business_id",
  "platformId": "instagram",
  "status": "active",
  "credentials": {
    "access_token": "EAAG...",
    "user_id": "facebook_user_id",
    "ig_user_id": "instagram_business_user_id",
    "facebook_page_id": "facebook_page_id",
    "facebook_page_name": "Page Name",
    "expires_in": 5183944,
    "created_at": "2025-09-09T10:00:00.000Z"
  },
  "platformName": "Instagram Business",
  "platformIcon": "instagram",
  "createdAt": "2025-09-09T10:00:00.000Z",
  "updatedAt": "2025-09-09T10:00:00.000Z"
}
```

## How the Fix Works

1. **First API Call**: 
   - Service discovers Instagram Business Account ID from user's Facebook Pages
   - Caches `ig_user_id`, `facebook_page_id`, and `facebook_page_name` in Firestore
   - Uses Page token to call `/{ig_user_id}/media`

2. **Subsequent Calls**:
   - Uses cached `ig_user_id` if available
   - Still fetches fresh Page token from `/me/accounts` for security
   - Direct call to `/{ig_user_id}/media` with Page token

3. **Error Handling**:
   - Clear error messages for missing Page Admin permissions
   - Graceful fallback when Instagram account not connected to Page
   - Automatic rediscovery if cached data becomes invalid

## Notes

1. **Authentication**: The frontend uses Firebase ID tokens for backend authentication
2. **Rate Limiting**: Instagram API has rate limits; the backend handles this gracefully
3. **Metrics**: Like/comment counts are set to 0 by default as they require additional API permissions
4. **Video Support**: Videos show thumbnail images when available
5. **Error Handling**: Comprehensive error handling for network, auth, and API errors
6. **Pagination**: Uses Instagram's cursor-based pagination system

## Testing

1. Ensure Firebase Auth is properly configured
2. Test with a valid Instagram Business account integration
3. Verify API endpoints respond correctly
4. Test pagination and refresh functionality
5. Validate error states and loading indicators

## Security Considerations

- All API calls are authenticated with Firebase ID tokens
- Integration validation prevents unauthorized access
- Firestore security rules should restrict integration access to business owners
- Environment variables should be properly secured in production

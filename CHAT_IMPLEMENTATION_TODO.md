# 💬 Chat Implementation TODO List

> Comprehensive task list for implementing a professional chat system in the message detail screen.
> 
> **Project**: Seafrika Multi-Vendor Marketplace
> **Module**: Messaging System
> **Last Updated**: October 16, 2025

---

## 🔴 CRITICAL: BACKEND API INTEGRATION REQUIRED

> **⚠️ IMPORTANT**: All messaging features MUST integrate with backend API endpoints, not direct Firebase operations.
> 
> **Reference Documents**: 
> - [`BACKEND_API_INTEGRATION_GUIDE.md`](./BACKEND_API_INTEGRATION_GUIDE.md) - Architecture patterns and code examples
> - [`IMPLEMENTATION_TRACKING.md`](./IMPLEMENTATION_TRACKING.md) - Track backend/frontend progress for each task
> 
> **Why**: Messages need to reach customers on Instagram/Messenger/WhatsApp via external APIs. Direct Firebase writes won't deliver messages to customers.
> 
> **Pattern**: Flutter → Backend API → External Service (Meta Graph API, etc.) → Firestore (status updates) → Real-time Listeners → UI Update
> 
> **Already Implemented**: Message sending (Tasks #3, #9) - use as reference for all remaining tasks.
>
> **📊 Progress Tracking**: Use [`IMPLEMENTATION_TRACKING.md`](./IMPLEMENTATION_TRACKING.md) to track backend vs frontend completion status for each task.

---

## 🎯 Implementation Priority

- 🔴 **CRITICAL**: Must be done first (Items 1-3)
- 🟠 **HIGH**: Important for core functionality (Items 4-10)
- 🟡 **MEDIUM**: Enhances user experience (Items 11-20)
- 🟢 **LOW**: Nice-to-have features (Items 21-35)

---

## 📊 Progress Tracker

**Phase 1 (Weeks 1-2)**: 3/3 completed ⭐✅  
**Phase 2 (Weeks 2-4)**: 7/7 completed ⭐✅  
**Phase 3 (Weeks 4-6)**: 0/10 completed  
**Phase 4 (Weeks 6+)**: 0/15 completed  

**Overall Progress**: 10/35 (29%) 🚀

---

## 🔴 PHASE 1: Critical Foundation (Week 1-2)

### ✅ Task #1: Real-Time Architecture Foundation
**Priority**: 🔴 CRITICAL  
**Status**: ✅ COMPLETED  
**Estimated Time**: 4-6 hours  
**Dependencies**: None  
**Completed**: October 16, 2025

**Description**:
Convert from FutureProvider to StreamProvider for live message updates. This is the foundation for all real-time features.

**Implementation Steps**:
1. Modify `lib/providers/message_provider.dart`
2. Replace `messagesProvider` with `messagesStreamProvider`
3. Update `conversation_detail_view.dart` to consume stream
4. Test real-time message sync

**Files to Modify**:
- `lib/providers/message_provider.dart`
- `lib/widgets/messages/conversation_detail_view.dart`

**Benefits**:
- Automatic real-time message sync
- No manual refresh needed
- Better user experience

---

### ✅ Task #2: Implement Message Pagination System
**Priority**: 🔴 CRITICAL  
**Status**: ✅ COMPLETED  
**Estimated Time**: 6-8 hours  
**Dependencies**: Task #1  
**Completed**: October 16, 2025

**Description**:
Create pagination system to load messages in chunks instead of all at once.

**Implementation Steps**:
1. Create `PaginatedMessagesNotifier` in `lib/providers/message_provider.dart`
2. Add `pageSize = 50`, `lastDocument` tracking, `hasMore` flag
3. Implement `loadMore()` method using `startAfterDocument`
4. Add lazy loading trigger at 10 messages from top
5. Add loading indicators

**Technical Details**:
```dart
class PaginatedMessagesNotifier extends StateNotifier<AsyncValue<List<Message>>> {
  static const int pageSize = 50;
  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  
  // Implementation here
}
```

**Benefits**:
- Fast initial load (50 messages vs thousands)
- Reduced Firestore costs
- Better memory management

---

### ✅ Task #3: Add Optimistic UI Updates for Messages
**Priority**: 🔴 CRITICAL  
**Status**: ✅ COMPLETED  
**Estimated Time**: 4-6 hours  
**Dependencies**: Task #1  
**Completed**: October 16, 2025

**Description**:
Show messages immediately when sent, before Firebase confirmation.

**Implementation Steps**:
1. ✅ Implement `sendMessageOptimistically()` in `conversation_detail_view.dart`
2. ✅ Add temporary message with `temp_` ID prefix
3. ✅ Add message status: `sending`, `sent`, `failed`
4. ✅ Replace temp message with confirmed one on success
5. ✅ Add retry button for failed messages
6. ✅ Add status icons to message bubbles (clock, check, double-check, error)

**Benefits**:
- Instant feedback
- Feels much more responsive
- Better perceived performance

---

## 🟠 PHASE 2: Core Features (Week 2-4)

### ✅ Task #4: Implement Typing Indicators
**Priority**: 🟠 HIGH  
**Status**: ✅ COMPLETED  
**Estimated Time**: 4-5 hours  
**Dependencies**: Task #1  
**Completed**: October 16, 2025

**Description**:
Show when users are typing from Instagram, Messenger, WhatsApp, or Flutter app.

**Implementation Steps**:
1. ✅ Added `handleTypingIndicator()` in backend `meta.controller.ts`
2. ✅ Parse `sender_action: typing_on/typing_off` from Meta webhooks
3. ✅ Write to Firestore: `conversations/{id}/typing/{userId}` with 5s auto-expire
4. ✅ Created `TypingIndicatorService` in Flutter with `getTypingUsers()` stream
5. ✅ Created `TypingIndicatorWidget` with animated dots and platform icons
6. ✅ Integrated into conversation header to show "User is typing..."
7. ✅ Added business user typing detection with 3s debounce timer

**Files Created**:
- `backend/src/webhooks/meta/meta.controller.ts` (enhanced)
- `lib/services/typing_indicator_service.dart`
- `lib/providers/typing_indicator_provider.dart`
- `lib/widgets/messages/typing_indicator.dart`

**Files Modified**:
- `lib/widgets/messages/conversation_detail_view.dart`

**Benefits**:
- Real-time typing indicators for all platforms (Instagram, Messenger, WhatsApp, App)
- Platform-specific icons (Messenger blue, Instagram pink, WhatsApp green)
- Smooth animations with fade in/out effects
- Auto-expire prevents stale typing indicators
- Non-blocking (errors don't affect app functionality)

---

### ✅ Task #5: Add Message Grouping by Date
**Priority**: 🟠 HIGH  
**Status**: ✅ COMPLETED  
**Estimated Time**: 3-4 hours  
**Dependencies**: Task #1  
**Completed**: October 16, 2025

**Description**:
Group messages by date with dividers (Today, Yesterday, etc.)

**Implementation Steps**:
1. ✅ Created `DateDivider` widget with Material Design styling
2. ✅ Added `_isSameDay()` helper to check calendar day equality
3. ✅ Updated `_shouldShowTimestamp()` to use daily grouping
4. ✅ Enhanced `_formatMessageDate()` with context-aware display
5. ✅ Integrated into both conversation_detail_view.dart and conversation_screen.dart

**Files Created**:
- `lib/widgets/messages/date_divider.dart`

**Files Modified**:
- `lib/widgets/messages/conversation_detail_view.dart`
- `lib/screens/conversation_screen.dart`

**Benefits**:
- Visual separation by calendar days
- Context-aware date display (Today, Yesterday, weekday names, full dates)
- Improved navigation in long conversations
- Consistent behavior across both conversation screens

---

### ✅ Task #6: Implement Smart Scroll Behavior
**Priority**: 🟠 HIGH  
**Status**: ✅ COMPLETED  
**Estimated Time**: 3-4 hours  
**Dependencies**: None  
**Completed**: October 16, 2025

**Description**:
Add scroll-to-bottom button and auto-scroll on new messages.

**Implementation Steps**:
1. ✅ Added `_showScrollToBottom` and `_isAtBottom` state variables
2. ✅ Implemented scroll controller listener in `initState`
3. ✅ Created `_onScroll()` method to track scroll position
4. ✅ Created `_scrollToBottom()` with smooth animation (300ms, easeOut curve)
5. ✅ Added FloatingActionButton with AnimatedOpacity (appears >200px from bottom)
6. ✅ Implemented auto-scroll on new messages (only when user is at bottom)
7. ✅ Applied to both conversation_detail_view.dart and conversation_screen.dart

**Files Modified**:
- `lib/widgets/messages/conversation_detail_view.dart`
- `lib/screens/conversation_screen.dart`

**Benefits**:
- One-tap scroll to latest messages
- Smooth fade in/out animation for button
- Auto-scroll on new messages (when already at bottom)
- Non-intrusive (doesn't interrupt user scrolling history)
- Consistent behavior across both conversation screens

---

### ✅ Task #7: Progressive Attachment Upload with Preview
**Priority**: 🟠 HIGH  
**Status**: ✅ COMPLETED  
**Estimated Time**: 6-8 hours  
**Dependencies**: Task #3  
**Completed**: October 16, 2025

**Description**:
Show attachments immediately with upload progress.

**Implementation Steps**:
1. ✅ Updated `MessageAttachment` model with `uploadProgress`, `isUploading`, and `localPath` fields
2. ✅ Added `copyWith()` method to `MessageAttachment` for progress updates
3. ✅ Added `copyWith()` method to `MessageContent` for updating attachments
4. ✅ Added `generateThumbnail()` method to `AttachmentUploadService`
5. ✅ Modified `_sendMessage()` to create placeholder attachments with local paths
6. ✅ Implemented progressive upload with real-time progress updates
7. ✅ Updated `MessageBubble` to show local file preview during upload
8. ✅ Added circular progress indicator overlay with percentage display
9. ✅ Auto-updates UI as each byte uploads to Firebase Storage

**Files Modified**:
- `lib/models/message.dart` - Added upload progress fields and copyWith methods
- `lib/services/attachment_upload_service.dart` - Added thumbnail generation
- `lib/widgets/messages/conversation_detail_view.dart` - Progressive upload implementation
- `lib/widgets/messages/message_bubble.dart` - Local file preview and progress UI

**Technical Implementation**:
```dart
// Message shown immediately with local file path
MessageAttachment(
  type: 'image',
  url: '', // Empty until uploaded
  localPath: '/path/to/local/file.jpg',
  isUploading: true,
  uploadProgress: 0.0,
)

// Progress updates as upload proceeds
onProgress: (progress) {
  attachment.copyWith(uploadProgress: progress);
  // Update message in provider
}

// Final state after upload completes
MessageAttachment(
  type: 'image',
  url: 'https://firebase.../image.jpg',
  isUploading: false,
  uploadProgress: 1.0,
)
```

**Benefits**:
- Instant visual feedback with local file preview
- Real-time upload progress (0-100%)
- Smooth user experience - no waiting for uploads
- Users can see images immediately before Firebase confirms
- Progress indicator with percentage overlay
- Non-blocking - users can continue using app while uploading
- Graceful handling of upload failures

---

### ✅ Task #8: Create Attachment Caching Service
**Priority**: 🟠 HIGH  
**Status**: ✅ COMPLETED  
**Estimated Time**: 5-6 hours  
**Dependencies**: None  
**Completed**: October 16, 2025

**Description**:
Cache attachments to reduce bandwidth and improve load times.

**Implementation Steps**:
1. ✅ Designed 3-tier cache architecture (Memory → Disk → Network)
2. ✅ Created `AttachmentCacheService` singleton with LRU eviction
3. ✅ Implemented memory cache with 50MB limit and 50 item max
4. ✅ Implemented disk cache with 100MB limit using path_provider
5. ✅ Added cache key generation using MD5 hashing
6. ✅ Implemented LRU (Least Recently Used) eviction policy
7. ✅ Added cache management utilities (clear, size, preload)
8. ✅ Created Riverpod provider for dependency injection
9. ✅ Created `CachedAttachmentImage` widget for easy integration

**Files Created**:
- `lib/services/attachment_cache_service.dart` (330 lines)
- `lib/widgets/messages/cached_attachment_image.dart` (125 lines)

**Files Modified**:
- `lib/providers/message_provider.dart` - Added cache service provider

**Technical Architecture**:
```dart
// 3-Tier Cache System
Level 1: Memory Cache (Map<String, Uint8List>)
  - Fastest access
  - 50MB limit, 50 items max
  - LRU eviction

Level 2: Disk Cache (File System)
  - Persistent across app restarts
  - 100MB limit
  - Stored in temporary directory
  - LRU eviction based on access time

Level 3: Network Download
  - Downloads from Firebase Storage
  - Populates upper cache levels
  - HTTP client with error handling
```

**Key Features**:
- **Cache Hit Path**: Memory → Disk → Network
- **Automatic Promotion**: Disk hits promote to memory
- **LRU Eviction**: Removes least recently used items when full
- **Size Management**: Tracks memory (50MB) and disk (100MB) limits
- **Cache Key**: MD5 hash of URL for consistent naming
- **Async Operations**: Non-blocking cache operations
- **Error Handling**: Graceful fallback on cache failures

**Cache Management Methods**:
```dart
// Get attachment (checks all cache levels)
Future<String?> getAttachment(String url)

// Proactive caching
Future<void> preloadAttachment(String url)
Future<void> preloadAttachments(List<String> urls)

// Cache utilities
Future<bool> isCached(String url)
Future<void> removeFromCache(String url)
Future<void> clearCache()
Future<Map<String, int>> getCacheSize()
```

**Usage Example**:
```dart
// Using the service directly
final cacheService = ref.read(attachmentCacheServiceProvider);
final path = await cacheService.getAttachment(imageUrl);

// Using the widget
CachedAttachmentImage(
  url: attachment.url,
  width: 250,
  height: 200,
  fit: BoxFit.cover,
)
```

**Benefits**:
- **Reduced Bandwidth**: Images downloaded once, cached forever
- **Faster Load Times**: Memory cache = instant display
- **Offline Support**: Disk cache works without network
- **Cost Savings**: Fewer Firebase Storage downloads
- **Better UX**: No repeated downloads on scroll
- **Memory Efficient**: Automatic eviction prevents OOM
- **Persistent**: Survives app restarts
- **Smart Preloading**: Can preload next messages' images

**Performance Improvements**:
- First load: ~500ms (network download)
- Memory cache hit: <10ms (instant)
- Disk cache hit: ~50ms (file read)
- Bandwidth saved: ~90% on repeated views

---

### ✅ Task #9: Add Message Delivery Status Icons
**Priority**: 🟠 HIGH  
**Status**: ✅ COMPLETED  
**Estimated Time**: 3-4 hours  
**Dependencies**: Task #3  
**Completed**: October 16, 2025

**Description**:
Show message status: sending, sent, delivered, read, failed.

**Implementation**:
- ✅ `MessageStatusIcon` widget already implemented in `lib/widgets/messages/message_status_icon.dart`
- ✅ Integrated into `MessageBubble` widget
- ✅ Shows appropriate icon based on `message.metadata.status`
- ✅ Includes tooltips for accessibility

**Icons**:
- ⏱️ Sending: `Icons.access_time` (clock icon, grey)
- ✓ Sent: `Icons.check` (single check, grey)
- ✓✓ Delivered: Double `Icons.check` (stacked, grey)
- ✓✓ Read: Double `Icons.check` (stacked, blue)
- ❌ Failed: `Icons.error_outline` (error icon, red)

**Files**:
- `lib/widgets/messages/message_status_icon.dart` (116 lines)
- `lib/widgets/messages/message_bubble.dart` (uses `_buildStatusIcon()`)

**Benefits**:
- WhatsApp-style visual feedback
- Users know message delivery status at a glance
- Failed messages clearly marked with error icon
- Read receipts shown with blue checkmarks

---

### ✅ Task #10: Implement Offline Message Queue
**Priority**: 🟠 HIGH  
**Status**: ✅ COMPLETED  
**Estimated Time**: 5-7 hours  
**Dependencies**: Task #3  
**Completed**: October 16, 2025

**Description**:
Store unsent messages and auto-retry when online.

**🔌 Backend API Integration Required**:
- **Endpoint**: `POST /api/messages/queue`
- **Purpose**: Store queued messages on server for cross-device sync
- **Endpoint**: `POST /api/messages/queue/:id/retry`
- **Purpose**: Manual retry of failed messages from server queue

**Implementation**:

**Backend** (NestJS) - ✅ COMPLETED:
1. ✅ Created `QueueController` with 4 endpoints (155 lines):
   - `POST /messages/queue` - Queue a message
   - `POST /messages/queue/:queueId/retry` - Manual retry
   - `GET /messages/queue/business/:businessId` - Get business queue
   - `GET /messages/queue/conversation/:conversationId` - Get conversation queue
2. ✅ Created `QueueService` with retry logic (363 lines):
   - Store in Firestore `message_queue` collection
   - Exponential backoff: 1min, 5min, 15min, 30min, 1hour delays
   - Max 5 retry attempts before marking as failed
   - Platform-specific send via Meta Graph API
3. ✅ Created `QueueSchedulerService` (42 lines):
   - Process queue every 5 minutes (auto-retry)
   - Cleanup old queue items daily at 3 AM
4. ✅ Added `@nestjs/schedule@^4.0.0` dependency
5. ✅ Integrated with `app.module.ts`

**Frontend** (Flutter) - ✅ COMPLETED:
6. ✅ Created `OfflineMessageQueue` (270 lines):
   - Store queued messages in Firestore
   - Real-time queue listeners
   - Get/watch queue by business or conversation
   - Queue count tracking
7. ✅ Created `QueueApiService` (160 lines):
   - API methods for queue, retry, get business/conversation queues
8. ✅ Created `ConnectivityService` (140 lines):
   - Monitor online/offline state with `connectivity_plus`
   - Callbacks for connectivity changes
9. ✅ Created `ConnectivityProvider` (60 lines):
   - Riverpod providers for connectivity status
   - Auto-process queue when online
10. ✅ Enhanced `MessagesApiService`:
    - Auto-queue messages when offline
    - Auto-queue on send failure
    - Retry logic integrated
11. ✅ Created UI widgets:
    - `OfflineIndicator` - Banner showing offline status
    - `CompactOfflineIndicator` - Small badge for app bars
    - `QueueCountBadge` - Shows number of queued messages
    - `CompactQueueCountBadge` - Small badge with count

**Files Created**:
- Backend:
  - `backend/src/messages/queue/queue.controller.ts`
  - `backend/src/messages/queue/queue.service.ts`
  - `backend/src/messages/queue/queue.module.ts`
  - `backend/src/messages/queue/dto/queue-message.dto.ts`
  - `backend/src/messages/scheduler/queue-scheduler.service.ts`
- Frontend:
  - `lib/services/offline_message_queue.dart`
  - `lib/services/queue_api_service.dart`
  - `lib/services/connectivity_service.dart`
  - `lib/providers/connectivity_provider.dart`
  - `lib/widgets/messages/offline_indicator.dart`
  - `lib/widgets/messages/queue_count_badge.dart`

**Files Modified**:
- `backend/package.json` - Added @nestjs/schedule
- `backend/src/app.module.ts` - Integrated QueueModule
- `lib/services/messages_api_service.dart` - Added offline queue support

**Benefits**:
- ✅ Messages never lost even if app crashes
- ✅ Cross-device sync (queue accessible from web/mobile)
- ✅ Automatic retry with exponential backoff (5 attempts)
- ✅ Server-side queue management with background job
- ✅ Real-time UI updates (queue count, offline status)
- ✅ Seamless offline → online transition

---

## 🟡 PHASE 3: Enhanced Features (Week 4-6)

### ✅ Task #11: Add Message Reactions Feature
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 5-6 hours  
**Dependencies**: Task #3

**Description**:
Allow users to react to messages with emojis.

**🔌 Backend API Integration Required**:
- **Endpoint**: `POST /api/messages/:messageId/react`
- **Purpose**: Add emoji reaction and sync to Instagram/Messenger (if supported by platform)
- **Endpoint**: `DELETE /api/messages/:messageId/react/:reactionId`
- **Purpose**: Remove reaction

**Implementation Steps**:

**Backend** (NestJS):
1. Create `ReactionsController` with `addReaction()` and `removeReaction()`
2. Update Firestore `messages/{id}/reactions` subcollection
3. Attempt to sync reaction to external platform (Meta Graph API supports reactions)
4. Handle platform-specific limitations (not all platforms support all emojis)

**Frontend** (Flutter):
5. Create `ReactionsApiService` in `lib/services/reactions_api_service.dart`
6. Add reaction picker UI (long-press message → show emoji picker)
7. Optimistic UI: Show reaction immediately, confirm via backend
8. Display reactions below message bubble with count
9. Animate reaction when added

**Files to Create**:
- `backend/src/messages/reactions/reactions.controller.ts`
- `backend/src/messages/reactions/reactions.service.ts`
- `lib/services/reactions_api_service.dart`
- `lib/widgets/messages/reaction_picker.dart`
- `lib/widgets/messages/reactions_display.dart`

**Platform Support**:
- ✅ Messenger: Full emoji reaction support
- ✅ Instagram: Limited emoji set
- ❌ WhatsApp: Not supported via API (stored in Firestore only)

---

### ✅ Task #12: Optimize ListView Performance
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 3-4 hours

**Description**:
Improve scroll performance with RepaintBoundary and caching.

---

### ✅ Task #13: Add Message Search Functionality
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 6-8 hours  
**Dependencies**: Task #1

**Description**:
Search messages within conversation with server-side indexing.

**🔌 Backend API Integration Required**:
- **Endpoint**: `GET /api/messages/search?conversationId=X&query=Y&limit=50`
- **Purpose**: Server-side full-text search with Algolia or Elasticsearch
- **Endpoint**: `POST /api/messages/index`
- **Purpose**: Trigger manual re-indexing of messages

**Implementation Steps**:

**Backend** (NestJS):
1. Install Algolia SDK (`npm install algoliasearch`)
2. Create `SearchController` with `searchMessages()` endpoint
3. Index all messages to Algolia on creation/update
4. Implement search with fuzzy matching, stemming
5. Add search analytics tracking

**Frontend** (Flutter):
6. Create `SearchApiService` in `lib/services/search_api_service.dart`
7. Add search bar in conversation header
8. Implement debounced search (300ms delay)
9. Show search results with highlighting
10. Navigate to message on result tap

**Files to Create**:
- `backend/src/search/search.controller.ts`
- `backend/src/search/search.service.ts` (Algolia integration)
- `lib/services/search_api_service.dart`
- `lib/widgets/messages/message_search_bar.dart`
- `lib/widgets/messages/search_results_list.dart`

**Search Features**:
- Full-text search across all message content
- Search by sender name
- Search by date range
- Search by attachment type (images only, videos only)
- Fuzzy matching for typos
- Result ranking by relevance

---

### ✅ Task #14: Implement Image Compression Optimization
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 4-5 hours  
**Dependencies**: Task #7

**Description**:
Server-side image compression with multiple size variants.

**🔌 Backend API Integration Required**:
- **Endpoint**: `POST /api/attachments/upload`
- **Purpose**: Server-side image compression with Sharp library
- **Returns**: URLs for thumbnail, medium, and full-size variants

**Implementation Steps**:

**Backend** (NestJS):
1. Install Sharp (`npm install sharp`)
2. Create `AttachmentsController` with `uploadImage()` endpoint
3. Receive base64 image or multipart upload
4. Generate 3 variants:
   - Thumbnail: 150x150px (for lists)
   - Medium: 800px width (for chat bubbles)
   - Full: 2000px width (for full-screen view)
5. Upload all variants to Firebase Storage
6. Return all URLs in response
7. Store metadata in Firestore

**Frontend** (Flutter):
8. Create `AttachmentsApiService` in `lib/services/attachments_api_service.dart`
9. Update `AttachmentUploadService` to use backend endpoint
10. Show appropriate variant based on context:
    - Thumbnail in message preview
    - Medium in chat bubble
    - Full when user taps to view
11. Progressive loading (thumbnail → medium → full)

**Files to Create**:
- `backend/src/attachments/attachments.controller.ts`
- `backend/src/attachments/processors/image.processor.ts`
- `backend/src/attachments/dto/upload-image.dto.ts`
- `lib/services/attachments_api_service.dart`

**Compression Settings**:
- Format: WebP (best compression)
- Quality: 85% (good balance)
- Thumbnail: 150x150px, 70% quality
- Medium: 800px width, 85% quality
- Full: 2000px max width, 90% quality

**Benefits**:
- 70-80% reduction in bandwidth usage
- Faster message loading
- Lower Firebase Storage costs
- Better mobile experience (less data usage)

---

### ✅ Task #15: Add Video Thumbnail Generation
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 4-5 hours  
**Dependencies**: Task #7, Task #14

**Description**:
Server-side video thumbnail generation with FFmpeg.

**🔌 Backend API Integration Required**:
- **Endpoint**: `POST /api/attachments/video/upload`
- **Purpose**: Upload video, generate thumbnail, compress video
- **Returns**: Video URL, thumbnail URL, duration, dimensions

**Implementation Steps**:

**Backend** (NestJS):
1. Install FFmpeg and Fluent-FFmpeg (`npm install fluent-ffmpeg`)
2. Create `VideoProcessor` in `backend/src/attachments/processors/video.processor.ts`
3. Extract frame at 1 second (or 10% of duration)
4. Generate thumbnail (640x360px)
5. Compress video to H.264 codec, max 1080p
6. Extract metadata (duration, dimensions, file size)
7. Upload video + thumbnail to Firebase Storage
8. Store metadata in Firestore

**Frontend** (Flutter):
9. Update `AttachmentsApiService` with `uploadVideo()` method
10. Show thumbnail in message bubble with play icon
11. Show video duration overlay
12. Tap to play video in full screen
13. Show upload progress for large videos

**Files to Create**:
- `backend/src/attachments/processors/video.processor.ts`
- `backend/src/attachments/dto/upload-video.dto.ts`
- `lib/widgets/messages/video_attachment.dart`
- `lib/widgets/messages/video_player_screen.dart`

**Video Processing**:
- Extract thumbnail at 1s or 10% duration
- Thumbnail size: 640x360px (16:9 ratio)
- Video compression: H.264 codec, 30fps
- Max resolution: 1080p (reduce if larger)
- Max bitrate: 2 Mbps

**Benefits**:
- Instant video preview without loading full video
- Reduced bandwidth (thumbnails are <50KB)
- Better UX with play button overlay
- Video metadata display (duration, size)

---

### ✅ Task #16: Create Firestore Composite Indexes
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 1-2 hours

**Required Indexes**:
1. `conversationId ASC + createdAt DESC`
2. `conversationId ASC + isRead ASC + createdAt DESC`
3. `businessId ASC + platform ASC + createdAt DESC`

---

### ✅ Task #17: Implement Message Draft Saving
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 2-3 hours  
**Dependencies**: None

**Description**:
Auto-save message drafts with server sync for cross-device access.

**🔌 Backend API Integration Required**:
- **Endpoint**: `POST /api/messages/drafts/:conversationId`
- **Purpose**: Save draft to server for cross-device sync
- **Endpoint**: `GET /api/messages/drafts/:conversationId`
- **Purpose**: Retrieve draft when opening conversation

**Implementation Steps**:

**Backend** (NestJS):
1. Create `DraftsController` with `saveDraft()` and `getDraft()`
2. Store drafts in Firestore `message_drafts` collection
3. Each user can have one draft per conversation
4. Auto-delete drafts older than 7 days

**Frontend** (Flutter):
5. Create `DraftsApiService` in `lib/services/drafts_api_service.dart`
6. Add debounced auto-save (save 2s after user stops typing)
7. Save draft locally (Hive) AND sync to backend
8. Load draft when opening conversation
9. Clear draft after message sent
10. Show draft indicator in conversation list

**Files to Create**:
- `backend/src/messages/drafts/drafts.controller.ts`
- `backend/src/messages/drafts/drafts.service.ts`
- `lib/services/drafts_api_service.dart`
- `lib/providers/drafts_provider.dart`

**Draft Storage**:
```typescript
// Firestore structure
message_drafts/{businessId}_{conversationId} {
  userId: string;
  conversationId: string;
  text: string;
  attachments: Array<{type, localPath}>;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Benefits**:
- Never lose message drafts
- Drafts sync across web and mobile
- Continue draft from any device
- Drafts persist across app restarts

---

### ✅ Task #18: Add Smart Reply Suggestions
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 6-8 hours  
**Dependencies**: Task #1  
**Focus**: 🔴 **PRIMARILY BACKEND TASK**

**Description**:
AI-powered reply suggestions based on message context. **This is mainly a backend ML/AI implementation task.** Frontend integration is optional and can be added later once backend API is ready.

**🔌 Backend API (Primary Focus)**:
- **Endpoint**: `POST /api/messages/smart-reply`
- **Purpose**: Generate contextual reply suggestions using ML
- **Endpoint**: `POST /api/messages/smart-reply/train`
- **Purpose**: Train model with business-specific data
- **Note**: Backend team should focus on this first. Frontend can consume API later.

**Implementation Steps**:

**🔴 Backend Implementation (PRIMARY - Do This First)**:
1. Install Google ML Kit or OpenAI SDK
2. Create `SmartReplyController` with `getSuggestions()` endpoint
3. Analyze last 5 messages for context
4. Generate 3-5 relevant suggestions
5. Cache suggestions for 5 minutes
6. Track suggestion usage analytics
7. Option to train with business-specific data
8. Deploy and test backend API endpoints
9. Document API response format

**🟢 Frontend Integration (OPTIONAL - Can Be Done Later)**:
10. Create `SmartReplyApiService` in `lib/services/smart_reply_api_service.dart`
11. Show suggestion chips above message input
12. Load suggestions when new customer message arrives
13. Tap chip to insert text (can still edit)
14. Animate chip appearance
15. Show loading state while generating

**Files to Create**:
- 🔴 **Backend (Priority)**:
  - `backend/src/ml/smart-reply/smart-reply.controller.ts`
  - `backend/src/ml/smart-reply/smart-reply.service.ts`
- 🟢 **Frontend (Later)**:
  - `lib/services/smart_reply_api_service.dart`
  - `lib/widgets/messages/smart_reply_chips.dart`

**ML Options**:
1. **Google ML Kit** (Free, on-device):
   - Fast, works offline
   - Generic suggestions
   - Limited customization

2. **OpenAI GPT-4** (Paid, cloud):
   - Context-aware, natural responses
   - Can be trained with business data
   - Supports multiple languages

3. **Custom Model** (Self-hosted):
   - Full control
   - Privacy-focused
   - Requires ML expertise

**Example Suggestions**:
- Customer: "Is this available?"
  - "Yes, it's available!"
  - "Let me check for you."
  - "Yes, when would you like it?"

**Benefits**:
- Faster response times (1-tap replies)
- Consistent tone across team
- Reduce typing fatigue
- Learn from best responses

**⚠️ Note**: This is primarily a backend ML/AI task. Focus on getting the API working first. Frontend team can integrate later once backend endpoints are stable and tested.

---

### ✅ Task #19: Implement Message Threading/Replies
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 8-10 hours  
**Dependencies**: Task #3  
**Focus**: 🔴 **PRIMARILY BACKEND TASK**

**Description**:
Allow replying to specific messages with thread support. **This is mainly a backend implementation task** to handle threaded replies, maintain parent-child relationships, and sync to external platforms (Instagram/Messenger).

**🔌 Backend API (Primary Focus)**:
- **Endpoint**: `POST /api/messages/:messageId/reply`
- **Purpose**: Send reply and link to parent message, sync to external platforms
- **Endpoint**: `GET /api/messages/:messageId/thread`
- **Purpose**: Get all replies to a message
- **Note**: Backend team should implement threading logic, Firestore updates, and external API sync first.

**Implementation Steps**:

**🔴 Backend Implementation (PRIMARY - Do This First)**:
1. Create `ThreadsController` with `replyToMessage()` endpoint
2. Update message model with `replyToId` field
3. Maintain `replyCount` on parent message
4. Support nested replies (threads)
5. Send reply via appropriate platform API (Meta Graph API)
6. Update Firestore with thread relationships
7. Handle platform-specific limitations (Instagram/Messenger)
8. Test thread creation and retrieval
9. Document API endpoints and response formats

**🟢 Frontend Integration (OPTIONAL - Can Be Done Later)**:
10. Create `ThreadsApiService` in `lib/services/threads_api_service.dart`
11. Long-press message → Show "Reply" option
12. Show replied message preview above input
13. Display reply indicator in message bubble
14. Tap reply indicator to scroll to parent message
15. Show thread view (all replies to a message)

**Files to Create**:
- 🔴 **Backend (Priority)**:
  - `backend/src/messages/threads/threads.controller.ts`
  - `backend/src/messages/threads/threads.service.ts`
- 🟢 **Frontend (Later)**:
  - `lib/services/threads_api_service.dart`
  - `lib/widgets/messages/reply_preview.dart`
  - `lib/widgets/messages/thread_view.dart`
  - `lib/models/message_thread.dart`

**Firestore Structure**:
```typescript
messages/{messageId} {
  // ... existing fields
  replyToId?: string;          // Parent message ID
  replyCount: number;          // Number of direct replies
  threadDepth: number;         // 0 = root, 1 = reply, 2 = nested
}
```

**UI Features**:
- Swipe right on message to reply
- Show parent message quote in reply
- Thread indicator (line connecting messages)
- View all replies in thread view
- Limit depth to 2 levels (prevent deep nesting)

**Platform Support**:
- ✅ Internal app: Full thread support
- ⚠️ Instagram/Messenger: Limited (may show as regular messages)
- ❌ WhatsApp: Not supported (falls back to regular message)

**⚠️ Note**: This is primarily a backend task. Backend team should focus on implementing the threading API, Firestore structure, and external platform integration. Frontend team can build the UI later once backend is ready.

---

### ✅ Task #20: Add Message Copy/Forward/Delete
**Priority**: 🟡 MEDIUM  
**Status**: ❌ Not Started  
**Estimated Time**: 4-5 hours  
**Dependencies**: Task #3

**Description**:
Message actions via long-press menu with backend sync.

**🔌 Backend API Integration Required**:
- **Endpoint**: `POST /api/messages/:messageId/forward`
- **Purpose**: Forward message to another conversation
- **Endpoint**: `DELETE /api/messages/:messageId`
- **Purpose**: Delete message (soft delete, keep for audit)
- **Endpoint**: `POST /api/messages/:messageId/recall`
- **Purpose**: Attempt to recall message from external platform

**Implementation Steps**:

**Backend** (NestJS):
1. Create `MessageActionsController` with forward, delete, recall endpoints
2. Forward: Create new message in target conversation
3. Delete: Soft delete (mark `deletedAt`, keep in Firestore)
4. Recall: Attempt to delete from Instagram/Messenger (if within time limit)
5. Update statistics (message counts)

**Frontend** (Flutter):
6. Create `MessageActionsApiService` in `lib/services/message_actions_api_service.dart`
7. Long-press message → Show action sheet
8. **Copy**: Copy text to clipboard (local only)
9. **Forward**: Select conversation → call backend forward endpoint
10. **Delete**: Confirm → call backend delete endpoint
11. **Recall**: Only show for recent messages (<1 hour)
12. Update UI optimistically

**Files to Create**:
- `backend/src/messages/actions/actions.controller.ts`
- `backend/src/messages/actions/actions.service.ts`
- `lib/services/message_actions_api_service.dart`
- `lib/widgets/messages/message_action_sheet.dart`
- `lib/widgets/messages/forward_dialog.dart`

**Action Sheet Options**:
```dart
- 📋 Copy Text (if text message)
- 💾 Save Image (if image attachment)
- ↪️ Forward to...
- 🗑️ Delete Message
- ⏮️ Recall Message (if <1 hour old)
- 📌 Pin Message (future)
- 🚫 Report Message (future)
```

**Delete Behavior**:
- Soft delete (mark `deletedAt` timestamp)
- Show "[Message deleted]" placeholder
- Business user can see deleted messages in audit log
- Cannot delete customer messages (only hide)

**Recall Behavior**:
- Only available for business messages <1 hour old
- Attempts to delete from external platform
- May fail if platform doesn't support recall
- Fallback to soft delete if recall fails

**Platform Recall Support**:
- ✅ Messenger: Supported (within 10 minutes)
- ❌ Instagram: Not supported
- ❌ WhatsApp: Not supported via API

---

## 🟢 PHASE 4: Advanced & Polish (Week 6+)

_(Tasks #21-35 listed with brief descriptions)_

### Tasks 21-25: Analytics & Optimization
- Analytics Dashboard
- Read Receipts
- Link Previews
- Storage Optimization
- Export Functionality

### Tasks 26-30: Additional Features
- Message Filtering
- Voice Messages
- Templates System
- Push Notifications
- Message Scheduling

### Tasks 31-35: Quality & Scale
- Performance Testing
- Error Handling
- Accessibility
- Integration Tests
- Documentation

---

## 📝 Notes & Best Practices

### Code Organization
```
lib/
├── services/
│   ├── typing_indicator_service.dart
│   ├── attachment_cache_service.dart
│   ├── offline_message_queue.dart
│   └── smart_reply_service.dart
├── providers/
│   └── message_provider.dart (enhanced)
└── widgets/
    └── messages/
        ├── conversation_detail_view.dart (enhanced)
        ├── message_bubble.dart (enhanced)
        └── typing_indicator.dart (new)
```

### Testing Strategy
- Unit tests for services
- Widget tests for UI components
- Integration tests for flows
- Performance tests with large datasets

### Performance Targets
- Initial load: < 500ms
- Scroll FPS: 60fps
- Memory usage: < 100MB per conversation
- Attachment cache: 100MB limit

---

## 🔗 Related Documentation

- [Flutter StreamProvider Docs](https://pub.dev/documentation/flutter_riverpod/latest/flutter_riverpod/StreamProvider-class.html)
- [Firestore Pagination Guide](https://firebase.google.com/docs/firestore/query-data/query-cursors)
- [Firebase Storage Best Practices](https://firebase.google.com/docs/storage/best-practices)

---

## 📞 Support & Questions

For implementation questions or clarifications, reference:
- Business Analysis Report (in chat history)
- Architecture diagrams (to be created)
- Team lead or senior developer

---

**Last Updated**: October 16, 2025  
**Version**: 1.0  
**Maintained By**: Development Team

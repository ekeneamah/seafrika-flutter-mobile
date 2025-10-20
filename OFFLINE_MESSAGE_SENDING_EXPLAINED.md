# 📨 Message Sending Flow: Offline-First Implementation Analysis

## Current Implementation Status

### ✅ What's Already Implemented (Task #10 - Offline Message Queue)

The app **already has a robust offline-first message sending system** implemented in **Task #10** (completed October 16, 2025). Here's how it currently works:

---

## 🔄 Complete Message Sending Flow

### When User Taps "Send" Button

#### **Phase 1: Optimistic UI Update** (Instant)
```dart
// File: lib/widgets/messages/conversation_detail_view.dart
// Lines: ~1430-1520

Future<void> _sendMessage() async {
  final text = _messageController.text.trim();
  
  // 1. Generate temporary ID for optimistic message
  final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
  
  // 2. Create optimistic message (shown immediately in UI)
  final optimisticMessage = Message(
    id: tempId,
    // ... message data
    metadata: MessageMetadata(
      status: MessageStatus.sending, // ⚠️ Shows "sending" indicator
    ),
  );
  
  // 3. Add to UI IMMEDIATELY (user sees it right away)
  ref.read(paginatedMessagesProvider(conversationId).notifier)
     .addMessage(optimisticMessage);
  
  // 4. Clear input field (better UX)
  _messageController.clear();
}
```

**User Experience:** Message appears instantly in chat with "sending" status

---

#### **Phase 2: Local Firestore Write** (Fast - ~50-200ms)
```dart
// File: lib/providers/messages_provider.dart
// Lines: 282-335

Future<void> sendMessage(Message message, {
  required MessagesApiService apiService,
}) async {
  // 1. Write to LOCAL Firestore (works offline!)
  final messageRef = _firestore.collection('messages').doc();
  final batch = _firestore.batch();
  
  batch.set(messageRef, messageData); // Message saved locally
  batch.update(conversationRef, { ... }); // Conversation updated
  batch.update(integrationRef, { ... }); // Stats updated
  
  await batch.commit(); // ✅ Works offline via Firestore offline persistence
}
```

**Offline Behavior:** 
- ✅ Firestore has **offline persistence** enabled by default
- ✅ Local write succeeds even without internet
- ✅ Firestore syncs to cloud when connection restored

---

#### **Phase 3: Backend API Call** (Network-dependent)
```dart
// File: lib/providers/messages_provider.dart
// Lines: 353-365

// Call backend API to send via platform (Messenger/Instagram/WhatsApp)
try {
  final response = await apiService.sendMessage(
    platform: platform,
    integrationId: integrationId,
    messageId: messageId,
    recipientId: recipientId,
    message: message.content.text,
    // ... other params
  );
  
  debugPrint('✅ Message sent via backend API');
} catch (e) {
  // API call failed - update status to 'failed'
  await messageRef.update({
    'metadata.status': 'failed',
  });
  rethrow;
}
```

**This is where the offline queue magic happens! 👇**

---

#### **Phase 4: Offline Queue Logic** (Automatic)
```dart
// File: lib/services/messages_api_service.dart
// Lines: 70-100 (Messenger) and 175-205 (Instagram)

Future<Map<String, dynamic>> sendMessengerMessage({...}) async {
  // 1. Check if device is offline
  final isOnline = await _connectivityService.checkConnectivity();
  
  if (!isOnline) {
    // 🔴 OFFLINE: Queue message for later
    await _queue.queueMessage(
      messageId: messageId,
      conversationId: conversationId,
      businessId: businessId,
      integrationId: integrationId,
      platform: 'messenger',
      recipientId: recipientId,
      message: message,
      reason: 'offline',
    );
    
    return {
      'success': false,
      'queued': true,
      'messageId': messageId,
      'reason': 'Device is offline - message queued for retry',
    };
  }
  
  // 2. Try to send via backend API
  try {
    final url = ApiConfig.getMessengerSendMessage(integrationId);
    final response = await _client.post(Uri.parse(url), ...);
    
    return _handleResponse(response); // ✅ Success!
    
  } catch (e) {
    // 🔴 SEND FAILED: Queue for retry
    await _queue.queueMessage(
      messageId: messageId,
      // ... same params
      reason: 'send_failed: $e',
    );
    
    return {
      'success': false,
      'queued': true,
      'messageId': messageId,
      'reason': 'Send failed - message queued for retry',
      'error': e.toString(),
    };
  }
}
```

**Key Points:**
- ✅ **Offline Detection:** Checks connectivity before attempting send
- ✅ **Automatic Queueing:** Messages queued if offline OR if send fails
- ✅ **No User Intervention:** Happens silently in background

---

## 🗄️ Offline Message Queue Details

### Storage Location
```dart
// File: lib/services/offline_message_queue.dart
// Lines: 10-45

class OfflineMessageQueue {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<String> queueMessage({...}) async {
    final queueRef = _firestore.collection('message_queue').doc();
    
    await queueRef.set({
      'messageId': messageId,
      'conversationId': conversationId,
      'businessId': businessId,
      'status': 'queued',
      'retryCount': 0,
      'maxRetries': 5,
      'nextRetryAt': now.add(Duration(minutes: 1)),
      'createdAt': now,
      // ... other fields
    });
    
    return queueRef.id;
  }
}
```

**Queue Collection:** `message_queue` (Firestore collection)

**Queue Item Fields:**
- `messageId` - Original message ID
- `status` - `queued`, `retrying`, `sent`, `failed`
- `retryCount` - Number of retry attempts (max 5)
- `nextRetryAt` - When to retry next
- `reason` - Why it was queued (`offline`, `send_failed`)

---

## ⚡ Automatic Retry System

### Frontend Auto-Retry (When App Online)
```dart
// File: lib/providers/connectivity_provider.dart
// Lines: 25-50

final connectivityProvider = StreamProvider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

// Auto-process queue when connection restored
ref.listen(connectivityProvider, (previous, next) {
  if (next.value?.isConnected == true && 
      previous?.value?.isConnected == false) {
    // Connection restored! Process queue
    processOfflineQueue();
  }
});
```

**Behavior:**
- ✅ Monitors connectivity changes in real-time
- ✅ Automatically processes queue when connection restored
- ✅ No user action required

---

### Backend Auto-Retry (Scheduled Job)
```ts
// File: backend/src/messages/queue/queue-scheduler.service.ts
// Lines: 10-30

@Injectable()
export class QueueSchedulerService {
  
  // Process queue every 5 minutes
  @Cron('*/5 * * * *')
  async processQueue() {
    const result = await this.queueService.processQueue();
    console.log(`✅ Queue processed: ${result.succeeded} sent, ${result.failed} failed`);
  }
  
  // Cleanup old queue items daily at 3 AM
  @Cron('0 3 * * *')
  async cleanupOldQueue() {
    const deleted = await this.queueService.cleanupOldQueue();
    console.log(`🗑️ Cleaned up ${deleted} old queue items`);
  }
}
```

**Retry Strategy (Exponential Backoff):**
- 1st retry: **1 minute** after queue
- 2nd retry: **5 minutes** after first retry
- 3rd retry: **15 minutes** after second retry
- 4th retry: **30 minutes** after third retry
- 5th retry: **1 hour** after fourth retry
- After 5 failures: **Marked as permanently failed**

---

## 📊 Message Status Lifecycle

```
User Taps Send
    ↓
[SENDING] - Optimistic UI (instant)
    ↓
    ├─ Online & API Success
    │       ↓
    │   [SENT] - ✅ Delivered to platform
    │
    ├─ Offline
    │       ↓
    │   [QUEUED] - 📦 Stored in message_queue
    │       ↓
    │   [Connection Restored]
    │       ↓
    │   [RETRYING] - 🔄 Auto-retry (1min, 5min, 15min, 30min, 1hr)
    │       ↓
    │       ├─ Success → [SENT] ✅
    │       └─ Max retries → [FAILED] ❌
    │
    └─ API Error
            ↓
        [QUEUED] - 📦 Auto-queued for retry
            ↓
        [Same retry flow as offline]
```

---

## 🔍 How Draft Saving Differs from Message Sending

| Feature | **Message Sending** | **Draft Saving (Task #17)** |
|---------|---------------------|------------------------------|
| **Trigger** | User taps "Send" | User types (debounced 2s) |
| **Primary Storage** | Firestore `messages` collection | SharedPreferences + Server API |
| **Offline Handling** | Auto-queue in `message_queue` | Always save to SharedPreferences |
| **Server Sync** | Backend sends to platform (Meta API) | Backend stores in Firestore `message_drafts` |
| **Retry Logic** | Exponential backoff (5 retries) | No retries (save when online) |
| **Cross-Device** | Via Firestore sync | Via server API + local fallback |
| **Persistence** | Permanent (until deleted) | 7-day expiry |
| **UI Indicator** | Status badge (sending/sent/failed) | "Draft:" prefix in list |

---

## 💡 Key Similarities (Both Are Offline-First)

### Message Sending
```dart
// 1. Save locally FIRST (Firestore offline persistence)
await _firestore.collection('messages').doc(messageId).set(messageData);

// 2. Try to send via API
try {
  await apiService.sendMessage(...);
} catch (e) {
  // 3. If fails, queue for retry
  await _queue.queueMessage(...);
}
```

### Draft Saving (Task #17)
```dart
// 1. Save locally FIRST (SharedPreferences)
await _saveLocalDraft(conversationId, draftText);

// 2. Try to sync to server
try {
  await _client.post(draftApiUrl, ...);
} catch (e) {
  // 3. Ignore error (already saved locally)
  // Will sync when connection restored
}
```

**Both patterns ensure:**
- ✅ **Instant feedback** (local save is fast)
- ✅ **Works offline** (no network required)
- ✅ **Auto-sync** (syncs when connection available)
- ✅ **No data loss** (local storage persists)

---

## 🚀 Summary

### Question: "How is message sending handled when offline?"

**Answer:**

1. **Optimistic UI:** Message appears instantly with "sending" status

2. **Local Save:** Saved to Firestore (works offline via persistence)

3. **API Call Attempt:**
   - **If Online:** Sends via backend → Platform API (Messenger/Instagram)
   - **If Offline:** Auto-queued in `message_queue` collection
   - **If API Fails:** Auto-queued for retry

4. **Auto-Retry:**
   - **Frontend:** Processes queue when connection restored
   - **Backend:** Cron job every 5 minutes
   - **Strategy:** Exponential backoff (1min → 5min → 15min → 30min → 1hr)
   - **Max Attempts:** 5 retries, then marked as failed

5. **Status Updates:**
   - `sending` → `sent` (success)
   - `sending` → `queued` → `sent` (delayed success)
   - `sending` → `queued` → `failed` (permanent failure after 5 retries)

**Result:** Users can send messages anytime, anywhere, and the app handles delivery automatically when connection is available.

---

## 📝 Task #17 (Drafts) vs Task #10 (Offline Queue)

### Task #10: Offline Message Queue
- **Purpose:** Ensure messages are delivered even if user is offline
- **Storage:** Firestore `message_queue` collection
- **Retry:** Aggressive (5 retries with exponential backoff)
- **User Visibility:** Status badges (sending/sent/failed)

### Task #17: Message Draft Saving
- **Purpose:** Save work-in-progress messages for later
- **Storage:** SharedPreferences (local) + Firestore `message_drafts` (server)
- **Retry:** None (saves when online, no retries)
- **User Visibility:** "Draft:" prefix in conversation list

**Both implement offline-first patterns but serve different purposes!**

---

## 📚 Related Files

### Message Sending (Task #10)
- `lib/services/messages_api_service.dart` - API calls with offline detection
- `lib/services/offline_message_queue.dart` - Queue management
- `lib/services/connectivity_service.dart` - Network monitoring
- `lib/providers/connectivity_provider.dart` - Auto-process queue
- `backend/src/messages/queue/queue.service.ts` - Backend retry logic
- `backend/src/messages/queue/queue-scheduler.service.ts` - Cron jobs

### Draft Saving (Task #17)
- `lib/services/drafts_api_service.dart` - Dual storage (local + server)
- `lib/widgets/messages/conversation_detail_view.dart` - Auto-save on text change
- `lib/widgets/messages/conversation_list.dart` - Draft indicators
- `backend/src/messages/drafts/drafts.service.ts` - Server storage with expiry

---

## ✅ Conclusion

**The app already has a comprehensive offline-first message sending system** implemented in Task #10 (Offline Message Queue). When a user taps "Send":

1. Message appears **instantly** (optimistic UI)
2. Saved **locally** to Firestore (works offline)
3. **Automatically queued** if offline or API fails
4. **Auto-retried** when connection restored (frontend + backend)
5. **Exponential backoff** retry strategy (up to 5 attempts)

**Task #17 (Drafts) uses a similar pattern:**
- Save locally first (SharedPreferences)
- Sync to server when online
- Load with fallback (server → local)

**Both systems ensure zero data loss and seamless offline/online transitions!** 🎉

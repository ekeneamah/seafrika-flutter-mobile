# 🔌 Backend API Integration Guide

> **Critical Architecture Document**: All messaging features MUST use backend API endpoints, not direct Firebase operations.

**Project**: Seafrika Multi-Vendor Marketplace  
**Module**: Messaging System  
**Created**: October 16, 2025  
**Status**: ✅ ACTIVE ARCHITECTURE PATTERN

---

## 🎯 Architecture Overview

### ❌ OLD PATTERN (DEPRECATED - DO NOT USE)
```
Flutter App → Firebase Firestore (Direct Write)
          → Firebase Storage (Direct Upload)
          ❌ Customer never receives message
          ❌ No API validation
          ❌ No centralized logging
```

### ✅ NEW PATTERN (REQUIRED FOR ALL FEATURES)
```
Flutter App → Backend API (NestJS)
          → Meta Graph API / External Services
          → Firebase Firestore (Status Updates)
          → Real-time Listeners → Flutter UI Update
          ✅ Messages reach customers
          ✅ Centralized validation & error handling
          ✅ Consistent logging & monitoring
```

---

## 📚 Implementation Reference: Message Sending

We've already implemented the complete message sending flow as a reference pattern. **ALL remaining tasks should follow this exact architecture.**

### Backend Implementation (NestJS)

#### 1. Controller Layer (`*.controller.ts`)
```typescript
// Example: messenger.controller.ts
@Post(':integrationId/send')
@ApiOperation({ summary: 'Send message via Messenger' })
async sendMessage(
  @Param('integrationId') integrationId: string,
  @Body() body: SendMessageDto,
  @Headers('authorization') auth: string,
) {
  // 1. Validate auth token
  const userId = await this.validateAuth(auth);
  
  // 2. Validate request body
  if (!body.recipientId || !body.message) {
    throw new BadRequestException('Missing required fields');
  }
  
  // 3. Get integration credentials from Firestore
  const integration = await this.firestoreService.getIntegration(integrationId);
  
  // 4. Call external service (Meta Graph API, etc.)
  const result = await this.facebookService.sendMessage({
    accessToken: integration.accessToken,
    recipientId: body.recipientId,
    message: body.message,
  });
  
  // 5. Update Firestore with success/failure status
  await this.firestoreService.updateMessage(body.messageId, {
    status: 'sent',
    sentAt: new Date(),
    externalId: result.message_id,
  });
  
  // 6. Return response
  return {
    success: true,
    messageId: body.messageId,
    externalId: result.message_id,
  };
}
```

#### 2. Service Layer (`*.service.ts`)
```typescript
// Example: facebook.service.ts
async sendMessage(params: SendMessageParams): Promise<SendMessageResult> {
  const url = `https://graph.facebook.com/v21.0/me/messages`;
  
  const response = await this.httpService.post(url, {
    recipient: { id: params.recipientId },
    message: { text: params.message },
  }, {
    params: { access_token: params.accessToken },
  });
  
  return {
    success: true,
    message_id: response.data.message_id,
    recipient_id: response.data.recipient_id,
  };
}
```

### Frontend Implementation (Flutter)

#### 3. API Configuration (`lib/config/api_config.dart`)
```dart
class ApiConfig {
  static const String baseUrl = 'https://your-api.com/api';
  
  // Add endpoint helper methods
  static String getMessengerSendMessage(String integrationId) =>
      '$baseUrl/integrations/messenger/$integrationId/send';
      
  static String getInstagramSendMessage(String integrationId) =>
      '$baseUrl/integrations/instagram/$integrationId/send-message';
}
```

#### 4. API Service Layer (`lib/services/*_api_service.dart`)
```dart
// Example: messages_api_service.dart
class MessagesApiService {
  final http.Client _client = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<Map<String, dynamic>> sendMessage({
    required String platform,
    required String integrationId,
    required String messageId,
    required String recipientId,
    required String message,
  }) async {
    final url = platform == 'messenger'
        ? ApiConfig.getMessengerSendMessage(integrationId)
        : ApiConfig.getInstagramSendMessage(integrationId);
    
    final headers = await _getHeaders();
    
    final response = await _client.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'messageId': messageId,
        'recipientId': recipientId,
        'message': message,
      }),
    );
    
    return _handleResponse(response);
  }
  
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
  
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('API call failed: ${response.statusCode} - ${response.body}');
  }
}
```

#### 5. Provider Layer (`lib/providers/*_provider.dart`)
```dart
// Create Riverpod provider
final messagesApiServiceProvider = Provider<MessagesApiService>(
  (ref) => MessagesApiService(),
);

// Use in service methods
class MessagesService {
  Future<void> sendMessage(
    Message message, {
    required MessagesApiService apiService,
  }) async {
    // 1. Write to Firestore with status='sending'
    await _firestore.collection('messages').doc(messageId).set({
      ...messageData,
      'status': 'sending',
    });
    
    // 2. Call backend API
    try {
      final response = await apiService.sendMessage(
        platform: platform,
        integrationId: integrationId,
        messageId: messageId,
        recipientId: recipientId,
        message: message.content.text ?? '',
      );
      
      // Backend updates Firestore status to 'sent'
      // Real-time listeners automatically update UI
      
    } catch (e) {
      // Update status to 'failed' on error
      await _firestore.collection('messages').doc(messageId).update({
        'status': 'failed',
        'error': e.toString(),
      });
      rethrow;
    }
  }
}
```

#### 6. UI Layer (Widgets)
```dart
// conversation_detail_view.dart
final messagesService = ref.read(messagesServiceProvider);
final messagesApiService = ref.read(messagesApiServiceProvider);

await messagesService.sendMessage(
  message,
  apiService: messagesApiService,
);
```

---

## 🔧 Required Backend Endpoints for Remaining Tasks

### Task #10: Offline Message Queue
**Endpoint**: `POST /api/messages/queue`
- Store queued messages on server
- Auto-retry on connectivity restore
- Return queue status

### Task #11: Message Reactions
**Endpoint**: `POST /api/messages/:messageId/react`
- Add emoji reaction to message
- Sync to external platform (if supported)
- Update Firestore reactions collection

### Task #13: Message Search
**Endpoint**: `GET /api/messages/search?conversationId=...&query=...`
- Server-side search with Algolia/Elasticsearch
- Return paginated results
- Cache search results

### Task #14: Image Compression
**Endpoint**: `POST /api/attachments/upload`
- Server-side compression with Sharp/ImageMagick
- Generate multiple size variants (thumbnail, medium, full)
- Upload to Firebase Storage
- Return URLs for all variants

### Task #15: Video Thumbnails
**Endpoint**: `POST /api/attachments/video/thumbnail`
- Server-side thumbnail generation with FFmpeg
- Extract frame at specific timestamp
- Upload thumbnail to Firebase Storage
- Return thumbnail URL

### Task #17: Message Drafts
**Endpoint**: `POST /api/messages/drafts/:conversationId`
- Save draft on server (not just locally)
- Sync across devices
- Auto-save with debounce

### Task #18: Smart Reply
**Endpoint**: `POST /api/messages/smart-reply`
- ML-based reply suggestions
- Context-aware responses
- Return array of suggested replies

### Task #19: Message Threading
**Endpoint**: `POST /api/messages/:messageId/reply`
- Create threaded reply
- Update parent message with reply count
- Maintain thread hierarchy

### Task #20: Message Actions
**Endpoints**:
- `POST /api/messages/:messageId/copy`
- `POST /api/messages/:messageId/forward`
- `DELETE /api/messages/:messageId`

### Task #26: Voice Messages
**Endpoint**: `POST /api/attachments/voice`
- Server-side audio transcription
- Convert to optimized format
- Generate waveform visualization
- Upload to Firebase Storage

### Task #27: Templates System
**Endpoints**:
- `GET /api/templates`
- `POST /api/templates`
- `PUT /api/templates/:id`
- `DELETE /api/templates/:id`

### Task #29: Message Scheduling
**Endpoint**: `POST /api/messages/schedule`
- Schedule message for future delivery
- Store in backend queue
- Send at specified time
- Support timezone handling

---

## 🏗️ Backend Project Structure

```
backend/
├── src/
│   ├── integrations/
│   │   ├── messenger/
│   │   │   ├── messenger.controller.ts ✅ (Already implemented)
│   │   │   ├── messenger.service.ts
│   │   │   └── dto/
│   │   │       └── send-message.dto.ts
│   │   ├── instagram/
│   │   │   ├── instagram.controller.ts ✅ (Already implemented)
│   │   │   └── instagram.service.ts
│   │   └── whatsapp/
│   │       ├── whatsapp.controller.ts (TODO)
│   │       └── whatsapp.service.ts
│   ├── messages/
│   │   ├── messages.controller.ts (Create for Task #10+)
│   │   ├── messages.service.ts
│   │   └── dto/
│   ├── attachments/
│   │   ├── attachments.controller.ts (Create for Task #14+)
│   │   ├── attachments.service.ts
│   │   └── processors/
│   │       ├── image.processor.ts
│   │       └── video.processor.ts
│   ├── search/
│   │   ├── search.controller.ts (Create for Task #13)
│   │   └── search.service.ts (Algolia/Elasticsearch)
│   └── common/
│       ├── services/
│       │   ├── firebase.service.ts
│       │   └── firestore.service.ts
│       └── guards/
│           └── auth.guard.ts
```

---

## ✅ Benefits of Backend-First Architecture

### 1. **External API Integration**
- Messages actually reach customers on Instagram/Messenger/WhatsApp
- Centralized credential management
- Rate limiting & retry logic

### 2. **Data Validation**
- Server-side validation prevents bad data
- Type safety with DTOs
- Input sanitization

### 3. **Security**
- API keys never exposed to client
- Token-based authentication
- Request rate limiting

### 4. **Monitoring & Logging**
- Centralized error tracking
- Request/response logging
- Performance metrics

### 5. **Scalability**
- Queue management for background tasks
- Load balancing
- Caching strategies

### 6. **Consistency**
- Single source of truth
- Atomic operations
- Transaction support

### 7. **Future-Proofing**
- Easy to add new platforms
- Version control for APIs
- Backward compatibility

---

## 🚫 What NOT to Do

### ❌ DON'T: Direct Firebase Operations
```dart
// WRONG - Don't do this anymore!
await FirebaseFirestore.instance.collection('messages').add(messageData);
await FirebaseStorage.instance.ref('images/$filename').putFile(file);
```

### ✅ DO: Call Backend API First
```dart
// CORRECT - Always go through backend
final response = await messagesApiService.sendMessage(...);
// Backend handles Firebase updates
```

### ❌ DON'T: Store Sensitive Data Client-Side
```dart
// WRONG
const accessToken = 'EAABwz...'; // Never hardcode
```

### ✅ DO: Let Backend Manage Credentials
```dart
// CORRECT - Backend fetches from Firestore
final response = await apiService.sendMessage(
  integrationId: integrationId, // Backend gets credentials
);
```

---

## 📝 Implementation Checklist for Each Task

When implementing any new feature:

- [ ] **Backend**: Create controller endpoint
- [ ] **Backend**: Implement service logic
- [ ] **Backend**: Add Firebase/Firestore updates
- [ ] **Backend**: Add error handling & logging
- [ ] **Backend**: Test endpoint with Postman/Insomnia
- [ ] **Frontend**: Add endpoint to `ApiConfig`
- [ ] **Frontend**: Create API service class
- [ ] **Frontend**: Add Riverpod provider
- [ ] **Frontend**: Update business logic to use API
- [ ] **Frontend**: Update UI to call service with provider
- [ ] **Testing**: End-to-end test (Flutter → Backend → External → Firebase → Flutter)

---

## 🔍 Testing Strategy

### Backend Testing
```bash
# Unit tests
npm run test

# Integration tests
npm run test:e2e

# Manual testing
curl -X POST http://localhost:3000/api/integrations/messenger/123/send \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"messageId":"msg1","recipientId":"123","message":"Test"}'
```

### Frontend Testing
```dart
// Widget test
testWidgets('Send message calls API service', (tester) async {
  final mockApiService = MockMessagesApiService();
  when(mockApiService.sendMessage(...)).thenAnswer((_) async => {...});
  
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        messagesApiServiceProvider.overrideWithValue(mockApiService),
      ],
      child: ConversationDetailView(...),
    ),
  );
  
  // Tap send button
  await tester.tap(find.byIcon(Icons.send));
  await tester.pumpAndSettle();
  
  // Verify API service was called
  verify(mockApiService.sendMessage(...)).called(1);
});
```

---

## 📚 Related Documentation

- [NestJS Controllers](https://docs.nestjs.com/controllers)
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [Riverpod Providers](https://riverpod.dev/docs/concepts/providers)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Meta Graph API](https://developers.facebook.com/docs/graph-api)

---

## 🆘 Common Issues & Solutions

### Issue: "API call returns 401 Unauthorized"
**Solution**: Check auth token is being sent in headers
```dart
final token = await _storage.read(key: 'auth_token');
headers['Authorization'] = 'Bearer $token';
```

### Issue: "Message sent but customer doesn't receive"
**Solution**: Check backend logs for external API errors. Verify access token is valid.

### Issue: "Firestore status not updating"
**Solution**: Ensure backend is updating Firestore after external API call succeeds.

### Issue: "Real-time listener not picking up changes"
**Solution**: Check Firestore rules allow read access. Verify listener is subscribed to correct collection/document.

---

## 🎓 Training Resources

### For Backend Developers
1. Review `messenger.controller.ts` and `instagram.controller.ts`
2. Understand the flow: Controller → Service → External API → Firestore
3. Follow clean architecture principles
4. Use dependency injection for services

### For Frontend Developers
1. Review `messages_api_service.dart`
2. Understand the flow: Widget → Provider → Service → API
3. Follow existing patterns (see `TikTokService` for reference)
4. Always handle errors gracefully

---

**Remember**: If a feature involves data that needs to reach external platforms (Instagram, Messenger, WhatsApp) or requires server-side processing (image compression, ML, etc.), it **MUST** go through the backend API. No exceptions!

---

**Last Updated**: October 16, 2025  
**Maintained By**: Development Team  
**Status**: ✅ ACTIVE ARCHITECTURE STANDARD

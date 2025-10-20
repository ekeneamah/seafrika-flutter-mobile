# 🤖 Task #18: Smart Reply Suggestions - Complete Overview

## 📋 Basic Information

- **Task ID**: #18
- **Priority**: 🟡 MEDIUM
- **Status**: ❌ Not Started
- **Estimated Time**: 6-8 hours
- **Dependencies**: Task #1 (Basic Chat UI)
- **Focus**: 🔴 **PRIMARILY BACKEND TASK** (AI/ML Implementation)

---

## 🎯 Description

**AI-powered reply suggestions based on message context.**

This feature generates contextual, one-tap reply suggestions to help users respond faster to customer messages. The system analyzes recent conversation history and suggests 3-5 relevant responses that users can send with a single tap.

**Key Point:** This is **mainly a backend ML/AI implementation task**. Frontend integration is optional and can be added later once the backend API is ready and tested.

---

## 🏗️ Architecture Overview

### Backend (Primary Focus) 🔴
- **Language**: TypeScript (NestJS)
- **ML/AI**: Google ML Kit, OpenAI GPT-4, or Custom Model
- **Storage**: Firestore (cache suggestions, analytics)
- **Processing**: Analyze last 5 messages for context
- **Output**: 3-5 contextual reply suggestions

### Frontend (Optional - Later) 🟢
- **Language**: Dart (Flutter)
- **UI**: Chip widgets above message input
- **Integration**: REST API calls to backend
- **UX**: One-tap to send suggestion (can edit before sending)

---

## 🔌 Backend API Endpoints

### 1. Generate Smart Replies
```typescript
POST /api/messages/smart-reply

Request Body:
{
  "conversationId": "string",
  "businessId": "string",
  "integrationId": "string",
  "lastMessages": [
    {
      "id": "msg123",
      "text": "Is this available?",
      "sender": "customer",
      "timestamp": "2024-10-19T10:30:00Z"
    },
    // ... up to 5 recent messages
  ],
  "platform": "messenger" | "instagram" | "whatsapp"
}

Response:
{
  "suggestions": [
    {
      "id": "sugg1",
      "text": "Yes, it's available!",
      "confidence": 0.95,
      "type": "affirmative"
    },
    {
      "id": "sugg2",
      "text": "Let me check for you.",
      "confidence": 0.88,
      "type": "checking"
    },
    {
      "id": "sugg3",
      "text": "Yes, when would you like it?",
      "confidence": 0.82,
      "type": "follow_up"
    }
  ],
  "cacheExpiry": "2024-10-19T10:35:00Z", // 5 minutes
  "model": "gpt-4" | "ml-kit" | "custom"
}
```

### 2. Train Model (Optional)
```typescript
POST /api/messages/smart-reply/train

Request Body:
{
  "businessId": "string",
  "trainingData": [
    {
      "customerMessage": "How much is this?",
      "agentReply": "It's $49.99. Would you like to order?"
    },
    // ... more examples
  ]
}

Response:
{
  "success": true,
  "trainedSamples": 150,
  "modelVersion": "v2.1",
  "accuracy": 0.91
}
```

### 3. Track Usage Analytics
```typescript
POST /api/messages/smart-reply/analytics

Request Body:
{
  "suggestionId": "sugg1",
  "conversationId": "conv123",
  "action": "used" | "dismissed" | "edited",
  "editedText": "Yes, it's in stock!" // if edited
}

Response:
{
  "success": true
}
```

---

## 🔴 Backend Implementation Steps (Priority)

### Step 1: Install ML/AI SDK
```bash
# Option 1: OpenAI (Recommended)
npm install openai

# Option 2: Google Generative AI
npm install @google/generative-ai

# Option 3: Custom model libraries
npm install tensorflow @tensorflow/tfjs-node
```

### Step 2: Create Smart Reply Service
```typescript
// File: backend/src/ml/smart-reply/smart-reply.service.ts

import { Injectable } from '@nestjs/common';
import { OpenAI } from 'openai';
import { FirestoreService } from '../../firebase/firestore.service';

@Injectable()
export class SmartReplyService {
  private openai: OpenAI;
  private cache: Map<string, any> = new Map();
  
  constructor(private firestoreService: FirestoreService) {
    this.openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });
  }
  
  /**
   * Generate smart reply suggestions based on conversation context
   */
  async generateSuggestions(params: {
    conversationId: string;
    businessId: string;
    lastMessages: Array<{text: string; sender: string}>;
    platform: string;
  }): Promise<{suggestions: Array<{text: string; confidence: number}>}> {
    
    // 1. Check cache first (5-minute TTL)
    const cacheKey = `${params.conversationId}_suggestions`;
    if (this.cache.has(cacheKey)) {
      const cached = this.cache.get(cacheKey);
      if (Date.now() - cached.timestamp < 5 * 60 * 1000) {
        return cached.data;
      }
    }
    
    // 2. Build context from last 5 messages
    const context = params.lastMessages
      .slice(-5)
      .map(m => `${m.sender}: ${m.text}`)
      .join('\n');
    
    // 3. Generate suggestions using GPT-4
    const completion = await this.openai.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content: `You are a helpful customer service assistant. 
                   Generate 3-5 short, professional reply suggestions 
                   based on the conversation context. Keep replies under 
                   50 characters when possible.`
        },
        {
          role: "user",
          content: `Conversation:\n${context}\n\nGenerate reply suggestions:`
        }
      ],
      temperature: 0.7,
      max_tokens: 200,
    });
    
    // 4. Parse suggestions
    const suggestionsText = completion.choices[0].message.content;
    const suggestions = suggestionsText
      .split('\n')
      .filter(s => s.trim())
      .map((text, index) => ({
        id: `sugg_${Date.now()}_${index}`,
        text: text.replace(/^\d+\.\s*/, '').trim(),
        confidence: 0.9 - (index * 0.05),
        type: this.categorizeReply(text),
      }))
      .slice(0, 5);
    
    // 5. Cache suggestions
    this.cache.set(cacheKey, {
      data: { suggestions },
      timestamp: Date.now(),
    });
    
    // 6. Store analytics
    await this.logSuggestionGeneration(params.conversationId, suggestions);
    
    return { suggestions };
  }
  
  /**
   * Categorize reply type
   */
  private categorizeReply(text: string): string {
    const lower = text.toLowerCase();
    if (lower.includes('yes') || lower.includes('available')) return 'affirmative';
    if (lower.includes('check') || lower.includes('let me')) return 'checking';
    if (lower.includes('?')) return 'question';
    if (lower.includes('thank')) return 'gratitude';
    return 'general';
  }
  
  /**
   * Log suggestion generation for analytics
   */
  private async logSuggestionGeneration(
    conversationId: string, 
    suggestions: any[]
  ): Promise<void> {
    await this.firestoreService.createDocument('smart_reply_logs', {
      conversationId,
      suggestions,
      generatedAt: new Date(),
    });
  }
  
  /**
   * Track suggestion usage
   */
  async trackUsage(params: {
    suggestionId: string;
    conversationId: string;
    action: 'used' | 'dismissed' | 'edited';
    editedText?: string;
  }): Promise<void> {
    await this.firestoreService.createDocument('smart_reply_analytics', {
      ...params,
      timestamp: new Date(),
    });
  }
}
```

### Step 3: Create Smart Reply Controller
```typescript
// File: backend/src/ml/smart-reply/smart-reply.controller.ts

import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { SmartReplyService } from './smart-reply.service';

@Controller('messages/smart-reply')
@UseGuards(JwtAuthGuard)
export class SmartReplyController {
  constructor(private readonly smartReplyService: SmartReplyService) {}
  
  @Post()
  async getSuggestions(@Body() body: {
    conversationId: string;
    businessId: string;
    integrationId: string;
    lastMessages: Array<{text: string; sender: string}>;
    platform: string;
  }) {
    return await this.smartReplyService.generateSuggestions(body);
  }
  
  @Post('analytics')
  async trackAnalytics(@Body() body: {
    suggestionId: string;
    conversationId: string;
    action: 'used' | 'dismissed' | 'edited';
    editedText?: string;
  }) {
    await this.smartReplyService.trackUsage(body);
    return { success: true };
  }
}
```

### Step 4: Create Module
```typescript
// File: backend/src/ml/smart-reply/smart-reply.module.ts

import { Module } from '@nestjs/common';
import { SmartReplyController } from './smart-reply.controller';
import { SmartReplyService } from './smart-reply.service';
import { FirebaseModule } from '../../firebase/firebase.module';

@Module({
  imports: [FirebaseModule],
  controllers: [SmartReplyController],
  providers: [SmartReplyService],
  exports: [SmartReplyService],
})
export class SmartReplyModule {}
```

### Step 5: Register Module
```typescript
// File: backend/src/app.module.ts

import { SmartReplyModule } from './ml/smart-reply/smart-reply.module';

@Module({
  imports: [
    // ... existing imports
    SmartReplyModule,
  ],
})
export class AppModule {}
```

---

## 🟢 Frontend Implementation Steps (Optional - Later)

### Step 1: Create Smart Reply API Service
```dart
// File: lib/services/smart_reply_api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class SmartReplyApiService {
  final http.Client _client = http.Client();
  final String baseUrl = 'https://your-api.com';
  
  Future<List<SmartReplySuggestion>> getSuggestions({
    required String conversationId,
    required String businessId,
    required String integrationId,
    required List<Message> lastMessages,
    required String platform,
  }) async {
    final url = Uri.parse('$baseUrl/messages/smart-reply');
    
    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'conversationId': conversationId,
        'businessId': businessId,
        'integrationId': integrationId,
        'lastMessages': lastMessages.map((m) => {
          'text': m.content.text,
          'sender': m.sender.isCustomer ? 'customer' : 'agent',
          'timestamp': m.createdAt.toIso8601String(),
        }).toList(),
        'platform': platform,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['suggestions'] as List)
          .map((s) => SmartReplySuggestion.fromJson(s))
          .toList();
    }
    
    throw Exception('Failed to load suggestions');
  }
  
  Future<void> trackUsage({
    required String suggestionId,
    required String conversationId,
    required String action,
    String? editedText,
  }) async {
    final url = Uri.parse('$baseUrl/messages/smart-reply/analytics');
    
    await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'suggestionId': suggestionId,
        'conversationId': conversationId,
        'action': action,
        if (editedText != null) 'editedText': editedText,
      }),
    );
  }
}

class SmartReplySuggestion {
  final String id;
  final String text;
  final double confidence;
  final String type;
  
  SmartReplySuggestion({
    required this.id,
    required this.text,
    required this.confidence,
    required this.type,
  });
  
  factory SmartReplySuggestion.fromJson(Map<String, dynamic> json) {
    return SmartReplySuggestion(
      id: json['id'],
      text: json['text'],
      confidence: json['confidence'].toDouble(),
      type: json['type'],
    );
  }
}
```

### Step 2: Create Smart Reply Chips Widget
```dart
// File: lib/widgets/messages/smart_reply_chips.dart

import 'package:flutter/material.dart';
import '../../services/smart_reply_api_service.dart';

class SmartReplyChips extends StatefulWidget {
  final String conversationId;
  final Function(String) onReplySelected;
  
  const SmartReplyChips({
    required this.conversationId,
    required this.onReplySelected,
  });
  
  @override
  State<SmartReplyChips> createState() => _SmartReplyChipsState();
}

class _SmartReplyChipsState extends State<SmartReplyChips> {
  final SmartReplyApiService _apiService = SmartReplyApiService();
  List<SmartReplySuggestion> _suggestions = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }
  
  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);
    
    // Load suggestions from API
    // ... implementation
    
    setState(() => _isLoading = false);
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (_suggestions.isEmpty) {
      return SizedBox.shrink();
    }
    
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(suggestion.text),
              onPressed: () {
                widget.onReplySelected(suggestion.text);
                _apiService.trackUsage(
                  suggestionId: suggestion.id,
                  conversationId: widget.conversationId,
                  action: 'used',
                );
              },
            ),
          );
        },
      ),
    );
  }
}
```

---

## 🤖 ML/AI Options Comparison

### Option 1: Google ML Kit (Free, On-Device)
**Pros:**
- ✅ Free (no API costs)
- ✅ Works offline
- ✅ Fast (<100ms)
- ✅ Privacy-friendly (on-device)

**Cons:**
- ❌ Generic suggestions only
- ❌ Limited customization
- ❌ No training support

**Best For:** Basic suggestions, budget-conscious projects

---

### Option 2: OpenAI GPT-4 (Paid, Cloud) ⭐ **RECOMMENDED**
**Pros:**
- ✅ Context-aware responses
- ✅ Natural language understanding
- ✅ Can be fine-tuned with business data
- ✅ Multi-language support
- ✅ Continuous improvements

**Cons:**
- ❌ API costs (~$0.01-0.03 per request)
- ❌ Requires internet
- ❌ ~500-1500ms latency

**Best For:** High-quality, contextual suggestions

**Cost Estimate:**
- 1000 suggestions/day = ~$10-30/month
- Cache reduces costs by 70-80%

---

### Option 3: Custom Model (Self-Hosted)
**Pros:**
- ✅ Full control
- ✅ No API costs (after training)
- ✅ Privacy-focused
- ✅ Unlimited requests

**Cons:**
- ❌ Requires ML expertise
- ❌ Training data needed
- ❌ Infrastructure costs
- ❌ Maintenance overhead

**Best For:** Large-scale deployments, strict privacy requirements

---

## 📊 Example Conversation Flows

### Example 1: Product Availability
```
Customer: "Is this still available?"

Suggestions:
1. ✅ "Yes, it's available!"
2. 🔍 "Let me check for you."
3. ❓ "Yes! When would you like it?"
```

### Example 2: Pricing Inquiry
```
Customer: "How much does this cost?"

Suggestions:
1. 💰 "It's $49.99. Interested?"
2. 📦 "Price depends on quantity. How many?"
3. 🎁 "We have a special offer right now!"
```

### Example 3: Shipping Question
```
Customer: "When will it arrive?"

Suggestions:
1. 📅 "Usually 3-5 business days."
2. 🚚 "Let me check your order status."
3. 🌍 "Where are you located?"
```

---

## 📈 Analytics & Metrics

### Track These Metrics:
- **Usage Rate**: % of suggestions actually used
- **Edit Rate**: % of suggestions edited before sending
- **Dismissal Rate**: % of suggestions ignored
- **Response Time Improvement**: Time saved vs manual typing
- **Customer Satisfaction**: Correlation with CSAT scores

### Firestore Analytics Collection:
```typescript
smart_reply_analytics/{analyticsId} {
  suggestionId: string;
  conversationId: string;
  action: 'used' | 'dismissed' | 'edited';
  editedText?: string;
  timestamp: Date;
  responseTime: number; // ms
}
```

---

## ⚡ Performance Optimization

### 1. Caching Strategy
- Cache suggestions for 5 minutes
- Invalidate on new customer message
- Use Redis for distributed cache (production)

### 2. Rate Limiting
```typescript
// Limit: 10 requests per conversation per minute
@Throttle(10, 60)
@Post('smart-reply')
async getSuggestions() { ... }
```

### 3. Batch Processing
- Generate suggestions for multiple conversations in parallel
- Use background jobs for training

---

## 🔒 Security & Privacy

### 1. Data Privacy
- Don't store sensitive customer data
- Anonymize training data
- Comply with GDPR/CCPA

### 2. API Security
- Require JWT authentication
- Rate limit per business
- Monitor for abuse

### 3. Content Filtering
- Filter inappropriate suggestions
- Block PII (phone numbers, emails)
- Sanitize output

---

## 🎯 Success Criteria

### Backend (Primary)
- ✅ API generates 3-5 relevant suggestions
- ✅ Response time < 2 seconds
- ✅ 80%+ suggestion quality (user feedback)
- ✅ Analytics tracking working
- ✅ Caching reduces API calls by 70%

### Frontend (Optional)
- ✅ Chips appear within 1 second
- ✅ One-tap to send suggestion
- ✅ Smooth animations
- ✅ 30%+ usage rate

---

## 🚀 Deployment Plan

### Phase 1: Backend MVP (Week 1)
1. Implement OpenAI integration
2. Create basic controller + service
3. Test with sample conversations
4. Deploy to staging
5. Monitor costs and performance

### Phase 2: Optimization (Week 2)
1. Add caching layer
2. Implement rate limiting
3. Set up analytics
4. Deploy to production
5. A/B test with 10% of users

### Phase 3: Frontend (Week 3 - Optional)
1. Create API service
2. Build chip UI
3. Integrate with chat view
4. Test user flows
5. Roll out to all users

---

## 📚 Resources

### Documentation
- [OpenAI API Docs](https://platform.openai.com/docs)
- [Google ML Kit](https://developers.google.com/ml-kit)
- [NestJS Modules](https://docs.nestjs.com/modules)

### Code References
- Similar implementation in Gmail Smart Compose
- Slack AI-powered suggestions
- WhatsApp Business Quick Replies

---

## ✅ Conclusion

**Task #18 (Smart Reply Suggestions)** is a **backend-focused AI/ML feature** that generates contextual reply suggestions to speed up customer support.

**Recommended Approach:**
1. ✅ **Start with OpenAI GPT-4** (best quality, easy to implement)
2. ✅ **Implement backend API first** (controller + service)
3. ✅ **Test with real conversations** (measure quality)
4. ✅ **Optimize with caching** (reduce costs)
5. ✅ **Add frontend later** (once backend is stable)

**Estimated Backend Time:** 6-8 hours  
**Estimated Frontend Time:** 3-4 hours (optional)

**Priority:** 🟡 MEDIUM (Nice-to-have, not critical)

**Next Steps:** Focus on backend implementation, then optionally add frontend integration once API is stable and tested.

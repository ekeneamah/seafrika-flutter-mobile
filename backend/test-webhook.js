#!/usr/bin/env node

/**
 * Meta Webhook Test Script
 * 
 * This script helps test the Meta webhook integration by:
 * 1. Sending sample webhook events to your local/deployed endpoint
 * 2. Verifying message storage in Firestore
 * 3. Testing notification delivery
 * 
 * Usage:
 * node test-webhook.js --url=http://localhost:3000 --business=BIZ-1757246154270715
 */

const crypto = require('crypto');
const axios = require('axios');

// Configuration
const WEBHOOK_VERIFY_TOKEN = 'seafrika_meta_webhook_2024';
const META_APP_SECRET = '97dfc746ad048defcfd25b713109e1ff';
const TIKTOK_APP_SECRET = process.env.TIKTOK_APP_SECRET || 'your_tiktok_app_secret';
const YOUTUBE_WEBHOOK_VERIFY_TOKEN = process.env.YOUTUBE_WEBHOOK_VERIFY_TOKEN || 'seafrika_youtube_webhook_2024';

// Sample webhook events
const SAMPLE_EVENTS = {
  messenger: {
    object: 'page',
    entry: [
      {
        id: '123456789', // This should be your actual page ID
        time: Date.now(),
        messaging: [
          {
            sender: { id: 'test_user_123' },
            recipient: { id: '123456789' },
            timestamp: Date.now(),
            message: {
              mid: `test_msg_${Date.now()}`,
              text: 'Hello! I need help with my order.',
            },
          },
        ],
      },
    ],
  },
  
  instagram: {
    object: 'instagram',
    entry: [
      {
        id: '987654321', // This should be your actual Instagram Business Account ID
        time: Date.now(),
        messaging: [
          {
            sender: { id: 'ig_user_456', username: 'test_customer' },
            recipient: { id: '987654321' },
            timestamp: Date.now(),
            message: {
              mid: `ig_msg_${Date.now()}`,
              text: 'Hi! Is this product still available?',
            },
          },
        ],
      },
    ],
  },
  
  facebook_comment: {
    object: 'page',
    entry: [
      {
        id: '123456789',
        time: Date.now(),
        changes: [
          {
            field: 'mention',
            value: {
              item: 'comment',
              comment_id: `comment_${Date.now()}`,
              post_id: 'post_123',
              sender_id: 'user_789',
              sender_name: 'John Doe',
              message: '@YourPage This looks amazing! How much does it cost?',
              created_time: Math.floor(Date.now() / 1000),
            },
          },
        ],
      },
    ],
  },
  
  instagram_comment: {
    object: 'instagram',
    entry: [
      {
        id: '987654321',
        time: Date.now(),
        changes: [
          {
            field: 'comments',
            value: {
              id: `ig_comment_${Date.now()}`,
              text: 'Love this! Where can I buy it?',
              from: {
                id: 'ig_commenter_123',
                username: 'happy_customer',
              },
              media: {
                id: 'ig_media_456',
                media_product_type: 'FEED',
              },
            },
          },
        ],
      },
    ],
  },

  // TikTok Events
  tiktok_video_publish: {
    event: 'video.publish',
    client_key: 'your_tiktok_client_key',
    user_openid: 'tiktok_user_123',
    video_id: `video_${Date.now()}`,
    video_title: 'Amazing Product Demo!',
    video_description: 'Check out this amazing product we just launched!',
    video_url: 'https://www.tiktok.com/@username/video/1234567890',
    cover_url: 'https://example.com/thumbnail.jpg',
    duration: 30,
    view_count: 150,
    like_count: 25,
    comment_count: 5,
    create_time: Math.floor(Date.now() / 1000),
  },

  tiktok_comment: {
    event: 'comment.create',
    client_key: 'your_tiktok_client_key',
    user_openid: 'tiktok_creator_123',
    video_id: 'video_123',
    comment_id: `comment_${Date.now()}`,
    comment_text: 'This is so cool! Where can I buy this?',
    commenter_openid: 'commenter_456',
    commenter_display_name: 'TikTok User',
    create_time: Math.floor(Date.now() / 1000),
  },

  tiktok_follow: {
    event: 'user.follow',
    client_key: 'your_tiktok_client_key',
    user_openid: 'tiktok_creator_123',
    follower_openid: 'follower_789',
    follower_display_name: 'New Follower',
    create_time: Math.floor(Date.now() / 1000),
  },

  tiktok_like: {
    event: 'user.like',
    client_key: 'your_tiktok_client_key',
    user_openid: 'tiktok_creator_123',
    video_id: 'video_123',
    liker_openid: 'liker_456',
    liker_display_name: 'TikTok Fan',
    create_time: Math.floor(Date.now() / 1000),
  },

  // YouTube Events
  youtube_video_upload: {
    eventType: 'video-upload',
    channelId: 'UC1234567890abcdef',
    videoId: `video_${Date.now()}`,
    title: 'New Product Launch Video',
    description: 'Exciting news! We are launching our new product line.',
    publishedAt: new Date().toISOString(),
    thumbnailUrl: 'https://img.youtube.com/vi/VIDEO_ID/hqdefault.jpg',
    duration: 180,
    viewCount: 500,
    likeCount: 45,
    commentCount: 12,
  },

  youtube_comment: {
    eventType: 'comment',
    channelId: 'UC1234567890abcdef',
    videoId: 'video_123',
    commentId: `comment_${Date.now()}`,
    commentText: 'Great video! When will this be available for purchase?',
    authorChannelId: 'UC9876543210fedcba',
    authorDisplayName: 'YouTube Viewer',
    publishedAt: new Date().toISOString(),
  },

  youtube_subscription: {
    eventType: 'subscription',
    channelId: 'UC1234567890abcdef',
    subscriberChannelId: 'UC9876543210fedcba',
    subscriberChannelTitle: 'New Subscriber',
  },

  youtube_channel_update: {
    eventType: 'channel-update',
    channelId: 'UC1234567890abcdef',
    channelTitle: 'Your Business Channel',
    channelDescription: 'Official channel for our business',
    subscriberCount: 1250,
    videoCount: 85,
  },
};

function generateSignature(payload, secret) {
  return 'sha256=' + crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
}

function generateTikTokSignature(payload, secret, timestamp) {
  // TikTok uses a different signature format: t=timestamp,s=signature
  const signature = crypto
    .createHmac('sha256', secret)
    .update(timestamp + payload)
    .digest('hex');
  return `t=${timestamp},s=${signature}`;
}

async function sendWebhookEvent(webhookUrl, event, eventType, platform = 'meta') {
  try {
    const payload = JSON.stringify(event);
    let signature;
    let headers = {
      'Content-Type': 'application/json',
    };

    // Generate platform-specific signatures
    switch (platform) {
      case 'meta':
        signature = generateSignature(payload, META_APP_SECRET);
        headers['X-Hub-Signature-256'] = signature;
        break;
      case 'tiktok':
        const timestamp = Math.floor(Date.now() / 1000).toString();
        signature = generateTikTokSignature(payload, TIKTOK_APP_SECRET, timestamp);
        headers['tiktok-signature'] = signature;
        headers['x-tiktok-timestamp'] = timestamp;
        break;
      case 'youtube':
        // YouTube webhooks come through Google Cloud Pub/Sub format
        const pubsubEvent = {
          message: {
            data: Buffer.from(payload).toString('base64'),
            messageId: `msg_${Date.now()}`,
            publishTime: new Date().toISOString(),
            attributes: {
              eventType: event.eventType,
              channelId: event.channelId,
            }
          },
          subscription: 'projects/your-project/subscriptions/youtube-webhook-sub'
        };
        return await sendWebhookEvent(webhookUrl, pubsubEvent, eventType, 'youtube_pubsub');
      case 'youtube_pubsub':
        // Already formatted for Pub/Sub, no signature needed
        break;
    }
    
    console.log(`\n🚀 Sending ${eventType} webhook event (${platform})...`);
    console.log(`URL: ${webhookUrl}`);
    console.log(`Payload: ${payload.substring(0, 200)}...`);
    if (signature) console.log(`Signature: ${signature}`);
    
    const response = await axios.post(webhookUrl, event, {
      headers,
      timeout: 30000,
    });
    
    console.log(`✅ ${eventType} webhook sent successfully!`);
    console.log(`Response: ${JSON.stringify(response.data)}`);
    
    return response.data;
  } catch (error) {
    console.error(`❌ Failed to send ${eventType} webhook:`, error.message);
    if (error.response) {
      console.error(`Response status: ${error.response.status}`);
      console.error(`Response data: ${JSON.stringify(error.response.data)}`);
    }
    throw error;
  }
}

async function testWebhookVerification(webhookUrl, platform = 'meta') {
  try {
    console.log(`\n🔍 Testing ${platform} webhook verification...`);
    
    let verifyUrl;
    switch (platform) {
      case 'meta':
        verifyUrl = `${webhookUrl}?hub.mode=subscribe&hub.challenge=test_challenge_123&hub.verify_token=${WEBHOOK_VERIFY_TOKEN}`;
        break;
      case 'tiktok':
        // TikTok verification is usually done during setup, not via challenge
        console.log('TikTok webhook verification is done during app registration');
        return true;
      case 'youtube':
        verifyUrl = `${webhookUrl}?hub.mode=subscribe&hub.challenge=test_challenge_456&hub.verify_token=${YOUTUBE_WEBHOOK_VERIFY_TOKEN}`;
        break;
      default:
        console.log(`Unknown platform: ${platform}`);
        return false;
    }
    
    if (!verifyUrl) return true;
    
    const response = await axios.get(verifyUrl, { timeout: 15000 });
    
    if (response.data.includes('test_challenge_')) {
      console.log(`✅ ${platform} webhook verification successful!`);
      return true;
    } else {
      console.error(`❌ ${platform} webhook verification failed - incorrect challenge response`);
      return false;
    }
  } catch (error) {
    console.error(`❌ ${platform} webhook verification failed:`, error.message);
    return false;
  }
}

async function testAllWebhooks(baseUrl, businessId) {
  const webhookUrls = {
    meta: `${baseUrl}/api/webhooks/meta/webhook`,
    tiktok: `${baseUrl}/api/webhooks/tiktok/webhook`,
    youtube: `${baseUrl}/api/webhooks/youtube/webhook`,
  };
  
  console.log('🧪 Starting Multi-Platform Webhook Integration Test');
  console.log(`Base URL: ${baseUrl}`);
  console.log(`Business ID: ${businessId}`);
  console.log('Webhook URLs:');
  Object.entries(webhookUrls).forEach(([platform, url]) => {
    console.log(`  ${platform}: ${url}`);
  });
  
  // Test webhook verification for each platform
  for (const [platform, webhookUrl] of Object.entries(webhookUrls)) {
    const verificationPassed = await testWebhookVerification(webhookUrl, platform);
    if (!verificationPassed && platform !== 'tiktok') {
      console.log(`⚠️  ${platform} webhook verification failed. Check your configuration.`);
    }
  }
  
  // Group events by platform
  const eventsByPlatform = {
    meta: ['messenger', 'instagram', 'facebook_comment', 'instagram_comment'],
    tiktok: ['tiktok_video_publish', 'tiktok_comment', 'tiktok_follow', 'tiktok_like'],
    youtube: ['youtube_video_upload', 'youtube_comment', 'youtube_subscription', 'youtube_channel_update'],
  };
  
  // Test each platform's events
  for (const [platform, eventTypes] of Object.entries(eventsByPlatform)) {
    console.log(`\n🎯 Testing ${platform.toUpperCase()} events...`);
    
    for (const eventType of eventTypes) {
      try {
        const event = SAMPLE_EVENTS[eventType];
        if (!event) {
          console.warn(`⚠️  Event ${eventType} not found in SAMPLE_EVENTS`);
          continue;
        }
        
        await sendWebhookEvent(webhookUrls[platform], event, eventType, platform);
        console.log(`✅ ${eventType} test completed`);
        
        // Wait a bit between events
        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (error) {
        console.error(`❌ ${eventType} test failed:`, error.message);
      }
    }
  }
  
  console.log('\n📝 Test Summary:');
  console.log('- Check your application logs to see if webhook events were processed');
  console.log('- Check Firestore for saved messages in businesses/{businessId}/messages');
  console.log('- Check if notifications were triggered (check logs for notification service)');
  console.log('- Use the API endpoints to verify data:');
  console.log(`  GET ${baseUrl}/api/messages/${businessId}`);
  console.log(`  GET ${baseUrl}/api/messages/${businessId}/unread-count`);
  console.log(`  GET ${baseUrl}/api/messages/${businessId}?platform=tiktok`);
  console.log(`  GET ${baseUrl}/api/messages/${businessId}?platform=youtube`);
}

// Parse command line arguments
const args = process.argv.slice(2);
const getArg = (name) => {
  const arg = args.find(a => a.startsWith(`--${name}=`));
  return arg ? arg.split('=')[1] : null;
};

const baseUrl = getArg('url') || 'http://localhost:3000';
const businessId = getArg('business') || 'BIZ-1757246154270715';

// Run the test
testAllWebhooks(baseUrl, businessId)
  .then(() => {
    console.log('\n🎉 All tests completed!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Test failed:', error.message);
    process.exit(1);
  });
#!/bin/bash

# Facebook Instagram Webhook Setup Script
# This script helps you set up Facebook Developer configuration for Instagram webhooks

echo "🚀 Seafrika Instagram Webhook Setup"
echo "=================================="
echo ""

# Check if required environment variables are set
echo "📋 Checking environment configuration..."

required_vars=("FACEBOOK_APP_ID" "FACEBOOK_APP_SECRET" "INSTAGRAM_APP_ID" "INSTAGRAM_APP_SECRET" "INSTAGRAM_VERIFY_TOKEN")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -eq 0 ]; then
    echo "✅ All required environment variables are set"
else
    echo "❌ Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "   - $var"
    done
    echo ""
    echo "Please add these to your .env file:"
    echo "FACEBOOK_APP_ID=your-facebook-app-id"
    echo "FACEBOOK_APP_SECRET=your-facebook-app-secret"
    echo "INSTAGRAM_APP_ID=your-instagram-app-id"
    echo "INSTAGRAM_APP_SECRET=your-instagram-app-secret"
    echo "INSTAGRAM_VERIFY_TOKEN=your-custom-verify-token"
    echo ""
    echo "📖 See docs/FACEBOOK_DEVELOPER_SETUP.md for detailed instructions"
    exit 1
fi

echo ""
echo "🔗 Useful URLs for setup:"
echo "========================="
echo "Facebook Developer Console: https://developers.facebook.com/"
echo "Graph API Explorer: https://developers.facebook.com/tools/explorer/"
echo "Instagram Basic Display Docs: https://developers.facebook.com/docs/instagram-basic-display-api/"
echo ""

# Check if server is running
if curl -s "http://localhost:3000/api/webhooks/instagram/test" > /dev/null; then
    echo "✅ Webhook server is running"
    
    # Test webhook endpoint
    echo ""
    echo "🧪 Testing webhook endpoints..."
    
    # Test configuration validation
    echo "Testing configuration validation..."
    curl -s "http://localhost:3000/api/config/facebook/validate" | jq '.' || echo "Configuration endpoint not available"
    
    # Test webhook verification
    echo ""
    echo "Testing webhook verification..."
    test_token="test123"
    response=$(curl -s "http://localhost:3000/api/webhooks/instagram?hub.mode=subscribe&hub.challenge=${test_token}&hub.verify_token=${INSTAGRAM_VERIFY_TOKEN}")
    
    if [ "$response" = "$test_token" ]; then
        echo "✅ Webhook verification working correctly"
    else
        echo "❌ Webhook verification failed"
        echo "Expected: $test_token"
        echo "Got: $response"
    fi
    
else
    echo "❌ Webhook server is not running"
    echo "Please start the server with: npm run start:dev"
    exit 1
fi

echo ""
echo "📋 Next Steps:"
echo "=============="
echo "1. Create Facebook App at: https://developers.facebook.com/"
echo "2. Add Instagram Basic Display product"
echo "3. Configure webhook URL: https://your-domain.com/api/webhooks/instagram"
echo "4. Set verify token: ${INSTAGRAM_VERIFY_TOKEN}"
echo "5. Test with: curl \"http://localhost:3000/api/config/facebook/setup-guide\""
echo ""
echo "📖 Full documentation: docs/FACEBOOK_DEVELOPER_SETUP.md"
echo "🔧 API docs: http://localhost:3000/api/docs"

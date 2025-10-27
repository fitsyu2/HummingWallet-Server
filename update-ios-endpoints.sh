#!/bin/bash

# iOS App Endpoint Update Script
# Run this after deploying to Render

echo "📱 iOS App Endpoint Update"
echo "=========================="
echo ""

# Get the new server URL from user
echo "Enter your deployment service URL:"
echo "  - Railway: https://your-app-name.up.railway.app"
echo "  - Render: https://your-service-name.onrender.com"
echo "  - Custom: https://your-domain.com"
echo ""
echo "URL:"
read DEPLOY_URL

if [ -z "$DEPLOY_URL" ]; then
    echo "❌ Error: URL cannot be empty"
    exit 1
fi

# Remove trailing slash if present
DEPLOY_URL=${DEPLOY_URL%/}

echo ""
echo "🔄 Updating iOS app endpoints to: $DEPLOY_URL"
echo ""

# Check if we're in the right directory structure
if [ ! -d "../LiveWallet-iOS" ]; then
    echo "❌ Error: LiveWallet-iOS directory not found"
    echo "Please run this script from the HummingWallet-Server directory"
    exit 1
fi

# Update LiveActivityManager.swift
LIVE_ACTIVITY_FILE="../LiveWallet-iOS/LiveWallet/LiveActivityManager.swift"
if [ -f "$LIVE_ACTIVITY_FILE" ]; then
    echo "📝 Updating LiveActivityManager.swift..."
    # Replace any existing server URL with the new one
    sed -i '' "s|serverUrl = \"https://.*\..*\"|serverUrl = \"$DEPLOY_URL\"|g" "$LIVE_ACTIVITY_FILE"
    sed -i '' "s|return \"https://.*\..*\"|return \"$DEPLOY_URL\"|g" "$LIVE_ACTIVITY_FILE"
    echo "✅ LiveActivityManager.swift updated"
else
    echo "⚠️  Warning: LiveActivityManager.swift not found"
fi

# Update VideoStreamManager.swift
VIDEO_MANAGER_FILE="../LiveWallet-iOS/LiveWallet/VideoStreamManager.swift"
if [ -f "$VIDEO_MANAGER_FILE" ]; then
    echo "📝 Updating VideoStreamManager.swift..."
    # Replace any existing base URL with the new one
    sed -i '' "s|baseURL = \"https://.*\..*\"|baseURL = \"$DEPLOY_URL\"|g" "$VIDEO_MANAGER_FILE"
    echo "✅ VideoStreamManager.swift updated"
else
    echo "⚠️  Warning: VideoStreamManager.swift not found"
fi

echo ""
echo "🎉 Endpoint update complete!"
echo ""
echo "📋 Next steps:"
echo "1. Build and test your iOS app"
echo "2. Verify connectivity to: $DEPLOY_URL/health"
echo "3. Test video streaming: $DEPLOY_URL/api/v1/video/demo/stream.m3u8"
echo ""
echo "🔗 Your new endpoints:"
echo "   • Health: $DEPLOY_URL/health"
echo "   • Live Activities: $DEPLOY_URL/api/v1/liveactivities/*"
echo "   • Video Streaming: $DEPLOY_URL/api/v1/video/*"
echo ""
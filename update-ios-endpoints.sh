#!/bin/bash

# iOS App Endpoint Update Script
# Run this after deploying to Render or Railway

echo "📱 iOS App Endpoint Update"
echo "=========================="
echo ""

# Get the new server URL from user
echo "Enter your deployment service URL:"
echo "Examples:"
echo "  Render: https://your-service-name.onrender.com"
echo "  Railway: https://your-service-name.railway.app"
echo ""
echo "URL:"
read DEPLOYMENT_URL

if [ -z "$DEPLOYMENT_URL" ]; then
    echo "❌ Error: URL cannot be empty"
    exit 1
fi

# Remove trailing slash if present
DEPLOYMENT_URL=${DEPLOYMENT_URL%/}

echo ""
echo "🔄 Updating iOS app endpoints to: $DEPLOYMENT_URL"
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
    sed -i '' "s|serverUrl = \"https://.*\..*\"|serverUrl = \"$DEPLOYMENT_URL\"|g" "$LIVE_ACTIVITY_FILE"
    sed -i '' "s|return \"https://.*\..*\"|return \"$DEPLOYMENT_URL\"|g" "$LIVE_ACTIVITY_FILE"
    echo "✅ LiveActivityManager.swift updated"
else
    echo "⚠️  Warning: LiveActivityManager.swift not found"
fi

# Update VideoStreamManager.swift
VIDEO_MANAGER_FILE="../LiveWallet-iOS/LiveWallet/VideoStreamManager.swift"
if [ -f "$VIDEO_MANAGER_FILE" ]; then
    echo "📝 Updating VideoStreamManager.swift..."
    # Replace any existing base URL with the new one
    sed -i '' "s|baseURL = \"https://.*\..*\"|baseURL = \"$DEPLOYMENT_URL\"|g" "$VIDEO_MANAGER_FILE"
    echo "✅ VideoStreamManager.swift updated"
else
    echo "⚠️  Warning: VideoStreamManager.swift not found"
fi

echo ""
echo "🎉 Endpoint update complete!"
echo ""
echo "📋 Next steps:"
echo "1. Build and test your iOS app"
echo "2. Verify connectivity to: $DEPLOYMENT_URL/health"
echo "3. Test video streaming: $DEPLOYMENT_URL/api/v1/video/demo/stream.m3u8"
echo ""
echo "🔗 Your new endpoints:"
echo "   • Health: $DEPLOYMENT_URL/health"
echo "   • Live Activities: $DEPLOYMENT_URL/api/v1/liveactivities/*"
echo "   • Video Streaming: $DEPLOYMENT_URL/api/v1/video/*"
echo ""
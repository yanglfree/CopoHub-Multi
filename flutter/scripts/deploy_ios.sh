#!/bin/bash

# ==============================================================================
# CopoHub iOS App Store Connect Deployment Script
# 
# Usage: 
#   ./scripts/deploy_ios.sh
#
# Environment Variables required (You can also hardcode them below):
#   APPLE_ID="your_email@example.com"
#   APP_SPECIFIC_PASSWORD="your-app-specific-password"
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    echo "📄 Loading credentials from .env file..."
    source .env
fi

echo "🍏 Starting iOS deployment to App Store Connect..."

# 1. Check for credentials
if [ -z "$APPLE_ID" ] || [ -z "$APP_SPECIFIC_PASSWORD" ]; then
    echo "⚠️  Credentials not found in environment."
    echo "Please enter your Apple ID (e.g. youdroid2048@gmail.com):"
    read -p "> " APPLE_ID
    echo "Please enter your App-Specific Password (e.g. abcd-efgh-ijkl-mnop):"
    read -s -p "> " APP_SPECIFIC_PASSWORD
    echo ""
fi

# 2. Clean and build
echo "🧹 Cleaning project..."
flutter clean
flutter pub get

# 3. Build IPA
echo "📦 Building IPA for App Store (this will take a few minutes)..."
# The --export-method app-store flag ensures it creates an IPA ready for upload
flutter build ipa --release --export-method app-store

# 4. Find the generated IPA
IPA_PATH=$(find build/ios/ipa -name "*.ipa" | head -n 1)

if [ -z "$IPA_PATH" ]; then
    echo "❌ Error: Failed to find the generated IPA file in build/ios/ipa/"
    exit 1
fi

echo "✅ Successfully built IPA at: $IPA_PATH"
echo "🚀 Uploading to App Store Connect..."

# 5. Upload via xcrun altool
# Note: xcrun altool will upload the app to App Store Connect for TestFlight / App Store processing.
xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --username "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD"

if [ $? -eq 0 ]; then
    echo "🎉 Upload successful!"
    echo "Please wait a few minutes for Apple to process the build in App Store Connect."
else
    echo "❌ Upload failed. Please check your credentials, network, and the error logs above."
    exit 1
fi

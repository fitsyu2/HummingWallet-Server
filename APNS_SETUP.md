# Real APNs Setup Guide

## 📋 Prerequisites

1. **Apple Developer Program Membership** ($99/year)
2. **Paid Apple Developer Account** (free accounts cannot create APNs keys)

## 🔑 Step 1: Create APNs Authentication Key

### 1.1 Go to Apple Developer Console
- Visit: https://developer.apple.com
- Sign in with your Apple ID

### 1.2 Navigate to Keys
- Go to "Certificates, Identifiers & Profiles"
- Click "Keys" in the left sidebar

### 1.3 Create New Key
1. Click the "+" button to create a new key
2. Enter a descriptive name: "LiveWallet APNs Key"
3. Check the box for "Apple Push Notifications service (APNs)"
4. Click "Continue" and then "Register"

### 1.4 Download the Key
⚠️ **CRITICAL**: You can only download this key file once!

1. Click "Download" to get the `.p8` file
2. Save it as: `AuthKey_[KEY_ID].p8` (e.g., `AuthKey_ABC123DEFG.p8`)
3. **Note the Key ID**: 10-character string (e.g., `ABC123DEFG`)
4. Store the file securely

## 👥 Step 2: Get Your Team ID

1. In Apple Developer Console, go to "Membership"
2. Copy your **Team ID** (10-character string like `XYZ789MNOP`)

## 📱 Step 3: Configure App Identifier

### 3.1 Find Your App ID
1. Go to "Certificates, Identifiers & Profiles"
2. Click "Identifiers"
3. Look for `fitsyu2.LiveWallet` or create it if missing

### 3.2 Enable Push Notifications
1. Click on your app identifier
2. Check "Push Notifications" under Capabilities
3. Click "Save"

## 🖥️ Step 4: Configure Server

### 4.1 Place APNs Key File
```bash
# Create secure directory for keys
mkdir -p /Users/fitrahsyuhada/Projects/HummingWallet-Workspace/HummingWallet-Server/keys

# Move your downloaded key file there
mv ~/Downloads/AuthKey_ABC123DEFG.p8 /Users/fitrahsyuhada/Projects/HummingWallet-Workspace/HummingWallet-Server/keys/
```

### 4.2 Update Environment Variables
Edit `/Users/fitrahsyuhada/Projects/HummingWallet-Workspace/HummingWallet-Server/.env`:

```bash
# APNs Configuration - REPLACE WITH YOUR VALUES
APNS_KEY_ID=R5VFGH4JV2
APNS_TEAM_ID=635367SA9L
APNS_PRIVATE_KEY_PATH=/Users/fitrahsyuhada/Projects/HummingWallet-Workspace/HummingWallet-Server/keys/AuthKey_R5VFGH4JV2.p8
BUNDLE_IDENTIFIER=fitsyu2.LiveWallet

# Server Configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
LOG_LEVEL=info

# Environment (sandbox for development, production for App Store)
APNS_ENVIRONMENT=sandbox
```

### 4.3 Secure the Key File
```bash
# Set proper permissions for security
chmod 600 /Users/fitrahsyuhada/Projects/HummingWallet-Workspace/HummingWallet-Server/keys/AuthKey_R5VFGH4JV2.p8
```

## 📲 Step 5: iOS App Configuration

### 5.1 Update Provisioning Profile
1. In Xcode, select your LiveWallet project
2. Go to "Signing & Capabilities"
3. Ensure "Push Notifications" capability is added
4. Ensure your provisioning profile includes Push Notifications

### 5.2 Update Entitlements
Your `LiveWallet.entitlements` should include:
```xml
<key>aps-environment</key>
<string>development</string>
```

For production builds, change to:
```xml
<key>aps-environment</key>
<string>production</string>
```

## 🚀 Step 6: Test Real APNs

### 6.1 Restart Server
```bash
cd /Users/fitrahsyuhada/Projects/HummingWallet-Workspace/HummingWallet-Server
swift run
```

You should see:
```
✅ Real APNs client initialized successfully
```

### 6.2 Test on Device
1. Deploy app to physical iPhone (LiveActivities don't work in simulator)
2. Start a ride in the app
3. Watch for real push notifications in Dynamic Island

## 🔍 Troubleshooting

### Common Issues:

1. **"Key file not found"**
   - Verify the path in `APNS_PRIVATE_KEY_PATH`
   - Check file permissions (`chmod 600`)

2. **"Invalid authentication"**
   - Verify `APNS_KEY_ID` matches your key file
   - Verify `APNS_TEAM_ID` is correct

3. **"Bundle ID mismatch"**
   - Ensure `BUNDLE_IDENTIFIER=fitsyu2.LiveWallet`
   - Verify app identifier in Apple Developer Console

4. **"APNs environment error"**
   - Use `sandbox` for development
   - Use `production` for App Store builds

### Log Messages:
- ✅ `Real APNs client initialized successfully` = Working
- ⚠️ `APNs configuration missing - running in testing mode` = Missing setup
- ❌ `Failed to initialize APNs client` = Configuration error

## 🔐 Security Notes

1. **Never commit** `.p8` files to version control
2. **Add to .gitignore**:
   ```
   keys/
   *.p8
   .env
   ```
3. **Restrict file permissions**: `chmod 600` on key files
4. **Use environment variables** for production deployments

## 📚 Additional Resources

- [APNs Overview](https://developer.apple.com/documentation/usernotifications)
- [LiveActivity Documentation](https://developer.apple.com/documentation/activitykit)
- [APNSwift Library](https://github.com/swift-server-community/APNSwift)

---

Once you complete this setup, your LiveActivities will receive real push notifications from Apple's servers instead of simulated ones!
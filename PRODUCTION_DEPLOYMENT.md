# 🚀 Production Deployment Guide

## 📋 **Prerequisites**
- ✅ Railway CLI installed 
- ⏳ Railway account login needed
- ⏳ Railway project setup needed

## 🔷 **Step 1: Login to Railway**

```bash
cd /Users/fitrahsyuhada/Projects/HummingWallet-Workspace/HummingWallet-Server
railway login
```

This will open a browser for authentication.

## 🔷 **Step 2: Initialize Railway Project**

If you don't have a Railway project yet:

```bash
railway init
# Follow prompts to create a new project called "hummingwallet-server"
```

If you already have a project:

```bash
railway link
# Select your existing project
```

## 🔷 **Step 3: Deploy to Production**

```bash
# Deploy without DEVELOPMENT flag (production mode)
railway up
```

This will:
- Deploy your Swift server to Railway
- Use production URLs in responses
- Make it accessible at `https://hummingwallet-server-production.up.railway.app`

## 🔷 **Step 4: Verify Deployment**

```bash
# Check deployment status
railway status

# Get the deployed URL
railway domain
```

## 🚨 **Important Notes**

1. **No DEVELOPMENT Flag**: Railway deployment automatically runs in production mode
2. **Environment Variables**: Railway may need additional config for Swift deployment
3. **Domain**: Note the actual domain Railway assigns (might be different than our placeholder)

---

## 📱 **Next: Configure Apps**

Once server is deployed, we'll update:
1. **Android**: Change `BASE_URL` to production
2. **iOS**: Change `baseURL` to production
3. **Build**: Create APK and iOS build for real devices

Would you like to proceed with the Railway login and deployment?
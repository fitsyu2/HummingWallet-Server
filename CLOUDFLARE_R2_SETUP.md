# CloudFlare R2 Setup Guide

## Overview
This guide will help you set up CloudFlare R2 for video streaming with our HummingWallet server. R2 provides cost-effective object storage compatible with AWS S3 APIs.

## Cost Breakdown
- **CloudFlare R2**: $0.015/GB/month storage + $0.36/million requests
- **Estimated Monthly Cost**: $0-5 for video streaming (vs $100/month Railway Team plan)
- **Total Hybrid Cost**: ~$5-10/month (Railway Hobby + R2)

## Step 1: Create CloudFlare Account

1. Go to [CloudFlare](https://cloudflare.com)
2. Sign up for a free account or log in
3. Navigate to **R2 Object Storage** in the dashboard

## Step 2: Create R2 Bucket

1. Click **"Create bucket"**
2. **Bucket name**: `hummingwallet-videos` (or your preference)
3. **Location**: Choose closest to your users
4. Click **"Create bucket"**

## Step 3: Configure CORS (Cross-Origin Resource Sharing)

1. Go to your bucket settings
2. Click **"Settings"** tab
3. Scroll to **CORS policy**
4. Add this configuration:

```json
[
  {
    "AllowedOrigins": [
      "*"
    ],
    "AllowedMethods": [
      "GET",
      "PUT",
      "POST",
      "DELETE",
      "HEAD"
    ],
    "AllowedHeaders": [
      "*"
    ],
    "ExposeHeaders": [
      "ETag"
    ],
    "MaxAgeSeconds": 3600
  }
]
```

## Step 4: Get API Credentials

### Method 1: Using R2 API Tokens (Recommended)
1. In your Cloudflare dashboard, click **"R2 Object Storage"** in the left sidebar
2. Click **"Manage R2 API tokens"** button (usually in the top right)
3. Click **"Create API token"**
4. **Token name**: `HummingWallet-Server`
5. **Permissions**: 
   - `Object Read`
   - `Object Write` 
   - `Object Delete`
6. **Bucket restrictions**: Select your bucket (`hummingwallet-videos`)
7. Click **"Create API token"**
8. **IMPORTANT**: Copy these values immediately:
   - **Access Key ID**
   - **Secret Access Key**

### Method 2: Alternative Navigation (if button not found)
1. Go to **"My Profile"** (click on your profile icon in top right)
2. Click **"API Tokens"** tab
3. Scroll down to **"R2 API tokens"** section
4. Click **"Create token"**
5. Follow steps 4-8 above

### Method 3: Direct URL
Navigate directly to: `https://dash.cloudflare.com/profile/api-tokens` and scroll to R2 section

## Step 5: Get Additional Configuration

1. **Account ID**: Found in R2 dashboard sidebar
2. **Bucket Name**: Your bucket name (e.g., `hummingwallet-videos`)
3. **Endpoint**: `https://<account-id>.r2.cloudflarestorage.com`
4. **Public URL**: `https://pub-<bucket-id>.r2.dev` (enable custom domain for production)

## Step 6: Configure Railway Environment Variables

Add these environment variables to your Railway deployment:

```bash
R2_ACCOUNT_ID=your_account_id_here
R2_ACCESS_KEY_ID=your_access_key_here
R2_SECRET_ACCESS_KEY=your_secret_key_here
R2_BUCKET_NAME=hummingwallet-videos
R2_ENDPOINT=https://your_account_id.r2.cloudflarestorage.com
R2_PUBLIC_URL=https://pub-your_bucket_id.r2.dev
```

### How to add to Railway:
1. Go to your Railway project dashboard
2. Click **"Variables"** tab
3. Add each variable one by one
4. Deploy the changes

## Step 7: Test the Integration

1. Deploy your server with R2 integration
2. Test video upload endpoint:
```bash
curl -X POST "your-railway-url/api/v1/video/live/test123/upload" \
  -F "videoSegment=@test-video.ts" \
  -F "segmentNumber=1"
```

3. Test playlist generation:
```bash
curl "your-railway-url/api/v1/video/live/test123/stream.m3u8"
```

## Security Best Practices

1. **Restrict API token permissions** to only your bucket
2. **Enable bucket versioning** for data protection
3. **Set up lifecycle rules** to automatically delete old segments
4. **Use custom domain** for production instead of pub-*.r2.dev

## Monitoring & Costs

1. **Monitor usage** in CloudFlare R2 dashboard
2. **Set billing alerts** to avoid unexpected charges
3. **Review access logs** for security

## Troubleshooting

### Common Issues:

1. **"Access Denied" errors**:
   - Check API token permissions
   - Verify bucket name in environment variables

2. **CORS errors**:
   - Ensure CORS policy is properly configured
   - Check allowed origins include your domain

3. **Upload failures**:
   - Verify all environment variables are set
   - Check server logs for detailed error messages

### Support:
- CloudFlare R2 Documentation: https://developers.cloudflare.com/r2/
- Server logs: Check Railway deployment logs for detailed errors

## Next Steps

Once R2 is configured:
1. Deploy server to Railway
2. Test video streaming with iOS app
3. Monitor performance and costs
4. Consider custom domain for production

---

**Estimated Setup Time**: 15-30 minutes  
**Monthly Cost Savings**: ~$90-95 compared to Railway Team plan
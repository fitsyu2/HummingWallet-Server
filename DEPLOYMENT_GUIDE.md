# Deployment Guide: Enhanced HummingWallet Server with R2

## Overview
This guide covers deploying the enhanced HummingWallet server with CloudFlare R2 integration to Railway.

## Prerequisites
- ✅ CloudFlare R2 bucket created and configured
- ✅ R2 API credentials obtained
- ✅ Railway account with Hobby package ($5/month)

## Server Enhancements

### New Features Added:
1. **CloudFlare R2 Integration**: Cost-effective video storage
2. **Live Video Streaming**: HLS playlist generation with R2 URLs
3. **Automatic Cleanup**: Removes old segments after rides end
4. **Hybrid Architecture**: Railway for APIs + R2 for video storage

### Cost Savings:
- **Before**: $100/month (Railway Team plan for video storage)
- **After**: $5-10/month (Railway Hobby + CloudFlare R2)
- **Savings**: 85-90% cost reduction

## Deployment Steps

### 1. Environment Variables
Set these in Railway dashboard:

```bash
# R2 Configuration
R2_ACCOUNT_ID=your_account_id
R2_ACCESS_KEY_ID=your_access_key  
R2_SECRET_ACCESS_KEY=your_secret_key
R2_BUCKET_NAME=hummingwallet-videos
R2_ENDPOINT=https://your_account_id.r2.cloudflarestorage.com
R2_PUBLIC_URL=https://pub-your_bucket_id.r2.dev

# Server Configuration (if needed)
PORT=8080
```

### 2. Deploy to Railway

1. **Connect Repository**:
   ```bash
   railway login
   railway link
   ```

2. **Deploy Server**:
   ```bash
   railway up
   ```

3. **Monitor Deployment**:
   - Check Railway dashboard for build logs
   - Verify server starts without errors
   - Test health endpoint: `GET /health`

### 3. Test Deployment

#### Test 1: Health Check
```bash
curl https://your-railway-url.railway.app/health
```
Expected: `{"status": "ok"}`

#### Test 2: Video Upload
```bash
# Create a test video segment (or use existing .ts file)
curl -X POST "https://your-railway-url.railway.app/api/v1/video/live/test123/upload" \
  -F "videoSegment=@test-segment.ts" \
  -F "segmentNumber=1"
```

#### Test 3: Playlist Generation
```bash
curl "https://your-railway-url.railway.app/api/v1/video/live/test123/stream.m3u8"
```
Expected: HLS playlist with R2 URLs

#### Test 4: iOS Integration
Update iOS app endpoint to your Railway URL and test live streaming.

## API Endpoints

### Live Activities (Existing)
- `POST /api/v1/activities/start` - Start live activity
- `POST /api/v1/activities/update` - Update live activity  
- `POST /api/v1/activities/end` - End live activity

### Video Streaming (New)
- `POST /api/v1/video/live/:rideId/start` - Start live stream
- `POST /api/v1/video/live/:rideId/stop` - Stop live stream
- `POST /api/v1/video/live/:rideId/upload` - Upload video segment
- `GET /api/v1/video/live/:rideId/stream.m3u8` - Get HLS playlist
- `GET /api/v1/video/live/:rideId/status` - Get stream status

### Simple Video (Testing)
- `POST /api/v1/video/ride/:rideId/start` - Start simple stream
- `POST /api/v1/video/ride/:rideId/stop` - Stop simple stream
- `GET /api/v1/video/ride/:rideId/status` - Get simple status

## Monitoring & Maintenance

### Server Logs
Monitor Railway logs for:
- Video upload success/failures
- R2 storage operations
- HLS playlist generation
- Automatic cleanup operations

### Performance Metrics
- **Memory Usage**: Should stay under 512MB (Hobby limit)
- **CPU Usage**: Typically low except during video processing
- **Network**: Inbound video uploads, outbound to R2

### R2 Storage Monitoring
- **Storage Used**: Monitor in CloudFlare dashboard
- **Request Count**: Track API usage
- **Bandwidth**: Outbound from R2 to clients

## Troubleshooting

### Common Issues:

1. **"R2 credentials not found"**:
   - Verify all R2 environment variables are set
   - Check variable names match exactly

2. **Video upload fails**:
   - Check R2 bucket permissions
   - Verify CORS configuration
   - Check file size limits

3. **HLS playlist empty**:
   - Verify segments uploaded successfully to R2
   - Check R2 public URL configuration
   - Ensure playlist generation logic works

4. **iOS app can't stream**:
   - Verify HLS playlist accessible via browser
   - Check CORS allows iOS app domain
   - Test with VLC or other HLS player

### Debug Commands:

```bash
# Check server status
railway status

# View server logs  
railway logs

# Connect to server shell (if needed)
railway shell
```

## Production Considerations

### Security:
- [ ] Use custom domain for R2 instead of pub-*.r2.dev
- [ ] Implement proper authentication for video uploads
- [ ] Add rate limiting for API endpoints
- [ ] Enable HTTPS only

### Performance:
- [ ] Monitor memory usage (Hobby plan limit: 512MB)
- [ ] Optimize video segment sizes
- [ ] Consider CDN for global distribution
- [ ] Implement video compression if needed

### Reliability:
- [ ] Set up health checks
- [ ] Monitor R2 availability
- [ ] Implement retry logic for R2 operations
- [ ] Set up alerting for failures

## Success Criteria

✅ **Server deploys without errors**  
✅ **Health endpoint responds**  
✅ **Video upload works**  
✅ **HLS playlist generates**  
✅ **iOS app can stream videos**  
✅ **R2 storage costs under $5/month**  
✅ **Total hosting costs under $10/month**

## Next Steps

1. **Monitor for 24-48 hours** to ensure stability
2. **Test with real video content** from iOS app
3. **Optimize segment cleanup** timing if needed
4. **Consider custom domain** for production
5. **Add monitoring alerts** for cost/usage

---

**Expected Deployment Time**: 15-30 minutes  
**Monthly Hosting Cost**: $5-10 total  
**Cost Savings**: 85-90% vs previous architecture
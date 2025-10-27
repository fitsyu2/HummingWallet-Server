# RideTracker - LiveActivities Server

A Swift server built with HummingBird framework that provides endpoints for sending ride tracking LiveActivities notifications to iOS devices.

## Features

- 🚗 Ride tracking LiveActivity notifications
- 📱 Real-time ride status updates
- 🎯 Smart alert generation based on ride status
- 🔧 Built with HummingBird for high performance
- 📮 Uses APNSwift for Apple Push Notification service
- 🔐 Secure JWT-based authentication with APNs
- 📊 Comprehensive error handling and logging

## Prerequisites

- Swift 5.9 or later
- macOS 12 or later
- APNs Auth Key (.p8 file) from Apple Developer Portal
- iOS app with LiveActivities configured

## Quick Start

### 1. Build and Run

```bash
# Build the project
swift build

# Run the server
swift run HummingWallet
```

The server will start on `http://localhost:8080`

### 2. Test the Server

```bash
# Health check
curl http://localhost:8080/health

# Expected response:
# {"status":"ok","service":"RideTracker API","timestamp":"1698765432.123"}
```

### 3. APNs Configuration (Optional)

For production use with actual LiveActivities:

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Create a new Auth Key with APNs enabled
3. Download the `.p8` file
4. Set environment variables:

```bash
export APNS_KEY_ID=your_10_character_key_id
export APNS_TEAM_ID=your_10_character_team_id
export APNS_PRIVATE_KEY_PATH=/absolute/path/to/AuthKey_XXXXXXXX.p8
export BUNDLE_IDENTIFIER=com.yourcompany.ridetracker
```

## API Endpoints

### Health Check
```
GET /health
GET /
```

Response:
```json
{
  "service": "RideTracker LiveActivity Server",
  "version": "1.0.0",
  "description": "Real-time ride tracking with iOS LiveActivity support",
  "status": "running",
  "timestamp": "1698765432.123"
}
```

### Start Ride Tracking
```
POST /api/v1/liveactivities/send
```

Request body:
```json
{
  "activity_id": "RIDE123",
  "push_token": "64_character_hex_push_token",
  "content_state": "base64_encoded_ride_state",
  "attributes": "base64_encoded_ride_attributes",
  "priority": 10
}
```

Example ride content state (before base64 encoding):
```json
{
  "status": "driver_found",
  "progress": 0.25,
  "currentStep": "Driver John found",
  "estimatedArrival": "2024-01-01T12:05:00Z",
  "fare": 25.50,
  "driverLocation": "En route to pickup"
}
```

Example ride attributes (before base64 encoding):
```json
{
  "rideId": "RIDE123",
  "rideType": "economy",
  "pickupLocation": "123 Main St",
  "dropoffLocation": "456 Oak Ave",
  "driverName": "John Smith",
  "driverRating": 4.8,
  "vehicleInfo": "Toyota Camry - White",
  "licensePlate": "ABC-1234"
}
```

### Update Ride Status
```
POST /api/v1/liveactivities/update
```

Request body:
```json
{
  "activity_id": "RIDE123",
  "push_token": "64_character_hex_push_token",
  "content_state": "base64_encoded_updated_state",
  "priority": 5
}
```

### End Ride
```
POST /api/v1/liveactivities/end
```

Request body:
```json
{
  "activity_id": "RIDE123",
  "push_token": "64_character_hex_push_token",
  "final_content_state": "base64_encoded_final_state",
  "dismissal_date": "2024-01-01T12:30:00Z"
}
```

### Response Format

All endpoints return a response in this format:

```json
{
  "success": true,
  "message": "Ride notification sent successfully (simulated)",
  "activity_id": "RIDE123",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

## Ride Status Flow

The server automatically generates contextual alerts based on ride status:

- **driver_found**: "Driver Found! 🚗" - Driver assigned and en route
- **driver_pickup**: "Driver Arriving" - Driver approaching pickup location
- **driver_dropoff**: "Ride Started" - Journey to destination began
- **completed**: "Ride Completed ✅" - Arrival at destination
- **cancelled**: "Ride Cancelled" - Ride was cancelled

## Intelligent Alert Generation

The server parses ride data and automatically creates appropriate push notifications:

```swift
// Example auto-generated alerts:
"Driver Found! 🚗 - John Smith is heading to pick you up in a Toyota Camry - White"
"Driver Arriving - John Smith will arrive in 5 minutes"
"Ride Started - On your way to 456 Oak Ave"
"Ride Completed ✅ - You've arrived! Fare: $25.50"
```

## Logging

The server provides detailed ride tracking logs:

```
info RideTracker: Starting ride: Driver=John Smith, Type=economy, From=123 Main St, To=456 Oak Ave
info RideTracker: Ride update: Status=driver_pickup, Step=Driver en route, Progress=50%
info RideTracker: Ride completed: Status=completed, Fare=$25.50
```

## Error Handling

The server provides detailed error messages for various scenarios:

- Invalid push token format
- Ride data parsing errors
- Missing or invalid request body
- APNs service errors
- Configuration errors

## Production Deployment

### Deploy to Render

1. **Push to GitHub**: Ensure your code is in a GitHub repository

2. **Create Render Account**: Sign up at [render.com](https://render.com)

3. **Create New Web Service**:
   - Connect your GitHub repository
   - Choose "Docker" as the environment
   - Render will automatically detect the `Dockerfile`

4. **Configuration**:
   - **Build Command**: `swift build -c release`
   - **Start Command**: `swift run -c release`
   - **Port**: Render automatically sets the `PORT` environment variable (defaults to 10000)
   - **Health Check Path**: `/health`

5. **Environment Variables** (if using APNs):
   - `APNS_KEY_ID`: Your 10 character key ID
   - `APNS_TEAM_ID`: Your 10 character team ID
   - `APNS_PRIVATE_KEY_PATH`: Path to your .p8 file
   - `BUNDLE_IDENTIFIER`: Your app's bundle identifier

6. **Deploy**: Click "Create Web Service"

Your server will be available at `https://your-service-name.onrender.com`

### Update iOS App Endpoints

After deployment, update your iOS app endpoints:

```swift
// In LiveActivityManager.swift and VideoStreamManager.swift
let serverUrl = "https://your-service-name.onrender.com"
let baseURL = "https://your-service-name.onrender.com"
```

### Other Deployment Options

1. Change `APNS_ENVIRONMENT` to `production`
2. Use production APNs certificates
3. Configure proper logging and monitoring
4. Set up reverse proxy (nginx/Apache)
5. Use environment-specific configuration management

## Security Considerations

- APNs private keys are securely loaded from file system
- All sensitive configuration is via environment variables
- Request validation prevents malformed payloads
- Logging excludes sensitive ride information

## Dependencies

- [HummingBird](https://github.com/hummingbird-project/hummingbird) - Web framework
- [APNSwift](https://github.com/swift-server-community/APNSwift) - Apple Push Notifications
- [Swift-Log](https://github.com/apple/swift-log) - Logging
- [Swift-Crypto](https://github.com/apple/swift-crypto) - Cryptographic operations
- [JWTKit](https://github.com/vapor/jwt-kit) - JWT handling

## License

MIT License
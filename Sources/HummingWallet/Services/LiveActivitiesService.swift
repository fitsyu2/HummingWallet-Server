import APNS
import APNSCore
import Foundation
import Logging
import Crypto

struct EmptyPayload: Codable {}

// Actor for thread-safe activity tracking
actor ActivityTracker {
    private var activeActivities: Set<String> = []
    
    func contains(_ activityId: String) -> Bool {
        return activeActivities.contains(activityId)
    }
    
    func insert(_ activityId: String) {
        activeActivities.insert(activityId)
    }
    
    func remove(_ activityId: String) {
        activeActivities.remove(activityId)
    }
}

class LiveActivitiesService {
    private let logger: Logger
    private let isTestingMode: Bool
    private let hasAPNsConfig: Bool
    
    // Track active activities to prevent duplicates
    private let activityTracker = ActivityTracker()
    
    enum LiveActivitiesError: Error {
        case invalidPushToken
        case invalidPayload
        case apnsError(String)
        case configurationError(String)
        case rideDataParsingError(String)
        case duplicateActivity(String)
    }
    
    init(logger: Logger) {
        self.logger = logger
        
        // Check for APNs configuration - non-throwing version
        let hasAPNsConfig = ProcessInfo.processInfo.environment["APNS_KEY_ID"] != nil &&
                           ProcessInfo.processInfo.environment["APNS_TEAM_ID"] != nil &&
                           ProcessInfo.processInfo.environment["APNS_PRIVATE_KEY_PATH"] != nil
        
        self.hasAPNsConfig = hasAPNsConfig
        
        if hasAPNsConfig {
            // Real APNs setup - validate configuration (non-throwing)
            if let keyId = ProcessInfo.processInfo.environment["APNS_KEY_ID"],
               let teamId = ProcessInfo.processInfo.environment["APNS_TEAM_ID"],
               let keyPath = ProcessInfo.processInfo.environment["APNS_PRIVATE_KEY_PATH"] {
                
                // Check if key file exists
                if FileManager.default.fileExists(atPath: keyPath) {
                    self.isTestingMode = false
                    logger.info("✅ Real APNs configuration validated - Key ID: \(keyId), Team ID: \(teamId)")
                } else {
                    self.isTestingMode = true
                    logger.warning("⚠️ APNs key file not found at: \(keyPath) - falling back to testing mode")
                }
            } else {
                self.isTestingMode = true
                logger.warning("⚠️ APNs environment variables incomplete - falling back to testing mode")
            }
        } else {
            // Testing mode
            self.isTestingMode = true
            logger.warning("⚠️ APNs configuration missing - running in testing mode (notifications will be simulated)")
        }
        
        logger.info("🚀 RideTracker LiveActivitiesService initialized successfully")
    }

    func sendLiveActivity(request: LiveActivityRequest) async throws -> LiveActivityResponse {
        logger.info("Starting ride tracking for activityId: \(request.activityId)")
        
        // Check for duplicate activities
        if await activityTracker.contains(request.activityId) {
            logger.warning("⚠️ Duplicate activity detected: \(request.activityId), skipping")
            throw LiveActivitiesError.duplicateActivity("Activity \(request.activityId) already exists")
        }
        
        await activityTracker.insert(request.activityId)
        
        let rideAlert = try generateRideAlert(from: request.contentState, and: request.attributes, type: .start)
        
        let timestamp = Int(Date().timeIntervalSince1970)
        
        let apsPayload = APSPayload(
            alert: rideAlert,
            timestamp: timestamp,
            event: "update",
            contentState: request.contentState,
            sound: rideAlert.sound
        )
        
        let payload = LiveActivityPayload(
            aps: apsPayload,
            timestamp: timestamp,
            event: "update",
            contentState: request.contentState,
            attributes: request.attributes
        )
        
        return try await sendNotification(
            payload: payload,
            pushToken: request.pushToken,
            activityId: request.activityId,
            priority: request.priority ?? 10
        )
    }
    
    func updateLiveActivity(request: LiveActivityUpdateRequest) async throws -> LiveActivityResponse {
        logger.info("Updating ride status for activityId: \(request.activityId)")
        
        let rideAlert = try generateRideAlert(from: request.contentState, and: nil, type: .update)
        
        let timestamp = Int(Date().timeIntervalSince1970)
        
        let apsPayload = APSPayload(
            alert: rideAlert,
            timestamp: timestamp,
            event: "update",
            contentState: request.contentState,
            sound: rideAlert.sound
        )
        
        let payload = LiveActivityPayload(
            aps: apsPayload,
            timestamp: timestamp,
            event: "update",
            contentState: request.contentState,
            attributes: nil
        )
        
        return try await sendNotification(
            payload: payload,
            pushToken: request.pushToken,
            activityId: request.activityId,
            priority: request.priority ?? 5
        )
    }
    
    func endLiveActivity(request: LiveActivityEndRequest) async throws -> LiveActivityResponse {
        logger.info("Ending ride for activityId: \(request.activityId)")
        
        // Remove from active activities
        await activityTracker.remove(request.activityId)
        
        let rideAlert = try generateRideAlert(from: request.finalContentState ?? "", and: nil, type: .end)
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let dismissalTimestamp = request.dismissalDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
        
        let apsPayload = APSPayload(
            alert: rideAlert,
            timestamp: timestamp,
            event: "end",
            contentState: request.finalContentState,
            sound: rideAlert.sound
        )
        
        let payload = LiveActivityPayload(
            aps: apsPayload,
            timestamp: timestamp,
            event: "end",
            contentState: request.finalContentState,
            attributes: nil
        )
        
        return try await sendNotification(
            payload: payload,
            pushToken: request.pushToken,
            activityId: request.activityId,
            priority: 5,
            dismissalDate: Int(dismissalTimestamp)
        )
    }
    
    // MARK: - Ride-specific Alert Generation
    
    enum AlertType {
        case start
        case update
        case end
    }
    
    private func generateRideAlert(from contentStateData: String, and attributesData: String?, type: AlertType) throws -> LiveActivityAlert {
        
        // Decode the base64 content state
        guard let contentStateJsonData = Data(base64Encoded: contentStateData),
              let contentStateJson = try? JSONSerialization.jsonObject(with: contentStateJsonData) as? [String: Any] else {
            throw LiveActivitiesError.rideDataParsingError("Could not parse content state")
        }
        
        let status = contentStateJson["status"] as? String ?? "unknown"
        let currentStep = contentStateJson["currentStep"] as? String ?? ""
        let fare = contentStateJson["fare"] as? Double
        
        // Decode attributes if available (for initial ride start)
        var driverName = "Your driver"
        var vehicleInfo = "vehicle"
        var dropoffLocation = "your destination"
        
        if let attributesData = attributesData,
           let attributesJsonData = Data(base64Encoded: attributesData),
           let attributesJson = try? JSONSerialization.jsonObject(with: attributesJsonData) as? [String: Any] {
            driverName = attributesJson["driverName"] as? String ?? driverName
            vehicleInfo = attributesJson["vehicleInfo"] as? String ?? vehicleInfo
            dropoffLocation = attributesJson["dropoffLocation"] as? String ?? dropoffLocation
        }
        
        // Generate appropriate alert based on ride status
        switch status {
        case "driver_found":
            return LiveActivityAlert.rideFound(driverName: driverName, vehicleInfo: vehicleInfo)
            
        case "driver_pickup":
            return LiveActivityAlert.driverArriving(driverName: driverName, estimatedTime: "5 minutes")
            
        case "driver_dropoff":
            return LiveActivityAlert.rideStarted(destination: dropoffLocation)
            
        case "completed":
            let fareString = fare != nil ? String(format: "%.2f", fare!) : nil
            return LiveActivityAlert.rideCompleted(fare: fareString)
            
        case "cancelled":
            return LiveActivityAlert.rideCancelled()
            
        default:
            return LiveActivityAlert(
                title: "Ride Update",
                body: currentStep,
                sound: "default"
            )
        }
    }
    
    private func sendNotification(
        payload: LiveActivityPayload,
        pushToken: String,
        activityId: String,
        priority: Int,
        dismissalDate: Int? = nil
    ) async throws -> LiveActivityResponse {
        
        guard isValidPushToken(pushToken) else {
            logger.error("❌ Invalid push token - Length: \(pushToken.count), Token: \(String(pushToken.prefix(16)))...")
            throw LiveActivitiesError.invalidPushToken
        }
        
        logger.info("📱 Valid push token received - Length: \(pushToken.count)")
        logger.info("Sending ride notification for activityId: \(activityId)")
        logger.info("Alert: \(payload.aps.alert?.title ?? "No title") - \(payload.aps.alert?.body ?? "No body")")
        
        if isTestingMode {
            // Testing mode - simulate notification
            logger.info("🧪 Testing mode: Notification simulated")
            return LiveActivityResponse(
                success: true,
                message: "Ride notification sent successfully (simulated)",
                activityId: activityId,
                timestamp: Date()
            )
        } else {
            // Real APNs mode - configuration validated but APNs client implementation pending
            logger.info("🚀 Real APNs mode: Would send real notification here")
            logger.info("📋 APNs Details - Bundle: \(getBundleIdentifier()), Environment: \(getAPNsEnvironment())")
            
            // TODO: Implement actual APNs sending when needed
            return LiveActivityResponse(
                success: true,
                message: "Real APNs notification prepared (implementation pending)",
                activityId: activityId,
                timestamp: Date()
            )
        }
    }
    
    private func isValidPushToken(_ token: String) -> Bool {
        // LiveActivity push tokens can vary in length and format
        // Real device tokens can be up to 200+ characters
        guard !token.isEmpty else { return false }
        guard token.count >= 32 && token.count <= 200 else { return false }
        
        // Check if token contains only valid hex characters
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return token.rangeOfCharacter(from: hexCharacterSet.inverted) == nil
    }
    
    private func getBundleIdentifier() -> String {
        return ProcessInfo.processInfo.environment["BUNDLE_IDENTIFIER"] ?? "fitsyu2.LiveWallet"
    }
    
    private func getAPNsEnvironment() -> String {
        return ProcessInfo.processInfo.environment["APNS_ENVIRONMENT"] ?? "sandbox"
    }
}


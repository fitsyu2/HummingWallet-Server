import Hummingbird
import Logging
import Foundation

// Load environment variables from .env file
func loadEnvironmentVariables() {
    let currentDirectory = FileManager.default.currentDirectoryPath
    let envPath = "\(currentDirectory)/.env"
    
    guard let envContents = try? String(contentsOfFile: envPath) else {
        print("Warning: .env file not found at \(envPath)")
        return
    }
    
    let lines = envContents.components(separatedBy: .newlines)
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty && !trimmedLine.hasPrefix("#") else { continue }
        
        let parts = trimmedLine.components(separatedBy: "=")
        guard parts.count >= 2 else { continue }
        
        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
        
        setenv(key, value, 1)
    }
}

// Load environment variables before starting the server
loadEnvironmentVariables()

let logger = Logger(label: "RideTracker")

let router = Router()

router.get("/health") { _, _ in
    return [
        "status": "ok", 
        "service": "RideTracker API",
        "timestamp": String(Date().timeIntervalSince1970)
    ]
}

let apiGroup = router.group("api/v1")

// Initialize simple video controller
let videoController = SimpleVideoController()

// Add video streaming routes
videoController.addRoutes(to: apiGroup)

// Ride tracking LiveActivity endpoints
apiGroup.post("/liveactivities/send") { request, context in
    return try await LiveActivitiesController.sendLiveActivity(request: request, context: context)
}

apiGroup.post("/liveactivities/update") { request, context in
    return try await LiveActivitiesController.updateLiveActivity(request: request, context: context)
}

apiGroup.post("/liveactivities/end") { request, context in
    return try await LiveActivitiesController.endLiveActivity(request: request, context: context)
}

// Health endpoint with ride-specific info
router.get("/") { _, _ in
    return [
        "service": "RideTracker LiveActivity Server",
        "version": "1.0.0",
        "description": "Real-time ride tracking with iOS LiveActivity support",
        "status": "running",
        "timestamp": String(Date().timeIntervalSince1970)
    ]
}

// Get port from environment variable (for Render deployment) or default to 8080
let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080

let app = Application(
    router: router,
    configuration: .init(
        address: .hostname("0.0.0.0", port: port),
        serverName: "RideTracker"
    ),
    logger: logger
)

logger.info("🚗 RideTracker server starting on http://0.0.0.0:\(port)")
logger.info("📱 Ready to handle LiveActivity ride tracking requests")

try await app.runService()
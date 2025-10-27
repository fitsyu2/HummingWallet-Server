import Foundation
import Hummingbird
import NIOCore

// MARK: - Ride-specific LiveActivity Models

struct LiveActivityRequest: Codable {
    let activityId: String
    let pushToken: String
    let contentState: String
    let attributes: String?
    let alert: LiveActivityAlert?
    let priority: Int?
    let sound: String?
    
    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id"
        case pushToken = "push_token"
        case contentState = "content_state"
        case attributes
        case alert
        case priority
        case sound
    }
}

struct LiveActivityUpdateRequest: Codable {
    let activityId: String
    let pushToken: String
    let contentState: String
    let alert: LiveActivityAlert?
    let priority: Int?
    let sound: String?
    
    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id"
        case pushToken = "push_token"
        case contentState = "content_state"
        case alert
        case priority
        case sound
    }
}

struct LiveActivityEndRequest: Codable {
    let activityId: String
    let pushToken: String
    let finalContentState: String?
    let dismissalDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id"
        case pushToken = "push_token"
        case finalContentState = "final_content_state"
        case dismissalDate = "dismissal_date"
    }
}

struct LiveActivityAlert: Codable {
    let title: String?
    let body: String?
    let sound: String?
    
    init(title: String? = nil, body: String? = nil, sound: String? = nil) {
        self.title = title
        self.body = body
        self.sound = sound
    }
    
    // Ride-specific alert generators
    static func rideFound(driverName: String, vehicleInfo: String) -> LiveActivityAlert {
        return LiveActivityAlert(
            title: "Driver Found! 🚗",
            body: "\(driverName) is heading to pick you up in a \(vehicleInfo)",
            sound: "default"
        )
    }
    
    static func driverArriving(driverName: String, estimatedTime: String) -> LiveActivityAlert {
        return LiveActivityAlert(
            title: "Driver Arriving",
            body: "\(driverName) will arrive in \(estimatedTime)",
            sound: "default"
        )
    }
    
    static func rideStarted(destination: String) -> LiveActivityAlert {
        return LiveActivityAlert(
            title: "Ride Started",
            body: "On your way to \(destination)",
            sound: "default"
        )
    }
    
    static func rideCompleted(fare: String? = nil) -> LiveActivityAlert {
        let body = fare != nil ? "You've arrived! Fare: $\(fare!)" : "You've arrived at your destination!"
        return LiveActivityAlert(
            title: "Ride Completed ✅",
            body: body,
            sound: "default"
        )
    }
    
    static func rideCancelled(reason: String = "by driver") -> LiveActivityAlert {
        return LiveActivityAlert(
            title: "Ride Cancelled",
            body: "Your ride was cancelled \(reason)",
            sound: "default"
        )
    }
}

struct LiveActivityResponse: Codable {
    let success: Bool
    let message: String
    let activityId: String?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case activityId = "activity_id"
        case timestamp
    }
}

extension LiveActivityResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(self)
        return Response(
            status: success ? .ok : .badRequest,
            headers: [.contentType: "application/json"],
            body: .init(contentLength: data.count) { writer in
                try await writer.write(ByteBuffer(data: data))
            }
        )
    }
}

struct LiveActivityPayload: Codable {
    let aps: APSPayload
    let timestamp: Int
    let event: String
    let contentState: String?
    let attributes: String?
    
    enum CodingKeys: String, CodingKey {
        case aps
        case timestamp
        case event
        case contentState = "content-state"
        case attributes
    }
}

struct APSPayload: Codable {
    let alert: LiveActivityAlert?
    let timestamp: Int
    let event: String
    let contentState: String?
    let sound: String?
    
    enum CodingKeys: String, CodingKey {
        case alert
        case timestamp
        case event
        case contentState = "content-state"
        case sound
    }
}
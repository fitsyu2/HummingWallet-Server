//
//  RealtimeStreamController.swift
//  HummingWallet
//
//  Simplified real-time streaming without persistent storage
//  Perfect for live ride tracking with no recording needs
//

import Foundation
import Hummingbird
import Logging
import NIO

// MARK: - Response Models

struct StreamResponse: Codable {
    let success: Bool
    let rideId: String
    let streamUrl: String?
    let status: String
    let message: String?
}

extension StreamResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(contentLength: data.count) { writer in
                try await writer.write(ByteBuffer(data: data))
            }
        )
    }
}

struct StreamStatus: Codable {
    let rideId: String
    let isActive: Bool
    let streamUrl: String?
    let startTime: TimeInterval?
    let viewerCount: Int
}

extension StreamStatus: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(contentLength: data.count) { writer in
                try await writer.write(ByteBuffer(data: data))
            }
        )
    }
}

// MARK: - Real-time Stream Session

class StreamSession {
    let rideId: String
    let startTime: Date
    var isActive: Bool
    var viewers: Set<String> = []
    var lastActivity: Date
    
    init(rideId: String) {
        self.rideId = rideId
        self.startTime = Date()
        self.isActive = true
        self.lastActivity = Date()
    }
    
    func addViewer(_ viewerId: String) {
        viewers.insert(viewerId)
        lastActivity = Date()
    }
    
    func removeViewer(_ viewerId: String) {
        viewers.remove(viewerId)
        lastActivity = Date()
    }
}

// MARK: - Real-time Stream Controller

class RealtimeStreamController {
    private let logger = Logger(label: "realtime-stream")
    private var activeSessions: [String: StreamSession] = [:]
    private let baseURL: String
    
    init() {
        // Get base URL from environment or use Railway default
        self.baseURL = ProcessInfo.processInfo.environment["RAILWAY_STATIC_URL"] ?? 
                      "https://hummingwallet-server-production.up.railway.app"
        logger.info("🎬 RealtimeStreamController initialized with base URL: \(baseURL)")
    }
    
    // MARK: - Route Configuration
    
    func addRoutes(to group: RouterGroup<some RequestContext>) {
        // Start real-time stream
        group.post("stream/:rideId/start", use: startStream)
        
        // Stop real-time stream
        group.post("stream/:rideId/stop", use: stopStream)
        
        // Join stream as viewer
        group.post("stream/:rideId/join", use: joinStream)
        
        // Leave stream
        group.post("stream/:rideId/leave", use: leaveStream)
        
        // Get stream status
        group.get("stream/:rideId/status", use: getStreamStatus)
        
        // Get all active streams
        group.get("stream/active", use: getActiveStreams)
        
        // Simple real-time endpoint for live updates
        group.get("stream/:rideId/live", use: getLiveStream)
    }
    
    // MARK: - Route Handlers
    
    /// Start a real-time stream for a ride
    @Sendable
    func startStream(_ request: Request, context: some RequestContext) async throws -> StreamResponse {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        logger.info("🚀 Starting real-time stream for ride: \(rideId)")
        
        let session = StreamSession(rideId: rideId)
        activeSessions[rideId] = session
        
        let streamUrl = "\(baseURL)/api/v1/stream/\(rideId)/live"
        
        return StreamResponse(
            success: true,
            rideId: rideId,
            streamUrl: streamUrl,
            status: "active",
            message: "Real-time stream started successfully"
        )
    }
    
    /// Stop a real-time stream
    @Sendable
    func stopStream(_ request: Request, context: some RequestContext) async throws -> StreamResponse {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        logger.info("🛑 Stopping real-time stream for ride: \(rideId)")
        
        if let session = activeSessions[rideId] {
            session.isActive = false
            // Remove session after a brief delay to allow viewers to disconnect
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                activeSessions.removeValue(forKey: rideId)
                logger.info("🧹 Cleaned up session for ride: \(rideId)")
            }
        }
        
        return StreamResponse(
            success: true,
            rideId: rideId,
            streamUrl: nil,
            status: "stopped",
            message: "Real-time stream stopped"
        )
    }
    
    /// Join a stream as a viewer
    @Sendable
    func joinStream(_ request: Request, context: some RequestContext) async throws -> StreamResponse {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        guard let session = activeSessions[rideId], session.isActive else {
            throw HTTPError(.notFound, message: "No active stream found for ride")
        }
        
        // Generate a viewer ID (could be from request headers/auth in production)
        let viewerId = UUID().uuidString
        session.addViewer(viewerId)
        
        logger.info("👀 Viewer \(viewerId) joined stream for ride: \(rideId)")
        
        return StreamResponse(
            success: true,
            rideId: rideId,
            streamUrl: "\(baseURL)/api/v1/stream/\(rideId)/live",
            status: "viewing",
            message: "Successfully joined stream"
        )
    }
    
    /// Leave a stream
    @Sendable
    func leaveStream(_ request: Request, context: some RequestContext) async throws -> StreamResponse {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        // In a real implementation, you'd get viewer ID from auth/session
        logger.info("👋 Viewer left stream for ride: \(rideId)")
        
        return StreamResponse(
            success: true,
            rideId: rideId,
            streamUrl: nil,
            status: "left",
            message: "Successfully left stream"
        )
    }
    
    /// Get stream status
    @Sendable
    func getStreamStatus(_ request: Request, context: some RequestContext) async throws -> StreamStatus {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        if let session = activeSessions[rideId], session.isActive {
            return StreamStatus(
                rideId: rideId,
                isActive: true,
                streamUrl: "\(baseURL)/api/v1/stream/\(rideId)/live",
                startTime: session.startTime.timeIntervalSince1970,
                viewerCount: session.viewers.count
            )
        } else {
            return StreamStatus(
                rideId: rideId,
                isActive: false,
                streamUrl: nil,
                startTime: nil,
                viewerCount: 0
            )
        }
    }
    
    /// Get all active streams
    @Sendable
    func getActiveStreams(_ request: Request, context: some RequestContext) async throws -> Response {
        let activeStreams = activeSessions.values.filter { $0.isActive }.map { session in
            [
                "rideId": session.rideId,
                "startTime": session.startTime.timeIntervalSince1970,
                "viewerCount": session.viewers.count,
                "streamUrl": "\(baseURL)/api/v1/stream/\(session.rideId)/live"
            ]
        }
        
        let result: [String: Any] = [
            "activeStreams": activeStreams,
            "totalCount": activeStreams.count,
            "serverTime": Date().timeIntervalSince1970
        ]
        
        let data = try JSONSerialization.data(withJSONObject: result)
        
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(contentLength: data.count) { writer in
                try await writer.write(ByteBuffer(data: data))
            }
        )
    }
    
    /// Simple live stream endpoint (for real-time updates)
    @Sendable
    func getLiveStream(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        guard let session = activeSessions[rideId], session.isActive else {
            throw HTTPError(.notFound, message: "No active stream for ride")
        }
        
        // Simple JSON response for real-time updates
        let liveData: [String: Any] = [
            "rideId": rideId,
            "status": "live",
            "timestamp": Date().timeIntervalSince1970,
            "viewerCount": session.viewers.count,
            "message": "Live stream is active"
        ]
        
        let data = try JSONSerialization.data(withJSONObject: liveData)
        
        return Response(
            status: .ok,
            headers: [
                .contentType: "application/json",
                .cacheControl: "no-cache, no-store, must-revalidate"
            ],
            body: .init(contentLength: data.count) { writer in
                try await writer.write(ByteBuffer(data: data))
            }
        )
    }
}
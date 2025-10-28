//
//  VideoForwardingController.swift
//  HummingWallet
//
//  Video forwarding for real-time camera streaming
//  iPhone camera → Server → iPhone simulator
//

import Foundation
import Hummingbird
import Logging
import NIO
import MultipartKit

// MARK: - Video Stream Models

struct VideoStreamInfo: Codable {
    let streamId: String
    let quality: String
    let isActive: Bool
    let viewerCount: Int
    let startTime: TimeInterval
}

struct VideoForwardResponse: Codable {
    let success: Bool
    let streamId: String
    let message: String
    let streamUrl: String?
    let viewerCount: Int?
}

extension VideoForwardResponse: ResponseGenerator {
    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let encoder = JSONEncoder()
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

// MARK: - Video Stream Session

class VideoStreamSession {
    let streamId: String
    let startTime: Date
    var isActive: Bool = true
    var viewers: Set<String> = []
    var lastFrameData: Data?
    var frameCount: Int = 0
    var bytesReceived: Int = 0
    var lastActivity: Date
    
    init(streamId: String) {
        self.streamId = streamId
        self.startTime = Date()
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
    
    func updateFrame(_ data: Data) {
        lastFrameData = data
        frameCount += 1
        bytesReceived += data.count
        lastActivity = Date()
    }
}

// MARK: - Video Forwarding Controller

class VideoForwardingController {
    private let logger = Logger(label: "video-forwarding")
    private var activeStreams: [String: VideoStreamSession] = [:]
    private let baseURL: String
    
    init() {
        self.baseURL = ProcessInfo.processInfo.environment["RAILWAY_STATIC_URL"] ?? 
                      "https://hummingwallet-server-production.up.railway.app"
        logger.info("📹 VideoForwardingController initialized")
    }
    
    // MARK: - Route Configuration
    
    func addRoutes(to group: RouterGroup<some RequestContext>) {
        // Start video stream
        group.post("video/:streamId/start", use: startVideoStream)
        
        // Stop video stream
        group.post("video/:streamId/stop", use: stopVideoStream)
        
        // Upload video frame (from camera)
        group.post("video/:streamId/frame", use: uploadVideoFrame)
        
        // Get latest frame (for viewers)
        group.get("video/:streamId/frame", use: getLatestFrame)
        
        // Join as viewer
        group.post("video/:streamId/join", use: joinAsViewer)
        
        // Leave stream
        group.post("video/:streamId/leave", use: leaveStream)
        
        // Get stream info
        group.get("video/:streamId/info", use: getStreamInfo)
        
        // List active streams
        group.get("video/active", use: getActiveStreams)
        
        // Stream statistics
        group.get("video/:streamId/stats", use: getStreamStats)
    }
    
    // MARK: - Route Handlers
    
    /// Start a video stream
    @Sendable
    func startVideoStream(_ request: Request, context: some RequestContext) async throws -> VideoForwardResponse {
        guard let streamId = context.parameters.get("streamId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing stream ID")
        }
        
        logger.info("🎬 Starting video stream: \(streamId)")
        
        let session = VideoStreamSession(streamId: streamId)
        activeStreams[streamId] = session
        
        return VideoForwardResponse(
            success: true,
            streamId: streamId,
            message: "Video stream started successfully",
            streamUrl: "\(baseURL)/api/v1/video/\(streamId)/frame",
            viewerCount: 0
        )
    }
    
    /// Stop a video stream
    @Sendable
    func stopVideoStream(_ request: Request, context: some RequestContext) async throws -> VideoForwardResponse {
        guard let streamId = context.parameters.get("streamId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing stream ID")
        }
        
        logger.info("🛑 Stopping video stream: \(streamId)")
        
        if let session = activeStreams[streamId] {
            session.isActive = false
            // Clean up after 30 seconds
            Task {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                activeStreams.removeValue(forKey: streamId)
                logger.info("🧹 Cleaned up stream: \(streamId)")
            }
        }
        
        return VideoForwardResponse(
            success: true,
            streamId: streamId,
            message: "Video stream stopped",
            streamUrl: nil,
            viewerCount: 0
        )
    }
    
    /// Upload video frame (from iPhone camera)
    @Sendable
    func uploadVideoFrame(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let streamId = context.parameters.get("streamId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing stream ID")
        }
        
        guard let session = activeStreams[streamId], session.isActive else {
            throw HTTPError(.notFound, message: "Stream not found or inactive")
        }
        
        // Read the raw video frame data
        let body = try await request.body.collect(upTo: 10 * 1024 * 1024) // 10MB max
        let frameData = Data(buffer: body)
        
        // Update session with new frame
        session.updateFrame(frameData)
        
        logger.info("📸 Received frame for stream \(streamId): \(frameData.count) bytes, total frames: \(session.frameCount)")
        
        let response = [
            "success": true,
            "streamId": streamId,
            "frameNumber": session.frameCount,
            "frameSize": frameData.count,
            "viewerCount": session.viewers.count
        ] as [String: Any]
        
        let data = try JSONSerialization.data(withJSONObject: response)
        
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(contentLength: data.count) { writer in
                try await writer.write(ByteBuffer(data: data))
            }
        )
    }
    
    /// Get latest frame (for viewers like simulator)
    @Sendable
    func getLatestFrame(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let streamId = context.parameters.get("streamId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing stream ID")
        }
        
        guard let session = activeStreams[streamId], session.isActive else {
            throw HTTPError(.notFound, message: "Stream not found or inactive")
        }
        
        guard let frameData = session.lastFrameData else {
            throw HTTPError(.notFound, message: "No frame data available")
        }
        
        logger.info("📺 Serving frame for stream \(streamId): \(frameData.count) bytes to viewer")
        
        return Response(
            status: .ok,
            headers: [
                .contentType: "image/jpeg", // Assuming JPEG frames
                .cacheControl: "no-cache, no-store, must-revalidate"
            ],
            body: .init(contentLength: frameData.count) { writer in
                try await writer.write(ByteBuffer(data: frameData))
            }
        )
    }
    
    /// Join as viewer
    @Sendable
    func joinAsViewer(_ request: Request, context: some RequestContext) async throws -> VideoForwardResponse {
        guard let streamId = context.parameters.get("streamId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing stream ID")
        }
        
        guard let session = activeStreams[streamId], session.isActive else {
            throw HTTPError(.notFound, message: "Stream not found or inactive")
        }
        
        let viewerId = UUID().uuidString
        session.addViewer(viewerId)
        
        logger.info("👀 Viewer \(viewerId) joined stream \(streamId)")
        
        return VideoForwardResponse(
            success: true,
            streamId: streamId,
            message: "Successfully joined stream",
            streamUrl: "\(baseURL)/api/v1/video/\(streamId)/frame",
            viewerCount: session.viewers.count
        )
    }
    
    /// Leave stream
    @Sendable
    func leaveStream(_ request: Request, context: some RequestContext) async throws -> VideoForwardResponse {
        guard let streamId = context.parameters.get("streamId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing stream ID")
        }
        
        logger.info("👋 Viewer left stream \(streamId)")
        
        return VideoForwardResponse(
            success: true,
            streamId: streamId,
            message: "Successfully left stream",
            streamUrl: nil,
            viewerCount: nil
        )
    }
    
    /// Get stream info
    @Sendable
    func getStreamInfo(_ request: Request, context: some RequestContext) async throws -> VideoStreamInfo {
        guard let streamId = context.parameters.get("streamId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing stream ID")
        }
        
        if let session = activeStreams[streamId], session.isActive {
            return VideoStreamInfo(
                streamId: streamId,
                quality: "auto",
                isActive: true,
                viewerCount: session.viewers.count,
                startTime: session.startTime.timeIntervalSince1970
            )
        } else {
            return VideoStreamInfo(
                streamId: streamId,
                quality: "none",
                isActive: false,
                viewerCount: 0,
                startTime: 0
            )
        }
    }
    
    /// Get active streams
    @Sendable
    func getActiveStreams(_ request: Request, context: some RequestContext) async throws -> Response {
        let activeStreamsList = activeStreams.values.filter { $0.isActive }.map { session in
            [
                "streamId": session.streamId,
                "viewerCount": session.viewers.count,
                "frameCount": session.frameCount,
                "bytesReceived": session.bytesReceived,
                "startTime": session.startTime.timeIntervalSince1970,
                "streamUrl": "\(baseURL)/api/v1/video/\(session.streamId)/frame"
            ]
        }
        
        let result: [String: Any] = [
            "activeStreams": activeStreamsList,
            "totalStreams": activeStreamsList.count,
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
    
    /// Get stream statistics
    @Sendable
    func getStreamStats(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let streamId = context.parameters.get("streamId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing stream ID")
        }
        
        guard let session = activeStreams[streamId] else {
            throw HTTPError(.notFound, message: "Stream not found")
        }
        
        let duration = Date().timeIntervalSince(session.startTime)
        let avgFrameSize = session.frameCount > 0 ? session.bytesReceived / session.frameCount : 0
        let bytesPerSecond = duration > 0 ? Double(session.bytesReceived) / duration : 0
        
        let stats: [String: Any] = [
            "streamId": streamId,
            "isActive": session.isActive,
            "duration": duration,
            "frameCount": session.frameCount,
            "bytesReceived": session.bytesReceived,
            "avgFrameSize": avgFrameSize,
            "bytesPerSecond": bytesPerSecond,
            "viewerCount": session.viewers.count,
            "hasLatestFrame": session.lastFrameData != nil
        ]
        
        let data = try JSONSerialization.data(withJSONObject: stats)
        
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(contentLength: data.count) { writer in
                try await writer.write(ByteBuffer(data: data))
            }
        )
    }
}

extension VideoStreamInfo: ResponseGenerator {
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
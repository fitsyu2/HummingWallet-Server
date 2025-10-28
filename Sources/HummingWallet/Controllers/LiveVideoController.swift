//
//  LiveVideoController.swift
//  HummingWallet
//
//  Enhanced video controller for receiving and forwarding live video streams
//

import Foundation
import Hummingbird
import Logging
import NIO
import MultipartKit

// MARK: - Video Stream Models

struct VideoUploadRequest: Codable {
    let rideId: String
    let segmentNumber: Int
    let timestamp: Double
}

struct LiveStreamStatus: Codable {
    let rideId: String
    let isLive: Bool
    let segmentCount: Int
    let lastUpdate: Double
    let viewerCount: Int
}

// MARK: - Live Video Controller

class LiveVideoController {
    private let logger = Logger(label: "live-video-controller")
    private var activeStreams: [String: StreamSession] = [:]
    private let segmentStorage = SegmentStorage()
    
    // MARK: - Stream Session Management
    
    private class StreamSession {
        let rideId: String
        var segments: [VideoSegment] = []
        var lastActivity: Date = Date()
        var viewers: Set<String> = []
        var isActive: Bool = true
        
        init(rideId: String) {
            self.rideId = rideId
        }
        
        func addSegment(_ segment: VideoSegment) {
            segments.append(segment)
            lastActivity = Date()
            
            // Keep only last 10 segments for HLS sliding window
            if segments.count > 10 {
                segments.removeFirst()
            }
        }
        
        func generatePlaylist() -> String {
            let targetDuration = segments.map(\.duration).max() ?? 10.0
            let mediaSequence = max(0, segments.count - 10)
            
            var playlist = """
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:\(Int(ceil(targetDuration)))
#EXT-X-MEDIA-SEQUENCE:\(mediaSequence)

"""
            
            for segment in segments {
                playlist += "#EXTINF:\(String(format: "%.1f", segment.duration)),\n"
                playlist += "segment/\(segment.filename)\n"
            }
            
            if !isActive {
                playlist += "#EXT-X-ENDLIST\n"
            }
            
            return playlist
        }
    }
    
    struct VideoSegment {
        let filename: String
        let duration: Double
        let timestamp: Date
        let data: Data
    }
    
    // MARK: - Route Configuration
    
    func addRoutes(to group: RouterGroup<some RequestContext>) {
        // Live stream upload endpoint - receive video segments
        group.post("video/live/:rideId/upload", use: uploadVideoSegment)
        
        // Live stream playlist endpoint - serve HLS playlist
        group.get("video/live/:rideId/stream.m3u8", use: getLiveStreamPlaylist)
        
        // Serve video segments
        group.get("video/live/:rideId/segment/:filename", use: getVideoSegment)
        
        // Start live stream session
        group.post("video/live/:rideId/start", use: startLiveStream)
        
        // Stop live stream session
        group.post("video/live/:rideId/stop", use: stopLiveStream)
        
        // Get live stream status
        group.get("video/live/:rideId/status", use: getLiveStreamStatus)
        
        // WebRTC signaling for real-time communication
        group.post("video/live/:rideId/signal", use: handleWebRTCSignaling)
        
        // Get list of active streams
        group.get("video/live/active", use: getActiveStreams)
    }
    
    // MARK: - Route Handlers
    
    /// Upload video segment for live streaming
    @Sendable
    func uploadVideoSegment(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        // Parse multipart form data for video segment
        guard let contentType = request.headers[.contentType],
              contentType.contains("multipart/form-data") else {
            throw HTTPError(.badRequest, message: "Expected multipart/form-data")
        }
        
        let body = try await request.body.collect(upTo: 50 * 1024 * 1024) // 50MB limit
        
        // Parse multipart data (simplified - you'd want a proper multipart parser)
        guard let segmentData = extractVideoSegment(from: body) else {
            throw HTTPError(.badRequest, message: "No video segment found")
        }
        
        // Get or create stream session
        let session = getOrCreateStreamSession(for: rideId)
        
        // Generate segment filename
        let segmentNumber = session.segments.count
        let filename = "segment\(segmentNumber).ts"
        
        // Create video segment
        let segment = VideoSegment(
            filename: filename,
            duration: 10.0, // Default 10 second segments
            timestamp: Date(),
            data: segmentData
        )
        
        // Store segment
        session.addSegment(segment)
        segmentStorage.store(segment: segment, for: rideId)
        
        logger.info("📹 Uploaded video segment \(filename) for ride \(rideId) (\(segmentData.count) bytes)")
        
        return try JSONResponse([
            "success": true,
            "rideId": rideId,
            "segmentNumber": segmentNumber,
            "filename": filename,
            "size": segmentData.count
        ]).response(from: request, context: context)
    }
    
    /// Get live stream HLS playlist
    @Sendable
    func getLiveStreamPlaylist(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        guard let session = activeStreams[rideId] else {
            throw HTTPError(.notFound, message: "No active stream for ride")
        }
        
        let playlist = session.generatePlaylist()
        let data = Data(playlist.utf8)
        
        return Response(
            status: .ok,
            headers: [
                .contentType: "application/vnd.apple.mpegurl",
                .cacheControl: "no-cache, no-store, must-revalidate"
            ],
            body: .init(contentLength: data.count) { writer in
                try await writer.write(ByteBuffer(data: data))
            }
        )
    }
    
    /// Serve individual video segments
    @Sendable
    func getVideoSegment(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let rideId = context.parameters.get("rideId", as: String.self),
              let filename = context.parameters.get("filename", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID or filename")
        }
        
        guard let segmentData = segmentStorage.retrieve(filename: filename, for: rideId) else {
            throw HTTPError(.notFound, message: "Video segment not found")
        }
        
        return Response(
            status: .ok,
            headers: [
                .contentType: "video/mp2t", // MPEG-TS format for HLS
                .cacheControl: "max-age=10"
            ],
            body: .init(contentLength: segmentData.count) { writer in
                try await writer.write(ByteBuffer(data: segmentData))
            }
        )
    }
    
    /// Start live stream session
    @Sendable
    func startLiveStream(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        let session = getOrCreateStreamSession(for: rideId)
        session.isActive = true
        
        logger.info("🎬 Started live stream for ride: \(rideId)")
        
        return try JSONResponse([
            "success": true,
            "rideId": rideId,
            "streamUrl": "/api/v1/video/live/\(rideId)/stream.m3u8",
            "status": "started"
        ]).response(from: request, context: context)
    }
    
    /// Stop live stream session
    @Sendable
    func stopLiveStream(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        if let session = activeStreams[rideId] {
            session.isActive = false
            
            // Clean up after 1 hour
            Task {
                try await Task.sleep(nanoseconds: 3600_000_000_000) // 1 hour
                activeStreams.removeValue(forKey: rideId)
                segmentStorage.cleanup(for: rideId)
            }
        }
        
        logger.info("🛑 Stopped live stream for ride: \(rideId)")
        
        return try JSONResponse([
            "success": true,
            "rideId": rideId,
            "status": "stopped"
        ]).response(from: request, context: context)
    }
    
    /// Get live stream status
    @Sendable
    func getLiveStreamStatus(_ request: Request, context: some RequestContext) async throws -> LiveStreamStatus {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        let session = activeStreams[rideId]
        
        return LiveStreamStatus(
            rideId: rideId,
            isLive: session?.isActive ?? false,
            segmentCount: session?.segments.count ?? 0,
            lastUpdate: session?.lastActivity.timeIntervalSince1970 ?? 0,
            viewerCount: session?.viewers.count ?? 0
        )
    }
    
    /// Handle WebRTC signaling for real-time video
    @Sendable
    func handleWebRTCSignaling(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        // Parse WebRTC signaling data
        let body = try await request.body.collect(upTo: 1024 * 1024) // 1MB limit
        guard let _ = try? JSONSerialization.jsonObject(with: Data(buffer: body)) as? [String: Any] else {
            throw HTTPError(.badRequest, message: "Invalid signaling data")
        }
        
        // Process signaling (offer, answer, ICE candidates)
        logger.info("📡 Processing WebRTC signaling for ride: \(rideId)")
        
        // In a real implementation, you'd relay this to connected viewers
        return try JSONResponse([
            "success": true,
            "rideId": rideId,
            "type": "signaling_processed"
        ]).response(from: request, context: context)
    }
    
    /// Get list of active streams
    @Sendable
    func getActiveStreams(_ request: Request, context: some RequestContext) async throws -> Response {
        let activeStreamList = activeStreams.map { (rideId, session) in
            [
                "rideId": rideId,
                "isActive": session.isActive,
                "segmentCount": session.segments.count,
                "viewerCount": session.viewers.count,
                "lastActivity": session.lastActivity.timeIntervalSince1970
            ]
        }
        
        return try JSONResponse([
            "activeStreams": activeStreamList,
            "totalCount": activeStreamList.count
        ]).response(from: request, context: context)
    }
    
    // MARK: - Helper Methods
    
    private func getOrCreateStreamSession(for rideId: String) -> StreamSession {
        if let existing = activeStreams[rideId] {
            return existing
        }
        
        let session = StreamSession(rideId: rideId)
        activeStreams[rideId] = session
        return session
    }
    
    private func extractVideoSegment(from buffer: ByteBuffer) -> Data? {
        // Simplified multipart parsing - in production use proper multipart library
        let data = Data(buffer: buffer)
        
        // Look for video content (this is a simplified approach)
        // In production, you'd properly parse multipart boundaries
        if data.count > 1000 { // Minimum reasonable segment size
            return data
        }
        
        return nil
    }
}

// MARK: - Support Classes

/// Simple in-memory segment storage (in production, use disk storage or cloud storage)
private class SegmentStorage {
    private var segments: [String: [String: Data]] = [:]
    
    func store(segment: LiveVideoController.VideoSegment, for rideId: String) {
        if segments[rideId] == nil {
            segments[rideId] = [:]
        }
        segments[rideId]![segment.filename] = segment.data
    }
    
    func retrieve(filename: String, for rideId: String) -> Data? {
        return segments[rideId]?[filename]
    }
    
    func cleanup(for rideId: String) {
        segments.removeValue(forKey: rideId)
    }
}

// MARK: - Response Helpers

extension LiveStreamStatus: ResponseGenerator {
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

private struct JSONResponse: ResponseGenerator {
    let data: [String: Any]
    
    init(_ data: [String: Any]) {
        self.data = data
    }
    
    func response(from request: Request, context: some RequestContext) throws -> Response {
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(contentLength: jsonData.count) { writer in
                try await writer.write(ByteBuffer(data: jsonData))
            }
        )
    }
}
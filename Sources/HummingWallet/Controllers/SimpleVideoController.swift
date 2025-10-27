//
//  SimpleVideoController.swift
//  HummingWallet
//
//  Created by System on 23/10/25.
//

import Foundation
import Hummingbird
import Logging
import NIO

// MARK: - Video Response Models

struct VideoStreamResponse: Codable {
    let success: Bool
    let rideId: String
    let streamUrl: String?
    let status: String?
}

struct VideoStatusResponse: Codable {
    let rideId: String
    let isActive: Bool
    let streamUrl: String?
    let status: String
}

// MARK: - ResponseGenerator Extensions

extension VideoStreamResponse: ResponseGenerator {
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

extension VideoStatusResponse: ResponseGenerator {
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

/// Simple controller for basic video streaming endpoints
struct SimpleVideoController {
    private let logger = Logger(label: "simple-video-controller")
    
    /// Configure video streaming routes
    func addRoutes(to group: RouterGroup<some RequestContext>) {
        // HLS playlist endpoint
        group.get("video/ride/:rideId/stream.m3u8", use: getHLSPlaylist)
        
        // Start video stream for a ride
        group.post("video/ride/:rideId/start", use: startVideoStream)
        
        // Stop video stream for a ride
        group.post("video/ride/:rideId/stop", use: stopVideoStream)
        
        // Get stream status
        group.get("video/ride/:rideId/status", use: getStreamStatus)
        
        // Demo video stream (for testing)
        group.get("video/demo/stream.m3u8", use: getDemoHLSPlaylist)
    }
    
    // MARK: - Route Handlers
    
    /// Get HLS playlist for a specific ride
    @Sendable
    func getHLSPlaylist(_ request: Request, context: some RequestContext) async throws -> Response {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        logger.info("Serving HLS playlist for ride: \(rideId)")
        
        // Simple demo playlist
        let playlistContent = """
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
https://church-seek-cloudy-intelligent.trycloudflare.com/api/v1/video/demo/segment/segment0.ts
#EXTINF:10.0,
https://church-seek-cloudy-intelligent.trycloudflare.com/api/v1/video/demo/segment/segment1.ts
#EXT-X-ENDLIST
"""
        
        let data = Data(playlistContent.utf8)
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
    
    /// Start video streaming for a ride
    @Sendable
    func startVideoStream(_ request: Request, context: some RequestContext) async throws -> VideoStreamResponse {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        logger.info("Starting video stream for ride: \(rideId)")
        
        return VideoStreamResponse(
            success: true,
            rideId: rideId,
            streamUrl: "https://church-seek-cloudy-intelligent.trycloudflare.com/api/v1/video/ride/\(rideId)/stream.m3u8",
            status: "started"
        )
    }
    
    /// Stop video streaming for a ride
    @Sendable
    func stopVideoStream(_ request: Request, context: some RequestContext) async throws -> VideoStreamResponse {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        logger.info("Stopping video stream for ride: \(rideId)")
        
        return VideoStreamResponse(
            success: true,
            rideId: rideId,
            streamUrl: nil,
            status: "stopped"
        )
    }
    
    /// Get stream status for a ride
    @Sendable
    func getStreamStatus(_ request: Request, context: some RequestContext) async throws -> VideoStatusResponse {
        guard let rideId = context.parameters.get("rideId", as: String.self) else {
            throw HTTPError(.badRequest, message: "Missing ride ID")
        }
        
        return VideoStatusResponse(
            rideId: rideId,
            isActive: true,
            streamUrl: "https://church-seek-cloudy-intelligent.trycloudflare.com/api/v1/video/ride/\(rideId)/stream.m3u8",
            status: "streaming"
        )
    }
    
    /// Get demo HLS playlist (for testing)
    @Sendable
    func getDemoHLSPlaylist(_ request: Request, context: some RequestContext) async throws -> Response {
        logger.info("Serving demo HLS playlist")
        
        let playlistContent = """
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:10.0,
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4
#EXT-X-ENDLIST
"""
        
        let data = Data(playlistContent.utf8)
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
}
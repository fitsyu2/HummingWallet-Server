import Hummingbird
import Foundation
import Logging

struct LiveActivitiesController {
    private static let service: LiveActivitiesService = {
        let logger = Logger(label: "RideTracker.LiveActivitiesController")
        return LiveActivitiesService(logger: logger)
    }()
    
    static func sendLiveActivity(request: Request, context: some RequestContext) async throws -> LiveActivityResponse {
        let logger = Logger(label: "RideTracker.sendLiveActivity")
        
        do {
            let requestData = try await request.body.collect(upTo: 1024 * 1024) // 1MB limit
            let liveActivityRequest = try JSONDecoder().decode(LiveActivityRequest.self, from: Data(buffer: requestData))
            
            // Log ride start details
            if let attributesData = liveActivityRequest.attributes,
               let decodedData = Data(base64Encoded: attributesData),
               let attributes = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] {
                let driverName = attributes["driverName"] as? String ?? "Unknown"
                let rideType = attributes["rideType"] as? String ?? "unknown"
                let pickup = attributes["pickupLocation"] as? String ?? "Unknown"
                let dropoff = attributes["dropoffLocation"] as? String ?? "Unknown"
                
                logger.info("Starting ride: Driver=\(driverName), Type=\(rideType), From=\(pickup), To=\(dropoff)")
            }
            
            let response = try await service.sendLiveActivity(request: liveActivityRequest)
            logger.info("Successfully started ride tracking for activityId: \(liveActivityRequest.activityId)")
            
            return response
            
        } catch let decodingError as DecodingError {
            logger.error("Failed to decode ride request: \(decodingError)")
            return LiveActivityResponse(
                success: false,
                message: "Invalid ride request format: \(decodingError.localizedDescription)",
                activityId: nil,
                timestamp: Date()
            )
        } catch let serviceError as LiveActivitiesService.LiveActivitiesError {
            logger.error("RideTracker service error: \(serviceError)")
            
            let message: String
            switch serviceError {
            case .duplicateActivity(let activityId):
                message = "Duplicate ride request - activity \(activityId) already exists"
            default:
                message = "Ride tracking error: \(serviceError.localizedDescription)"
            }
            
            return LiveActivityResponse(
                success: false,
                message: message,
                activityId: nil,
                timestamp: Date()
            )
        } catch {
            logger.error("Unexpected ride tracking error: \(error)")
            return LiveActivityResponse(
                success: false,
                message: "Unexpected ride error: \(error.localizedDescription)",
                activityId: nil,
                timestamp: Date()
            )
        }
    }
    
    static func updateLiveActivity(request: Request, context: some RequestContext) async throws -> LiveActivityResponse {
        let logger = Logger(label: "RideTracker.updateLiveActivity")
        
        do {
            let requestData = try await request.body.collect(upTo: 1024 * 1024) // 1MB limit
            let updateRequest = try JSONDecoder().decode(LiveActivityUpdateRequest.self, from: Data(buffer: requestData))
            
            // Log ride status update
            if let contentData = Data(base64Encoded: updateRequest.contentState),
               let content = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
                let status = content["status"] as? String ?? "unknown"
                let step = content["currentStep"] as? String ?? "unknown"
                let progress = content["progress"] as? Double ?? 0.0
                
                logger.info("Ride update: Status=\(status), Step=\(step), Progress=\(Int(progress * 100))%")
            }
            
            let response = try await service.updateLiveActivity(request: updateRequest)
            logger.info("Successfully updated ride status for activityId: \(updateRequest.activityId)")
            
            return response
            
        } catch let decodingError as DecodingError {
            logger.error("Failed to decode ride update request: \(decodingError)")
            return LiveActivityResponse(
                success: false,
                message: "Invalid ride update format: \(decodingError.localizedDescription)",
                activityId: nil,
                timestamp: Date()
            )
        } catch let serviceError as LiveActivitiesService.LiveActivitiesError {
            logger.error("RideTracker service error: \(serviceError)")
            return LiveActivityResponse(
                success: false,
                message: "Ride update error: \(serviceError.localizedDescription)",
                activityId: nil,
                timestamp: Date()
            )
        } catch {
            logger.error("Unexpected ride update error: \(error)")
            return LiveActivityResponse(
                success: false,
                message: "Unexpected ride update error: \(error.localizedDescription)",
                activityId: nil,
                timestamp: Date()
            )
        }
    }
    
    static func endLiveActivity(request: Request, context: some RequestContext) async throws -> LiveActivityResponse {
        let logger = Logger(label: "RideTracker.endLiveActivity")
        
        do {
            let requestData = try await request.body.collect(upTo: 1024 * 1024) // 1MB limit
            let endRequest = try JSONDecoder().decode(LiveActivityEndRequest.self, from: Data(buffer: requestData))
            
            // Log ride completion
            if let finalContentData = endRequest.finalContentState,
               let contentData = Data(base64Encoded: finalContentData),
               let content = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
                let status = content["status"] as? String ?? "unknown"
                let fare = content["fare"] as? Double
                
                if let fare = fare {
                    logger.info("Ride completed: Status=\(status), Fare=$\(String(format: "%.2f", fare))")
                } else {
                    logger.info("Ride ended: Status=\(status)")
                }
            }
            
            let response = try await service.endLiveActivity(request: endRequest)
            logger.info("Successfully ended ride for activityId: \(endRequest.activityId)")
            
            return response
            
        } catch let decodingError as DecodingError {
            logger.error("Failed to decode ride end request: \(decodingError)")
            return LiveActivityResponse(
                success: false,
                message: "Invalid ride end format: \(decodingError.localizedDescription)",
                activityId: nil,
                timestamp: Date()
            )
        } catch let serviceError as LiveActivitiesService.LiveActivitiesError {
            logger.error("RideTracker service error: \(serviceError)")
            return LiveActivityResponse(
                success: false,
                message: "Ride end error: \(serviceError.localizedDescription)",
                activityId: nil,
                timestamp: Date()
            )
        } catch {
            logger.error("Unexpected ride end error: \(error)")
            return LiveActivityResponse(
                success: false,
                message: "Unexpected ride end error: \(error.localizedDescription)",
                activityId: nil,
                timestamp: Date()
            )
        }
    }
}
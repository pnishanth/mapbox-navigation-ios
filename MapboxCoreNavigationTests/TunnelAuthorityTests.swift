import XCTest
import Turf
import Polyline
import MapKit
import MapboxDirections
@testable import MapboxCoreNavigation

struct TunnelDetectorTestData {
    static let ninthStreetFileName = "routeWithTunnels_9thStreetDC"
    static let kRouteKey = "routes"
    static let startLocation = CLLocationCoordinate2D(latitude: 38.890774, longitude: -77.023970)
    static let endLocation = CLLocationCoordinate2D(latitude: 38.88061238536352, longitude: -77.02471810711819)
}

let tunnelResponse = Fixture.JSONFromFileNamed(name: TunnelDetectorTestData.ninthStreetFileName)
let tunnelJsonRoute = (tunnelResponse[TunnelDetectorTestData.kRouteKey] as! [AnyObject]).first as! [String: Any]
let tunnelWayPoint1 = Waypoint(coordinate: TunnelDetectorTestData.startLocation)
let tunnelWaypoint2 = Waypoint(coordinate: TunnelDetectorTestData.endLocation)
let tunnelRoute = Route(json: tunnelJsonRoute, waypoints: [tunnelWayPoint1, tunnelWaypoint2], options: NavigationRouteOptions(waypoints: [tunnelWayPoint1, tunnelWaypoint2]))

class TunnelAuthorityTests: XCTestCase {
    lazy var locationManager = NavigationLocationManager()
    
    func testUserWithinTunnelEntranceRadius() {
        let routeProgress = RouteProgress(route: tunnelRoute)
        
        // Mock location move to first coordinate on tunnel route
        let firstCoordinate = tunnelRoute.coordinates!.first!
        let firstLocation = CLLocation(latitude: firstCoordinate.latitude, longitude: firstCoordinate.longitude)
        
        // Test outside tunnel
        routeProgress.currentLegProgress.stepIndex = 0
        let missingIntersectionTest = TunnelAuthority.isInTunnel(at: firstLocation, along: routeProgress)
        XCTAssertFalse(missingIntersectionTest, "Answer should be false.. missing intersection")
        
        // Test outside tunnel bad location
        routeProgress.currentLegProgress.stepIndex = 1
        routeProgress.currentLegProgress.currentStepProgress.intersectionsIncludingUpcomingManeuverIntersection = routeProgress.currentLegProgress.currentStepProgress.step.intersections
        routeProgress.currentLegProgress.currentStepProgress.intersectionIndex = 0
        
        let secondLocation = CLLocation(coordinate: firstLocation.coordinate, altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: 0, speed: TunnelAuthority.Constants.minimumTunnelEntranceSpeed - 1, timestamp: Date())
        
        let upcomingTunnelBadLocation = TunnelAuthority.isInTunnel(at: secondLocation, along: routeProgress)
        XCTAssertFalse(upcomingTunnelBadLocation, "Answer should be false, speed is too low.")
        
        // Test outside tunnel bad location due to unqualified
        let thirdLocation = CLLocation(coordinate: firstLocation.coordinate, altitude: 0, horizontalAccuracy: 200, verticalAccuracy: 0, course: 0, speed: TunnelAuthority.Constants.minimumTunnelEntranceSpeed, timestamp: Date())
        let upcomingTunnelBadLocationUnqualified = TunnelAuthority.isInTunnel(at: thirdLocation, along: routeProgress)
        XCTAssertFalse(upcomingTunnelBadLocationUnqualified, "Answer should be false, location is not qualified")
        
        // Outside tunnel when speed it too low
        let fourthLocation = CLLocation(coordinate: firstLocation.coordinate, altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: 0, speed: TunnelAuthority.Constants.minimumTunnelEntranceSpeed, timestamp: Date())
        let upcomingTunnelBadDistance = TunnelAuthority.isInTunnel(at: fourthLocation, along: routeProgress)
        XCTAssertFalse(upcomingTunnelBadDistance, "Answer should be false, distance to intersection is unset")
        
        // Waiting outside tunnel
        routeProgress.currentLegProgress.currentStepProgress.userDistanceToUpcomingIntersection = TunnelAuthority.Constants.tunnelEntranceRadius + 1
        let upcomingTunnelOutsideEntranceRadius = TunnelAuthority.isInTunnel(at: fourthLocation, along: routeProgress)
        XCTAssertFalse(upcomingTunnelOutsideEntranceRadius, "Answer should be false, outside entrance radius")
        routeProgress.currentLegProgress.currentStepProgress.userDistanceToUpcomingIntersection = nil
        
        // Entering tunnel
        routeProgress.currentLegProgress.currentStepProgress.userDistanceToUpcomingIntersection = TunnelAuthority.Constants.tunnelEntranceRadius - 1
        let upcomingTunnelInsideEntranceRadius = TunnelAuthority.isInTunnel(at: fourthLocation, along: routeProgress)
        XCTAssertTrue(upcomingTunnelInsideEntranceRadius, "Answer should be true, inside entrance radius")
        routeProgress.currentLegProgress.currentStepProgress.userDistanceToUpcomingIntersection = nil
        
        // Progressing through tunnel
        routeProgress.currentLegProgress.currentStepProgress.intersectionIndex = 1
        let currentTunnelProgressing = TunnelAuthority.isInTunnel(at: fourthLocation, along: routeProgress)
        XCTAssertTrue(currentTunnelProgressing, "Answer should be true, current intersection outlet is tunnel")
        
        // Exiting tunnel
        routeProgress.currentLegProgress.currentStepProgress.intersectionIndex = 2
        let exitedTunnel = TunnelAuthority.isInTunnel(at: fourthLocation, along: routeProgress)
        XCTAssertFalse(exitedTunnel, "Answer should be false, exited tunnel")
        
        // Between two tunnels with a short surface road
        routeProgress.currentLegProgress.currentStepProgress.userDistanceToUpcomingIntersection = TunnelAuthority.Constants.tunnelEntranceRadius + 1
        routeProgress.currentLegProgress.currentStepProgress.intersectionIndex = 4
        let betweenTunnels = TunnelAuthority.isInTunnel(at: fourthLocation, along: routeProgress)
        XCTAssertTrue(betweenTunnels, "Answer should be true, we are between two tunnels")
    }
}

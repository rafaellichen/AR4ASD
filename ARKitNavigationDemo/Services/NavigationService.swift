//
//  NavigationService.swift
//  ARKitDemoApp
//
//  Modified by Rafael Li Chen on 5/9/2018
//  Copyright © 2017 Rafael Li Chen. All rights reserved.
//


import MapKit
import CoreLocation

public extension MKPolyline {
    public var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid,
                                              count: self.pointCount)
        self.getCoordinates(&coords, range: NSRange(location: 0, length: self.pointCount))
        return coords
    }
}

struct NavigationService {
    
    func getDirections(destinationLocation: CLLocationCoordinate2D, request: MKDirectionsRequest, completion: @escaping ([MKRouteStep],[CLLocationCoordinate2D]) -> Void) {
        var steps: [MKRouteStep] = []
        var waypoints : [CLLocationCoordinate2D] = []
        
        let placeMark = MKPlacemark(coordinate: destinationLocation)
        
        request.destination = MKMapItem.init(placemark: placeMark)
        request.source = MKMapItem.forCurrentLocation()
        request.requestsAlternateRoutes = false
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if error != nil {
                print("Error getting directions")
            } else {
                guard let response = response else { return }
                for route in response.routes {
                    steps.append(contentsOf: route.steps)
                    waypoints.append(contentsOf: route.polyline.coordinates)
                }
                completion(steps, waypoints)
            }
        }
    }
}

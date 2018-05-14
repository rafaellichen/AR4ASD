//
//  CLLocationCoordinate2D.swift
//  ARKitDemoApp
//
//  Modified by Rafael Li Chen and Lidong Chen on 5/13/2018
//  Copyright © 2017 Rafael Li Chen. All rights reserved.
//

import CoreLocation

extension CLLocationCoordinate2D: Equatable {
    
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
    
    func calculateDirection(to coordinate: CLLocationCoordinate2D) -> Double {
        let a = sin(coordinate.longitude.toRadians() - longitude.toRadians()) * cos(coordinate.latitude.toRadians())
        let dLat = cos(latitude.toRadians()) * sin(coordinate.latitude.toRadians()) - sin(latitude.toRadians())
        let dLon = cos(coordinate.latitude.toRadians()) * cos(coordinate.longitude.toRadians() - longitude.toRadians())
        let b =  dLat * dLon
        return atan2(a, b)
    }
    
    func direction(to coordinate: CLLocationCoordinate2D) -> CLLocationDirection {
        return self.calculateDirection(to: coordinate).toDegrees()
    }
    
    func bearingToLocationRadian(_ destinationLocation: CLLocationCoordinate2D) -> Double {
        
        let lat1 = latitude.toRadians()
        let lon1 = longitude.toRadians()
        let lat2 = destinationLocation.latitude.toRadians()
        let lon2 = destinationLocation.longitude.toRadians()
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
        let radiansBearing = atan2(y, x)
        return radiansBearing
    }
    
    func coordinate(with bearing: Double, and distance: Double) -> CLLocationCoordinate2D {
        let distRadiansLat = distance / LocationConstants.metersPerRadianLat  // earth radius in meters latitude
        let distRadiansLong = distance / LocationConstants.metersPerRadianLon // earth radius in meters longitude
        let lat1 = self.latitude.toRadians()
        let lon1 = self.longitude.toRadians()
        let lat2 = asin(sin(lat1) * cos(distRadiansLat) + cos(lat1) * sin(distRadiansLat) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(distRadiansLong) * cos(lat1), cos(distRadiansLong) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(latitude: lat2.toDegrees(), longitude: lon2.toDegrees())
    }

    static func getIntermediaryLocations(currentLocation: CLLocation, destinationLocation: CLLocation) -> [CLLocationCoordinate2D] {
        var distances = [CLLocationCoordinate2D]()
        let distance = Float(destinationLocation.distance(from: currentLocation))
        var newLocation = CLLocationCoordinate2D()
        let InterPoint_Num = Int(floor(distance))
        for index in 1...InterPoint_Num {
            newLocation.latitude = currentLocation.coordinate.latitude + (destinationLocation.coordinate.latitude - currentLocation.coordinate.latitude) / Double(ceil(distance)) * Double(index)
            newLocation.longitude = currentLocation.coordinate.longitude + (destinationLocation.coordinate.longitude - currentLocation.coordinate.longitude) / Double(ceil(distance)) * Double(index)
            distances.append(newLocation)
        }
        return distances
    }
}

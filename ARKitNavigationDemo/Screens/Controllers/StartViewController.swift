//
//  StartViewController.swift
//  ARKitDemoApp
//
//  Modified by Rafael Li Chen on 5/9/2018
//  Copyright © 2017 Rafael Li Chen. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import ARKit

final class StartViewController: UIViewController, UIGestureRecognizerDelegate, Controller {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var touchlabel: UILabel!
    private var annotationColor = UIColor.blue
    internal var annotations: [POIAnnotation] = []
    private var currentTripLegs: [[CLLocationCoordinate2D]] = []
    weak var delegate: StartViewControllerDelegate?
    var locationService: LocationService = LocationService()
    var navigationService: NavigationService = NavigationService()
    var type: ControllerType = .nav
    private var locations: [CLLocation] = []
    var startingLocation: CLLocation!
    var press: UILongPressGestureRecognizer!
    private var steps: [MKRouteStep] = []
    private var waypoints: [CLLocationCoordinate2D] = []
    var autoUpdate = true
    var destinationLocation: CLLocationCoordinate2D! {
        didSet {
            setupNavigation()
        }
    }
    @IBAction func ZoomToMe(_ sender: UIButton) {
        autoUpdate = true
        centerMapInInitialCoordinates()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLbl), name: NSNotification.Name(rawValue: "refresh"), object: nil)
        if ARConfiguration.isSupported {
            locationService.delegate = self
            guard let locationManager = locationService.locationManager else { return }
            locationService.startUpdatingLocation(locationManager: locationManager)
            press = UILongPressGestureRecognizer(target: self, action: #selector(handleMapTap(gesture:)))
            press.minimumPressDuration = 0.35
            mapView.addGestureRecognizer(press)
            mapView.delegate = self
            let mapDragRecognizer = UIPanGestureRecognizer(target: self, action: (#selector(didDragMap)))
            mapDragRecognizer.delegate = self
            mapView.addGestureRecognizer(mapDragRecognizer)
        } else {
            presentMessage(title: "Not Compatible", message: "ARKit is not compatible with this phone.")
            return
        }
    }
    @objc func refreshLbl(notification: NSNotification) {
        touchlabel.isHidden = false
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    @objc func didDragMap(_ gestureRecognizer: UIGestureRecognizer) {
        if (gestureRecognizer.state == UIGestureRecognizerState.began) {
            autoUpdate = false
            touchlabel.isHidden = true
        }
    }

    
    // Sets destination location to point on map
    @objc func handleMapTap(gesture: UIGestureRecognizer) {
        if gesture.state != UIGestureRecognizerState.began {
            return
        }
        // Get tap point on map
        let touchPoint = gesture.location(in: mapView)
        
        // Convert map tap point to coordinate
        let coord: CLLocationCoordinate2D = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        
        destinationLocation = coord
    }
    
    // Gets directions from from MapKit directions API, when finished calculates intermediary locations
    
    private func setupNavigation() {
        
        let group = DispatchGroup()
        group.enter()
        
        DispatchQueue.global(qos: .default).async {
            
            if self.destinationLocation != nil {
                self.navigationService.getDirections(destinationLocation: self.destinationLocation, request: MKDirectionsRequest()) { steps, waypoints in
                    for step in steps {
                        self.annotations.append(POIAnnotation(coordinate: step.getLocation().coordinate, name: "N " + step.instructions))
                    }
                    for point in waypoints {
                        self.annotations.append(POIAnnotation(coordinate: point, name: ""))
                    }
                    self.steps.append(contentsOf: steps)
                    self.waypoints.append(contentsOf: waypoints)
                    group.leave()
                }
            }
            
            // All steps must be added before moving to next step
            group.wait()
            
            self.getLocationData()
        }
    }
    
    private func getLocationData() {
//        for (index, step) in steps.enumerated() {
//            setTripLegFromStep(step, and: index)
//        }
        for(index, point) in waypoints.enumerated() {
            setTripLegFromStep(point, and: index)
        }
        print(self.currentTripLegs.count)
        for leg in currentTripLegs {
            update(intermediary: leg)
        }
//        currentTripLegs = [waypoints]
        
        centerMapInInitialCoordinates()
//        showPointsOfInterestInMap(currentTripLegs: currentTripLegs)
        addMapAnnotations()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alertController = UIAlertController(title: "", message: "Start Navigation?", preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: "No.", style: .cancel, handler: { action in
                DispatchQueue.main.async {
                    self.destinationLocation = nil
                    self.annotations.removeAll()
                    self.locations.removeAll()
                    self.currentTripLegs.removeAll()
                    self.steps.removeAll()
                    self.waypoints.removeAll()
                    self.mapView.removeAnnotations(self.mapView.annotations)
                    self.mapView.removeOverlays(self.mapView.overlays)
                }
            })
            
            let okayAction = UIAlertAction(title: "Go!", style: .default, handler: { action in
                let destination = CLLocation(latitude: self.destinationLocation.latitude, longitude: self.destinationLocation.longitude)
                self.delegate?.startNavigation(with: self.annotations, for: destination, and: self.currentTripLegs, and: self.steps)
            })
            
            alertController.addAction(cancelAction)
            alertController.addAction(okayAction)
            self.present(alertController, animated: true, completion: nil)
        }
        
    }
    
    // Gets coordinates between two locations at set intervals
    private func setLeg(from previous: CLLocation, to next: CLLocation) -> [CLLocationCoordinate2D] {
        return CLLocationCoordinate2D.getIntermediaryLocations(currentLocation: previous, destinationLocation: next)
    }
    
    // Add POI dots to map
    private func showPointsOfInterestInMap(currentTripLegs: [[CLLocationCoordinate2D]]) {
        mapView.removeAnnotations(mapView.annotations)
        for tripLeg in currentTripLegs {
            for coordinate in tripLeg {
                let poi = POIAnnotation(coordinate: coordinate, name: String(describing: coordinate))
                mapView.addAnnotation(poi)
            }
        }
    }
    
    // Adds calculated distances to annotations and locations arrays
    private func update(intermediary locations: [CLLocationCoordinate2D]) {
        for intermediaryLocation in locations {
            annotations.append(POIAnnotation(coordinate: intermediaryLocation, name: String(describing:intermediaryLocation)))
            self.locations.append(CLLocation(latitude: intermediaryLocation.latitude, longitude: intermediaryLocation.longitude))
        }
    }
    
    // Determines whether leg is first leg or not and routes logic accordingly
    private func setTripLegFromStep(_ tripStep: CLLocationCoordinate2D, and index: Int) {
        if index > 0 {
            getTripLeg(for: index, and: tripStep)
        } else {
            getInitialLeg(for: tripStep)
        }
    }
//    private func setTripLegFromStep(_ tripStep: MKRouteStep, and index: Int) {
//        if index > 0 {
//            getTripLeg(for: index, and: tripStep)
//        } else {
//            getInitialLeg(for: tripStep)
//        }
//    }
    
    // Calculates intermediary coordinates for route step that is not first
    private func getTripLeg(for index: Int, and tripStep: CLLocationCoordinate2D) {
        let previousIndex = index - 1
        let previousStep = waypoints[previousIndex]
        let previousLocation = CLLocation(latitude: previousStep.latitude, longitude: previousStep.longitude)
        let nextLocation = CLLocation(latitude: tripStep.latitude, longitude: tripStep.longitude)
        let intermediarySteps = CLLocationCoordinate2D.getIntermediaryLocations(currentLocation: previousLocation, destinationLocation: nextLocation)
        currentTripLegs.append(intermediarySteps)
    }
//    private func getTripLeg(for index: Int, and tripStep: MKRouteStep) {
//        let previousIndex = index - 1
//        let previousStep = steps[previousIndex]
//        let previousLocation = CLLocation(latitude: previousStep.polyline.coordinate.latitude, longitude: previousStep.polyline.coordinate.longitude)
//        let nextLocation = CLLocation(latitude: tripStep.polyline.coordinate.latitude, longitude: tripStep.polyline.coordinate.longitude)
//        let intermediarySteps = CLLocationCoordinate2D.getIntermediaryLocations(currentLocation: previousLocation, destinationLocation: nextLocation)
//        currentTripLegs.append(intermediarySteps)
//    }
    
    // Calculates intermediary coordinates for first route step
    private func getInitialLeg(for tripStep: CLLocationCoordinate2D) {
        let nextLocation = CLLocation(latitude: tripStep.latitude, longitude: tripStep.longitude)
        let intermediaries = CLLocationCoordinate2D.getIntermediaryLocations(currentLocation: startingLocation, destinationLocation: nextLocation)
        currentTripLegs.append(intermediaries)
    }
//    private func getInitialLeg(for tripStep: MKRouteStep) {
//        let nextLocation = CLLocation(latitude: tripStep.polyline.coordinate.latitude, longitude: tripStep.polyline.coordinate.longitude)
//        let intermediaries = CLLocationCoordinate2D.getIntermediaryLocations(currentLocation: startingLocation, destinationLocation: nextLocation)
//        currentTripLegs.append(intermediaries)
//    }
    
    // Prefix N is just a way to grab step annotations, could definitely get refactored
    private func addMapAnnotations() {
        
        annotations.forEach { annotation in
            
            // Step annotations are green, intermediary are blue
            DispatchQueue.main.async {
                if let title = annotation.title, title.hasPrefix("N") {
                    self.annotationColor = .green
                } else {
                    self.annotationColor = .blue
                }
//                self.mapView?.addAnnotation(annotation)
                self.mapView.add(MKCircle(center: annotation.coordinate, radius: 0.2))
            }
        }
    }
    
}

extension StartViewController: LocationServiceDelegate, MessagePresenting, Mapable {
    
    // Once location is tracking - zoom in and center map
    func trackingLocation(for currentLocation: CLLocation) {
        startingLocation = currentLocation
        if(autoUpdate) {
            centerMapInInitialCoordinates()
        }
    }
    
    // Don't fail silently
    func trackingLocationDidFail(with error: Error) {
//        presentMessage(title: "Error", message: error.localizedDescription)
    }
}

extension StartViewController: MKMapViewDelegate {
    
//    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
//        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "annotationView") ?? MKAnnotationView()
//        annotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
//        annotationView.canShowCallout = true
//        return annotationView
//    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.fillColor = UIColor.black.withAlphaComponent(0.1)
            renderer.strokeColor = annotationColor
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer()
    }
}

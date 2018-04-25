//
//  ViewController.swift
//  ARKitDemoApp
//
//  Created by Christopher Webb-Orenstein on 8/27/17.
//  Copyright © 2017 Christopher Webb-Orenstein. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreLocation
import MapKit
import AVFoundation

import Firebase

class ViewController: UIViewController, CLLocationManagerDelegate {
    var cnst: Float = 2
    var locationHistory: [String] = []
    var systemgenerated: [String] = []
    var type: ControllerType = .nav
    weak var delegate: NavigationViewControllerDelegate?
    var locationData: LocationData!
    private var annotationColor = UIColor.blue
    private var updateNodes: Bool = false
    private var anchors: [ARAnchor] = []
    private var nodes: [BaseNode] = []
    private var steps: [MKRouteStep] = []
    private var locationService = LocationService()
    internal var annotations: [POIAnnotation] = []
    internal var startingLocation: CLLocation!
    private var destinationLocation: CLLocationCoordinate2D!
    private var locations: [CLLocation] = []
    private var currentLegs: [[CLLocationCoordinate2D]] = []
    private var updatedLocations: [CLLocation] = []
    private let configuration = ARWorldTrackingConfiguration()
    private var done: Bool = false
    var timer: Timer!
//    var timer2: Timer!
    let locationManager = CLLocationManager()
    var usercurrentlocation: CLLocationCoordinate2D!
    var audioindex = 0
    let speechSynthesizer = AVSpeechSynthesizer()
    var speechUtterance: AVSpeechUtterance = AVSpeechUtterance(string: "")
    var ref: DatabaseReference! = Database.database().reference()
    
    //    private var locationUpdates: Int = 0 {
//        didSet {
//            if locationUpdates >= 4 {
//                updateNodes = false
//            }
//        }
//    }
    @IBOutlet weak var TouchLabel: UILabel!
    
    @IBAction func Calibrate() {
        sceneView.session.pause()
        sceneView.scene.rootNode.enumerateChildNodes {
            (node, stop) in node.removeFromParentNode()
        }
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        DispatchQueue.main.async {
            self.addAnchors(steps: self.steps)
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        startingLocation = CLLocation(latitude: usercurrentlocation.latitude, longitude: usercurrentlocation.longitude)
        for baseNode in nodes {
            let translation = MatrixHelper.transformMatrix(for: matrix_identity_float4x4, originLocation: startingLocation, location: baseNode.location)
            let position = SCNVector3.positionFromTransform(translation)
            let distance = baseNode.location.distance(from: startingLocation)
            DispatchQueue.main.async {
                let scale = Float(distance)*self.cnst
                baseNode.scale = SCNVector3(x: scale, y: scale, z: scale)
                baseNode.anchor = ARAnchor(transform: translation)
                baseNode.position = position
            }
        }
        SCNTransaction.commit()
    }
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet private var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        TouchLabel.backgroundColor=UIColor.gray
        TouchLabel.layer.cornerRadius = TouchLabel.frame.height/2
        TouchLabel.layer.masksToBounds = true
        TouchLabel.textAlignment = .center
        mapView.delegate = self
        let latDelta:CLLocationDegrees = 0.0005
        let lonDelta:CLLocationDegrees = 0.0005
        let span = MKCoordinateSpanMake(latDelta, lonDelta)
//        print(mapView.centerCoordinate)
        let location = CLLocationCoordinate2DMake(mapView.centerCoordinate.latitude, mapView.centerCoordinate.longitude)
        let region = MKCoordinateRegionMake(location, span)
        mapView.setRegion(region, animated: false)
        
        setupScene()
        setupLocationService()
        setupNavigation()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest // You can change the locaiton accuary here.
            locationManager.startUpdatingLocation()
        }
        audioindex = 0
    }
}

extension ViewController: Controller {
    
    @IBAction func resetButtonTapped(_ sender: Any) {
        delegate?.reset()
        sceneView.session.pause()
        sceneView.scene.rootNode.enumerateChildNodes {
            (node, stop) in node.removeFromParentNode()
        }
        timer.invalidate()
        timer = nil
//        timer2.invalidate()
        locationHistory.removeAll()
        systemgenerated.removeAll()
        TouchLabel.isHidden=false
//        let randomKey = ref.child("history").child(UIDevice.current.identifierForVendor!.uuidString).childByAutoId().key
//        print(randomKey)
        for each in locations {
            systemgenerated.append(String(each.coordinate.latitude)+","+String(each.coordinate.longitude))
        }
//        self.ref.child("history").setValue(["test": 123])
//        let timestamp = NSDate().timeIntervalSince1970
//        print(timestamp)
        audioindex = 0
        let formatter = DateFormatter()
        // initially set the format based on your datepicker date
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let myString = formatter.string(from: Date())
        self.ref.child("history").child(UIDevice.current.identifierForVendor!.uuidString+"/"+myString).setValue(["latlong": locationHistory, "system": systemgenerated])
//        self.ref.child("History").child(randomKey).setValue(locationHistory)
    }
    
    private func setupLocationService() {
        locationService = LocationService()
        locationService.delegate = self
    }
    
    private func setupNavigation() {
        if locationData != nil {
            steps.append(contentsOf: locationData.steps)
            currentLegs.append(contentsOf: locationData.legs)
            let coordinates = currentLegs.flatMap { $0 }
            locations = coordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
            annotations.append(contentsOf: annotations)
            destinationLocation = locationData.destinationLocation.coordinate
        }
        done = true
    }
    
    private func setupScene() {
        sceneView.delegate = self
        sceneView.showsStatistics = false
        let scene = SCNScene()
        sceneView.scene = scene
        navigationController?.setNavigationBarHidden(true, animated: false)
        runSession()
    }
}

extension ViewController: MessagePresenting {
    
    // Set session configuration with compass and gravity 
    
    func runSession() {
        configuration.worldAlignment = .gravityAndHeading
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // Render nodes when user touches screen
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        TouchLabel.isHidden = true
        updateNodes = true
        if updatedLocations.count > 0 {
            startingLocation = CLLocation.bestLocationEstimate(locations: updatedLocations)
            if (startingLocation != nil && mapView.annotations.count == 0) && done == true {
                DispatchQueue.main.async {
//                    self.centerMapInInitialCoordinates()
                    self.showPointsOfInterestInMap(currentLegs: self.currentLegs)
                    self.addAnnotations()
                    self.addAnchors(steps: self.steps)
                    self.mapView.showsUserLocation = true
                }
            }
        }
        timer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(ViewController.update), userInfo: nil, repeats: true)
        
//        timer2 = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(ViewController.update2), userInfo: nil, repeats: true)
//        for i in steps {
//            print("location: ",i.getLocation())
//            print("instruction: ",i.instructions)
//        }
        
    }
    
    @objc func update2() {
        print(steps.count)
        if(audioindex<steps.count && audioindex != steps.count-1) {
            let string = steps[audioindex].instructions
            speechUtterance = AVSpeechUtterance(string: string)
            speechUtterance.rate = 0.4
            speechSynthesizer.speak(speechUtterance)
        } else if(audioindex == steps.count-1) {
            let string = "Proceed to your destination."
            speechUtterance = AVSpeechUtterance(string: string)
            speechUtterance.rate = 0.4
            speechSynthesizer.speak(speechUtterance)
        } else {
            let string = "You have arrived at your destination."
            speechUtterance = AVSpeechUtterance(string: string)
            speechUtterance.rate = 0.4
            speechSynthesizer.speak(speechUtterance)
        }
        
    }
    
    @objc func update() {
        print(audioindex)
        if(audioindex == 0) {
            let string = steps[audioindex].instructions
            speechUtterance = AVSpeechUtterance(string: string)
            speechUtterance.rate = 0.4
            speechSynthesizer.speak(speechUtterance)
            audioindex+=1
        } else if(audioindex<steps.count) {
            let distanceInMeters = CLLocation(latitude: steps[audioindex].getLocation().coordinate.latitude, longitude: steps[audioindex].getLocation().coordinate.longitude).distance(from: CLLocation(latitude:usercurrentlocation.latitude, longitude:usercurrentlocation.longitude))
            print(distanceInMeters)
            locationHistory.append(String(usercurrentlocation.latitude)+","+String(usercurrentlocation.longitude))
            if(distanceInMeters < 11) {
                let string = steps[audioindex].instructions
                speechUtterance = AVSpeechUtterance(string: string)
                speechUtterance.rate = 0.4
                speechSynthesizer.speak(speechUtterance)
//                presentMessage(title: "Route", message: steps[audioindex].instructions)
                audioindex+=1
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            usercurrentlocation=location.coordinate
        }
        let latitude:CLLocationDegrees = usercurrentlocation.latitude
        let longitude:CLLocationDegrees = usercurrentlocation.longitude
        let latDelta:CLLocationDegrees = 0.0005
        let lonDelta:CLLocationDegrees = 0.0005
        let span = MKCoordinateSpanMake(latDelta, lonDelta)
        let location = CLLocationCoordinate2DMake(latitude, longitude)
        let region = MKCoordinateRegionMake(location, span)
        mapView.setRegion(region, animated: false)
    }
    
    private func showPointsOfInterestInMap(currentLegs: [[CLLocationCoordinate2D]]) {
        for leg in currentLegs {
            for item in leg {
                let poi = POIAnnotation(coordinate: item, name: String(describing:item))
                self.annotations.append(poi)
//                self.mapView.addAnnotation(poi)
            }
        }
    }
    
    private func addAnnotations() {
        annotations.forEach { annotation in
            guard let map = mapView else { return }
            DispatchQueue.main.async {
                if let title = annotation.title, title.hasPrefix("N") {
                    self.annotationColor = .green
                } else {
                    self.annotationColor = .blue
                }
//                map.addAnnotation(annotation)
                map.add(MKCircle(center: annotation.coordinate, radius: 0.2))
            }
        }
    }
    
    private func updateNodePosition() {
//        if updateNodes {
//            locationUpdates += 1
//            SCNTransaction.begin()
//            SCNTransaction.animationDuration = 0.5
//            if updatedLocations.count > 0 {
//                startingLocation = CLLocation.bestLocationEstimate(locations: updatedLocations)
//                for baseNode in nodes {
//                    let translation = MatrixHelper.transformMatrix(for: matrix_identity_float4x4, originLocation: startingLocation, location: baseNode.location)
//                    let position = SCNVector3.positionFromTransform(translation)
//                    let distance = baseNode.location.distance(from: startingLocation)
//                    DispatchQueue.main.async {
//                        let scale = 100 / Float(distance)
//                        baseNode.scale = SCNVector3(x: scale, y: scale, z: scale)
//                        baseNode.anchor = ARAnchor(transform: translation)
//                        baseNode.position = position
//                    }
//                }
//            }
//            SCNTransaction.commit()
//        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        if updatedLocations.count > 0 {
            startingLocation = CLLocation.bestLocationEstimate(locations: updatedLocations)
            for baseNode in nodes {
                let translation = MatrixHelper.transformMatrix(for: matrix_identity_float4x4, originLocation: startingLocation, location: baseNode.location)
                let position = SCNVector3.positionFromTransform(translation)
                let distance = baseNode.location.distance(from: startingLocation)
                DispatchQueue.main.async {
//                    let scale = 100 / Float(distance)
                    let scale = Float(distance)*self.cnst
//                    print(scale)
                    baseNode.scale = SCNVector3(x: scale, y: scale, z: scale)
                    baseNode.anchor = ARAnchor(transform: translation)
                    baseNode.position = position
                }
            }
        }
        SCNTransaction.commit()
        
    }
    
    // For navigation route step add sphere node
    
    private func addSphere(for step: MKRouteStep) {
        let stepLocation = step.getLocation()
        let locationTransform = MatrixHelper.transformMatrix(for: matrix_identity_float4x4, originLocation: startingLocation, location: stepLocation)
        let stepAnchor = ARAnchor(transform: locationTransform)
        let sphere = BaseNode(title: step.instructions, location: stepLocation)
        anchors.append(stepAnchor)
        sphere.addNode(with: 0.6, and: .green, and: step.instructions)
        sphere.location = stepLocation
        sphere.anchor = stepAnchor
        sceneView.session.add(anchor: stepAnchor)
        sceneView.scene.rootNode.addChildNode(sphere)
        nodes.append(sphere)
    }
    
    // For intermediary locations - CLLocation - add sphere
    
    private func addSphere(for location: CLLocation) {
        let locationTransform = MatrixHelper.transformMatrix(for: matrix_identity_float4x4, originLocation: startingLocation, location: location)
//        print(locationTransform)
        let stepAnchor = ARAnchor(transform: locationTransform)
        let sphere = BaseNode(title: "Title", location: location)
        sphere.addSphere(with: 0.3, and: .blue)
        anchors.append(stepAnchor)
        sphere.location = location
        sceneView.session.add(anchor: stepAnchor)
        sceneView.scene.rootNode.addChildNode(sphere)
        sphere.anchor = stepAnchor
        nodes.append(sphere)
    }
}

extension ViewController: ARSCNViewDelegate {
    
    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        presentMessage(title: "Error", message: error.localizedDescription)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        presentMessage(title: "Error", message: "Session Interuption")
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            print("ready")
        case .notAvailable:
            print("wait")
        case .limited(let reason):
            print("limited tracking state: \(reason)")
        }
    }
}

extension ViewController: LocationServiceDelegate {
    
    func trackingLocation(for currentLocation: CLLocation) {
        if currentLocation.horizontalAccuracy <= 65.0 {
            updatedLocations.append(currentLocation)
            updateNodePosition()
        }
//        centerMapInInitialCoordinates()
    }
    
    func trackingLocationDidFail(with error: Error) {
        presentMessage(title: "Error", message: error.localizedDescription)
    }
}

extension ViewController: MKMapViewDelegate {
    
//    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
//        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "annotationView") ?? MKAnnotationView()
//        annotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
//        annotationView.canShowCallout = true
//        return annotationView
//
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
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        let alertController = UIAlertController(title: "Welcome to \(String(describing: title))", message: "You've selected \(String(describing: title))", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }    
}

extension ViewController:  Mapable {
    
    private func addAnchors(steps: [MKRouteStep]) {
        guard startingLocation != nil && steps.count > 0 else { return }
        for step in steps { addSphere(for: step) }
        for location in locations { addSphere(for: location) }
    }
}

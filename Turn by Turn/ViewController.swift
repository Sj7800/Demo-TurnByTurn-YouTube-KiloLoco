//
//  ViewController.swift
//  Turn by Turn
//
//  Created by leslie on 1/15/20.
//  Copyright © 2020 leslie. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var directionsLbl: UILabel!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D!
    
    var steps = [MKRoute.Step]()
    let speechSynthesizer = AVSpeechSynthesizer()
    
    var stepCounter = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupLocationManager()
        setupMapView()

    }
    
    func setupLocationManager() {
        
        locationManager.stopUpdatingLocation()
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.startUpdatingLocation()
        
    }
    
    func setupMapView() {
        
        // Map View delegate
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        
    }

    func getDirrections(to destination: MKMapItem) {
        
        // MKPlacemark data includes geo-location address associated with coordinate2D
        let sourcePlacemark = MKPlacemark(coordinate: currentCoordinate)
        // MKMapItem data includes geo-location address associated with any interesting data
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        
        let directionsRequest = MKDirections.Request()
        directionsRequest.source = sourceMapItem
        directionsRequest.destination = destination
        directionsRequest.transportType = .walking
        
        let directions = MKDirections(request: directionsRequest)
        directions.calculate { (response, _) in
            guard let response = response else { return }
            guard let primaryRoute = response.routes.first else { return }
            
            self.mapView.addOverlay(primaryRoute.polyline)
            
            self.locationManager.monitoredRegions.forEach({self.locationManager.stopMonitoring(for: $0)})
            
            self.steps = primaryRoute.steps
            for i in 0 ..< primaryRoute.steps.count {
                let step = primaryRoute.steps[i]
                let region = CLCircularRegion(center: step.polyline.coordinate, radius: 20, identifier: "\(i)")
                self.locationManager.startMonitoring(for: region)
                
                let circle = MKCircle(center: region.center, radius: region.radius)
                self.mapView.addOverlay(circle)
            }
            
            let initialMessage = "In \(self.steps[0].distance) meters, \(self.steps[0].instructions) then in \(self.steps[1].distance) meters, \(self.steps[1].instructions)"
            
            self.directionsLbl.text = initialMessage
            let speechUtterance = AVSpeechUtterance(string: initialMessage)
            self.speechSynthesizer.speak(speechUtterance)
            self.stepCounter += 1
        }
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
        
        // 'locations.first' is not correct for My_Current_Location
        guard let location = locations.first else { return }
        let currentLocation = CLLocation(latitude: (location.coordinate.latitude) - 0.00189429, longitude: (location.coordinate.longitude) + 0.00463669)
        self.currentCoordinate = currentLocation.coordinate
        print(currentLocation)
        
        // This data is correct for My_Current_Location as CLLocation type from mapView.userlocation
        let mapViewCoordinate = mapView.userLocation.coordinate
        //        self.currentCoordinate = mapViewCoordinate
        print(mapViewCoordinate)

//        guard let currentLocation = locationManager.location?.coordinate else { return }
//        self.currentCoordinate = currentLocation
        
        mapView.userTrackingMode = .followWithHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        stepCounter += 1
        if stepCounter < steps.count {
            let currentStep = steps[stepCounter]
            let message = "In \(currentStep.distance) meters, \(currentStep.instructions)"
            directionsLbl.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
        } else {
            let message = "Arrived at destination"
            directionsLbl.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
            stepCounter = 0
            locationManager.monitoredRegions.forEach({ self.locationManager.stopMonitoring(for: $0) })
            
        }
    }
}

extension ViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        
        let localSearchRequest = MKLocalSearch.Request()
        localSearchRequest.naturalLanguageQuery = searchBar.text
        let region = MKCoordinateRegion(center: currentCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        localSearchRequest.region = region
        
        let localSearch = MKLocalSearch(request: localSearchRequest)
        localSearch.start { (response, _) in
            guard let response = response else { return }
            print("\(response.mapItems)")
            print("\(response.mapItems.count)")
            guard let primaryMapItem = response.mapItems.first else { return }
            self.getDirrections(to: primaryMapItem)
        }
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .blue
            renderer.lineWidth = 10
            return renderer
        }
        
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.strokeColor = .red
            renderer.fillColor = .red
            renderer.alpha = 0.5
            return renderer
        }
        
        return MKOverlayRenderer()
    }
}

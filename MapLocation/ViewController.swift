//
//  ViewController.swift
//  MapLocation
//
//  Created by Ivan Pedrero on 9/14/19.
//  Copyright © 2019 Ivan Pedrero. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate, UISearchBarDelegate, MKMapViewDelegate{

    @IBOutlet weak var map: MKMapView!

    let manager = CLLocationManager()
    
    var myLocation:CLLocationCoordinate2D?
    
    //Button to restore the location
    @IBAction func restoreButton(_ sender: Any) {
        goToLastLocation()
        getHospitals()
    }
    
    //Button that searches for location
    @IBAction func searchButton(_ sender: Any) {
        //Define the search bar
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        present(searchController, animated: true, completion: nil)
    }
    
    //Function that gets called when the search button is pressed
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        //Ignore the user
        UIApplication.shared.beginIgnoringInteractionEvents()
        
        //Activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .gray)
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        
        self.view.addSubview(activityIndicator)
        
        //Contract the keyboard and search field
        searchBar.resignFirstResponder()
        dismiss(animated: true, completion: nil)
        
        //Create the search request
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchBar.text
        
        let activeSearch = MKLocalSearch(request: searchRequest)
        
        activeSearch.start { (response, error) in
            
            activityIndicator.stopAnimating()
            UIApplication.shared.endIgnoringInteractionEvents()
            
            if response == nil{
                //No response from the query
                print(error as Any)
            }else{
                //Remove annotations from the map
                let annotations = self.map.annotations
                self.map.removeAnnotations(annotations)
                
                //Get the data
                let latitude = response?.boundingRegion.center.latitude
                let longitude = response?.boundingRegion.center.longitude
                
                //Create the annotation
                let annotation = MKPointAnnotation()
                annotation.title = searchBar.text
                annotation.coordinate = CLLocationCoordinate2DMake(latitude!, longitude!)
                self.map.addAnnotation(annotation)
                
                //Zoom in the annotation
                let coordinate: CLLocationCoordinate2D = CLLocationCoordinate2DMake(latitude!, longitude!)
                let span:MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                let region:MKCoordinateRegion = MKCoordinateRegion(center: coordinate, span: span)
                self.map.setRegion(region, animated: true)
                
                //Get directions
                self.getDirections(coordinate: coordinate)
                self.getHospitals()
            }
        }
    }
    
    //Function that will get the directions from searched place
    func getDirections(coordinate:CLLocationCoordinate2D){
        
        //Remove previous rendered lines
        self.map.removeOverlays(map.overlays)
        
        let directionsRequest = MKDirections.Request()
        directionsRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: myLocation!))
        directionsRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        directionsRequest.transportType = .automobile
        
        let directions = MKDirections(request: directionsRequest)
        directions.calculate{ (response, error) in
            guard let directionsResponse = response else {
                if let error = error {
                    print(error)
                }
                return
            }
            
            let route = directionsResponse.routes[0]
            self.map.addOverlay(route.polyline, level:.aboveRoads)
            
            let rect = route.polyline.boundingMapRect
            self.map.setRegion(MKCoordinateRegion(rect), animated: true)
        }
        
        self.map.delegate = self
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor.blue
        renderer.lineWidth = 3.0
        return renderer
    }
    
    //Function to go to last location
    func goToLastLocation(){
        self.map.removeOverlays(map.overlays)
        self.map.removeAnnotations(map.annotations)
        
        let span:MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        let region:MKCoordinateRegion = MKCoordinateRegion(center: myLocation!, span: span)
        map.setRegion(region, animated: true)
        self.map.showsUserLocation = true
    }
    
    //Function that updates whenever the location changes
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //Set the first location of the array as the latest
        let location = locations[0]
        
        //Set the zoom
        let span:MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        
        //Add our current location
        myLocation = CLLocationCoordinate2DMake(location.coordinate.latitude, location.coordinate.longitude)
        
        //Add the region
        let region:MKCoordinateRegion = MKCoordinateRegion(center: myLocation!, span: span)
        
        //Set the region to zoom in and present it
        map.setRegion(region, animated: true)
        self.map.showsUserLocation = true
    }
    
    func getHospitals(){
        let annotations = self.map.annotations
        self.map.removeAnnotations(annotations)
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "Hospital"
        request.region = self.map.region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else {
                print(error!)
                return
            }
            
            for mapItem in response.mapItems {
                // Display the received items
                let latitude = mapItem.placemark.location?.coordinate.latitude
                let longitude = mapItem.placemark.location?.coordinate.longitude
                
                let hospital = MKPointAnnotation()
                hospital.title = mapItem.name! //Only do `!` if you are sure that it isn't nil
                hospital.coordinate = CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!)
                self.map.addAnnotation(hospital)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager.delegate = self                             //The manager will be in this screen controller
        manager.desiredAccuracy = kCLLocationAccuracyBest   //We need the best location
        /*
         Yoltic, here you have to request the authorization using BIOMETRICS instead of the requestInUse()
         */
        manager.requestWhenInUseAuthorization()             //Request authorization
        manager.startUpdatingLocation()                     //Start updating the location for the app
        
        getHospitals()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


}


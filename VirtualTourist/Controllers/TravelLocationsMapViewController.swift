//
//  TravelLocationsMapViewController.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 3/1/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController, NSFetchedResultsControllerDelegate, MKMapViewDelegate {
    
    var editingPin = false
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var lastEditLabel: UILabel!
    
    @IBAction func toggleEdit(_ sender: AnyObject) {
        editingPin = !editingPin
        
        let button = sender as! UIBarButtonItem
        button.title = button.title == "Edit" ? "Done": "Edit"
        
        // Commit the changes to core data after editing
        if !editingPin {
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
    
    // MARK: - Core Data
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = { () -> NSFetchedResultsController<NSFetchRequestResult> in
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName:"Pin")
        request.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: true)]
        print(request.entityName ?? "N/A")
        
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
    }()

    // MARK: - Viewcontroller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load previous region
        restoreMapRegion(true)
        
        // Assign the long touch gesture to add pin
        let longTouch = UILongPressGestureRecognizer(target: self, action: #selector(addPin(_:)))
        mapView.addGestureRecognizer(longTouch)
        
        // Fetch the objects
        do {
            try fetchedResultsController.performFetch()
        } catch {}
        
        // Delegation assignments
        fetchedResultsController.delegate = self
        mapView.delegate = self
        
        // Populate the map view
        guard let pins = fetchedResultsController.fetchedObjects as? [Pin] else {
            return
        }
        
        // Place past pins onto the map
        for pin in pins {
            let pointAnnotation = MKPointAnnotation()
            pointAnnotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            
            self.mapView.addAnnotation(pointAnnotation)
        }
    }
    
    // MARK: - NSFetchedResultsController
    
    var operationQueue: [BlockOperation]!
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        operationQueue = [BlockOperation]()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            let operation = BlockOperation(block: { () -> Void in
                let pin = anObject as! Pin
                let pointAnnotation = MKPointAnnotation()
                pointAnnotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                
                self.mapView.addAnnotation(pointAnnotation)
            })
            operationQueue.append(operation)
        default: break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        for operation in operationQueue {
            operation.start()
        }
        operationQueue = nil
    }
    
    // MARK: - MKMapViewDelegate methods
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseablePinIdentifier = "Pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseablePinIdentifier) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseablePinIdentifier)
        } else {
            pinView!.annotation = annotation
        }
        
        pinView!.isDraggable = true
        pinView!.animatesDrop = true
        pinView!.pinTintColor = UIColor(red: 16.0/255, green: 58.0/255, blue: 143.0/255, alpha: 1.0)
        
        // Add a tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(pinTapped(_:)))
        pinView!.addGestureRecognizer(tapGesture)
        
        return pinView
    }
    
    // Current Object Dragging
    var currentPinToMove: Pin!
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        
        switch newState {
        case .starting:
            let coordinate = view.annotation!.coordinate
            
            // Get the object that has the starting Coordinate
            let pins = fetchedResultsController.fetchedObjects as! [Pin]
            guard let index = pins.firstIndex(where: { (pin) -> Bool in
                return pin.latitude == coordinate.latitude && pin.longitude == coordinate.longitude
            }) else { return }
            
            currentPinToMove = pins[index]
            
            currentPinToMove.removePhotos()
            
            // End all other network task to focus on this current pin
            Flickr.sharedInstance().cancelAllNetworkTask()
        case .ending:
            let coordinate = view.annotation!.coordinate
            currentPinToMove.longitude = coordinate.longitude
            currentPinToMove.latitude = coordinate.latitude
            
            // Dictionary used to fetch the new photos
            let dictionary = [
                Pin.Keys.Latitude: coordinate.latitude,
                Pin.Keys.Longitude: coordinate.longitude,
                Flickr.ParameterKeys.Page: 1
            ]
            
            // Create the photo objects and assignment to the pin
            Flickr.sharedInstance().retrieveImages(currentPinToMove, dictionary: dictionary, completionHandler: nil)
            
            currentPinToMove = nil
        default: break
        }
        
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveRegion()
    }
    
    // MARK: - Selectors
    
    @objc func addPin(_ gesture: UILongPressGestureRecognizer) {
        
        // While the user is editing, adding pins is not available
        guard editingPin == false else {
            return
        }
        
        switch gesture.state {
        case .began:
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            let pointAnnotation = MKPointAnnotation()
            pointAnnotation.coordinate = coordinate
            
            let dictionary = [
                Pin.Keys.Longitude: coordinate.longitude,
                Pin.Keys.Latitude: coordinate.latitude,
                Flickr.ParameterKeys.Page: 1
            ]
            
            // Create the pin object and save it to core data
            let newPin = Pin(dictionary: dictionary as [String : AnyObject], context: sharedContext)
            CoreDataStackManager.sharedInstance().saveContext()
            
            DispatchQueue.global(qos: .userInteractive).async {
                // Create the photo objects and assignment to the pin
                Flickr.sharedInstance().retrieveImages(newPin, dictionary: dictionary, completionHandler: nil)

            }

        default: break
        }
    }
    
    // The first scene consist of 2 states which are editingPin/!editingPin
    // If editingPin, then a tap gesture on a pin would be to delete it
    // Otherwise, go to the photo album
    @objc func pinTapped(_ gesture: UITapGestureRecognizer) {
        let pinView = gesture.view as! MKPinAnnotationView

        if !editingPin {
            performSegue(withIdentifier: "ShowPhotos", sender: pinView)
        } else {
            // Cancel all network task
            Flickr.sharedInstance().cancelAllNetworkTask()

            // Deleting pins
            
            // Grab all the pins
            let pins = fetchedResultsController.fetchedObjects as! [Pin]

            // Grab the pin index associated with the coordinate
            let index = pins.firstIndex(where: { (pin) -> Bool in
                pin.latitude == pinView.annotation!.coordinate.latitude && pin.longitude == pinView.annotation!.coordinate.longitude
            })
            
            // Check if there is a pin associated with this coordinate (of course)
            guard let nonOptionalIndex = index else {
                print("Could not find the pin in that coordinate")
                return
            }
            
            // The pin to be deleted, but won't be 
            // completely deleted until the done button is pressed.
            let pin = pins[nonOptionalIndex]
            
            // 1. Remove the photos associated with this pin on cache and disk
            pin.removePhotos()
            
            // 2. Delete the object itself
            self.sharedContext.delete(pin)
            
            mapView.removeAnnotation(pinView.annotation!)
        }
    }
    
    // MARK: - Helper methods
    
    var mapRegionSettingsFilePath: String {
        let manager = FileManager.default
        let url = manager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return url.appendingPathComponent("mapRegionArchive").path
    }
    
    func restoreMapRegion(_ animated: Bool) {
        guard let mapSettings = NSKeyedUnarchiver.unarchiveObject(withFile: mapRegionSettingsFilePath) as? [String: AnyObject] else {
            // First run
            return
        }
        
        let longitudeDelta = mapSettings["longitudeDelta"] as! CLLocationDegrees
        let latitudeDelta = mapSettings["latitudeDelta"] as! CLLocationDegrees
        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    
        let longitude = mapSettings["longitude"] as! CLLocationDegrees
        let latitude = mapSettings["latitude"] as! CLLocationDegrees
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: animated)
    }
    
    func saveRegion() {
        let dictionary = [
            "longitudeDelta": mapView.region.span.longitudeDelta,
            "latitudeDelta": mapView.region.span.latitudeDelta,
            "longitude": mapView.region.center.longitude,
            "latitude": mapView.region.center.latitude
        ]
        
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: mapRegionSettingsFilePath)
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Set the back button
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "OK", style: .plain, target: nil, action: nil)
        
        if segue.identifier == "ShowPhotos" {
            // Get the senders coordinates
            let coordinate = (sender as! MKPinAnnotationView).annotation!.coordinate
            
            // Destination
            let destination = segue.destination as! PhotoAlbumViewController
            
            destination.coordinate = coordinate
            
            // Get the pin associated with the coordinate
            let allPins = fetchedResultsController.fetchedObjects as! [Pin]
            guard let index = allPins.firstIndex(where: { (pin) -> Bool in
                pin.latitude == coordinate.latitude && pin.longitude == coordinate.longitude
            }) else { return }
            
            let pin = allPins[index]
            
            destination.pin = pin
        }     }
    
}

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
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var mapView: MKMapView!
    
    // MARK: - Core Data
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let request = NSFetchRequest(entityName: "Pin")
        request.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: true)]
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
    }()

    // MARK: - Viewcontroller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Load previous region
        restoreMapRegion(true)
        
        // Assign the long touch gesture to add pin
        let longTouch = UILongPressGestureRecognizer(target: self, action: "addPin:")
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
    
    var operationQueue: [NSBlockOperation]!
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        operationQueue = [NSBlockOperation]()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type {
        case .Insert:
            let operation = NSBlockOperation(block: { () -> Void in
                let pin = anObject as! Pin
                let pointAnnotation = MKPointAnnotation()
                pointAnnotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                
                self.mapView.addAnnotation(pointAnnotation)
            })
            operationQueue.append(operation)
        default: break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        for operation in operationQueue {
            operation.start()
        }
        operationQueue = nil
    }
    
    // MARK: - MKMapViewDelegate methods
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseablePinIdentifier = "Pin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseablePinIdentifier) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseablePinIdentifier)
        } else {
            pinView!.annotation = annotation
        }
        
        pinView!.draggable = true
        pinView!.animatesDrop = true
        pinView!.pinTintColor = UIColor(red: 1.0, green: 127.0/255.0, blue: 0.0, alpha: 1.0)
        
        // Add a tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: "presentPhotos:")
        pinView!.addGestureRecognizer(tapGesture)
        
        return pinView
    }
    
    // Current Object Dragging
    var currentPinToMove: Pin!
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        switch newState {
        case .Starting:
            let coordinate = view.annotation!.coordinate
            
            // Get the object that has the starting Coordinate
            let pins = fetchedResultsController.fetchedObjects as! [Pin]
            guard let index = pins.indexOf({ (pin) -> Bool in
                return pin.latitude == coordinate.latitude && pin.longitude == coordinate.longitude
            }) else { return }
            
            currentPinToMove = pins[index]
            
            // Delete all older photos and get ready for new ones!
            for photo in currentPinToMove.photos {
                photo.pin = nil
            }
            
        case .Ending:
            let coordinate = view.annotation!.coordinate
            currentPinToMove.longitude = coordinate.longitude
            currentPinToMove.latitude = coordinate.latitude
            
            // Dictionary used to fetch the new photos
            let dictionary = [
                Pin.Keys.Latitude: coordinate.latitude,
                Pin.Keys.Longitude: coordinate.longitude,
                FlickrNetworkRequest.ParameterKeys.Page: 1
            ]
            
            // Create the photo objects and assignment to the pin
            FlickrNetworkRequest.sharedInstance().retrieveImages(currentPinToMove, dictionary: dictionary)
            
            currentPinToMove = nil
        default: break
        }
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveRegion()
    }
    
    // MARK: - Selectors
    
    func addPin(gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .Began:
            let point = gesture.locationInView(mapView)
            let coordinate = mapView.convertPoint(point, toCoordinateFromView: mapView)
            
            let pointAnnotation = MKPointAnnotation()
            pointAnnotation.coordinate = coordinate
            
            let dictionary = [
                Pin.Keys.Longitude: coordinate.longitude,
                Pin.Keys.Latitude: coordinate.latitude,
                FlickrNetworkRequest.ParameterKeys.Page: 1
            ]
            
            // Create the pin object and save it to core data
            let newPin = Pin(dictionary: dictionary, context: sharedContext)
            CoreDataStackManager.sharedInstance().saveContext()
            
            // Create the photo objects and assignment to the pin
            FlickrNetworkRequest.sharedInstance().retrieveImages(newPin, dictionary: dictionary)
            
        default: break
        }
    }
    
    func presentPhotos(gesture: UITapGestureRecognizer) {
        let pinView = gesture.view as! MKPinAnnotationView
        performSegueWithIdentifier("ShowPhotos", sender: pinView)
    }
    
    // MARK: - Helper methods
    
    var mapRegionSettingsFilePath: String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    func restoreMapRegion(animated: Bool) {
        guard let mapSettings = NSKeyedUnarchiver.unarchiveObjectWithFile(mapRegionSettingsFilePath) as? [String: AnyObject] else {
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
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowPhotos" {
            // Set the back button
            navigationItem.backBarButtonItem = UIBarButtonItem(title: "OK", style: .Plain, target: nil, action: nil)
            
            // Get the senders coordinates
            let coordinate = (sender as! MKPinAnnotationView).annotation!.coordinate
            
            // Destination
            let destination = segue.destinationViewController as! PhotoAlbumViewController
            
            destination.coordinate = coordinate
        }
    }
    
}

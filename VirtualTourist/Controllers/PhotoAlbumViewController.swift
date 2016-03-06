//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 3/1/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDelegate {
    
    var coordinate: CLLocationCoordinate2D!
    
    // MARK: - Core Data
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let request = NSFetchRequest(entityName: "Photo")
        
        request.predicate = NSPredicate(format: "pin.longitude = %lf AND pin.latitude = %lf", self.coordinate.longitude, self.coordinate.latitude)
        request.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: true)]
        
        return NSFetchedResultsController(fetchRequest: request, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
    }()
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    // MARK: - Viewcontroller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Map setup
        
        // Region
        let span = MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
        
        // Pin
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        
        do {
            try fetchedResultsController.performFetch()
        } catch {}
        
        // Collection view flowlayout setup
        
        flowLayout.minimumInteritemSpacing = gapSize
        flowLayout.minimumLineSpacing = gapSize
        
        // Delegate
        mapView.delegate = self
        fetchedResultsController.delegate = self
        
        guard let photo = fetchedResultsController.fetchedObjects?.first as? Photo, let pin = photo.pin else {
            print("The photo has no pin... or something is wrong")
            return
        }
        
        let latitude = pin.latitude
        let longitude = pin.longitude
        
        // TODO: Check if the pin has all of it's photos.
        
        // TODO: Delete - Everything below is for debugging purposes
        print("long: \(longitude), lat: \(latitude)")
        
        guard let count = fetchedResultsController.fetchedObjects?.count else {
            print("fetchedResultsController Changed nothing")
            return
        }
        
        print(count)
    }
    
    
    // MARK: - UICollectionViewDelegateFlowLayout methods
    
    let gapSize: CGFloat = 2.0
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let dimension = (view.bounds.size.width - (gapSize*2.0))/3.0
        return CGSize(width: dimension, height: dimension)
    }
    
    
    // MARK: - MKMapVieWDelegate methods
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseableMapIdentifier = "Pin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseableMapIdentifier) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseableMapIdentifier)
        } else {
            pinView!.annotation = annotation
        }
        
        pinView!.pinTintColor = UIColor(red: 1.0, green: 127.0/255.0, blue: 0.0, alpha: 1.0)
        
        return pinView
    }
    
    
    // MARK: - NSFetchedResultsControllerDelegate methods
    var operationQueue: [NSBlockOperation]!
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        operationQueue = [NSBlockOperation]()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Update:
            let updatedPhoto = anObject as! Photo
            let operation = NSBlockOperation(block: { () -> Void in
                // Check if the indexpath is nil
                guard let indexPath = indexPath else {
                    print("Can not update this indexPath")
                    return
                }
                
                // Grab the cell at a the specified index, if the index is not available - the image is not ready.
                guard let cell = self.collectionView.cellForItemAtIndexPath(indexPath) as? PhotoCollectionViewCell else {
                    print("Can not retrieve item as a PhotoCollectionViewCell")
                    return
                }
                
                guard let imageData = updatedPhoto.image else {
                    print("Corrupt image data")
                    return
                }
                
                cell.photoView.image = UIImage(data: imageData)
                if cell.activityIndicator.isAnimating() {
                    cell.toggleUI()
                }
            })
            operationQueue.append(operation)
        case .Insert:
            let operation = NSBlockOperation(block: { () -> Void in
                self.collectionView.reloadData()
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
    
    
    // MARK: - UICollectionViewDataSource methods
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects!.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let reuseableCellIdentifier = "PhotoCell"
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseableCellIdentifier, forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        // Check if the photo is ready
        guard let photo = fetchedResultsController.fetchedObjects?[indexPath.row] as? Photo,let imageData = photo.image else {
            return cell
        }
        
        cell.photoView.image = UIImage(data: imageData)
        if cell.activityIndicator.isAnimating() {
            cell.toggleUI()
        }
        
        return cell
    }
    
    
    // MARK: - UICollectionViewDelegate
    
    // TODO: New VC to view the photo (Maybe)
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        print("Item Selected")
    }
    
}

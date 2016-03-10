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
    var pin: Pin!   // Used to refresh the photos
    
    // MARK: - Core Data
    
    // Using this to monitor changes
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
    @IBOutlet weak var toolbarButton: UIBarButtonItem!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
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
        
    
        // Check if the task loading the photo objects is currently loading.
        if let state = pin.task?.state {
            toggleUI()

            switch state {
            case .Running: print("Disabling the UI - Running")
            case .Canceling: print("Disabling the UI - Canceling"); pin.task?.resume()
            case .Completed: print("Completed"); checkToEnableUI()
            case .Suspended: print("Suspended"); pin.task?.resume();
            }
        }
        
        // Collection view flowlayout setup
        
        flowLayout.minimumInteritemSpacing = gapSize
        flowLayout.minimumLineSpacing = gapSize
        
        // Delegate
        mapView.delegate = self
        fetchedResultsController.delegate = self
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
        
        pinView!.pinTintColor = UIColor(red: 16.0/255, green: 58.0/255, blue: 143.0/255, alpha: 1.0)
        
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
            print("Updating")
            let operation = NSBlockOperation(block: { () -> Void in
                guard let indexPath = indexPath else {
                    return
                }
                
                guard let cell = self.collectionView.cellForItemAtIndexPath(indexPath) as? PhotoCollectionViewCell else {
                    return
                }
                
                let updatedPhoto = anObject as! Photo
                cell.photoView.image = updatedPhoto.image
                if cell.activityIndicator.isAnimating() {
                    cell.toggleUI()
                }
            })
            
            self.checkToEnableUI()
            operationQueue.append(operation)
        case .Delete:
            let operation = NSBlockOperation(block: { () -> Void in
                guard let indexPath = indexPath else {
                    return
                }
                
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            })
            operationQueue.append(operation)
        case .Insert:
            print("Inserting")
            let operation = NSBlockOperation(block: { () -> Void in
                guard let indexPath = newIndexPath else {
                    return
                }
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            })
            operationQueue.append(operation)
        default: break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        for operation in operationQueue {
            operation.start()
        }
        
        // self.checkToEnableUI()
        operationQueue = nil
    }
    
    // MARK: - UICollectionViewDataSource methods
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let reuseableCellIdentifier = "PhotoCell"
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseableCellIdentifier, forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        cell.photoView.image = UIImage(named: "placeholder")
        cell.activityIndicator.startAnimating()
        
        // Check if the photo is ready
        guard let photo = fetchedResultsController.fetchedObjects?[indexPath.row] as? Photo else {
            // We'll only be inside this block if the photo isn't there
            return cell
        }
        
        guard let image = photo.image else {
            // The photo does not have it's image property
            // Load the image 
            
            // But first cancel all other task to download this image
            NSURLSession.sharedSession().invalidateAndCancel()
            Flickr.sharedInstance().loadImagesWithSize(photo, size: Flickr.ImageSizesForURL.LargeSquare, completionHandler: nil)
            
            return cell
        }
        
        cell.photoView.image = image
        if cell.activityIndicator.isAnimating() {
            cell.toggleUI()
        }
        
        // Change alpha value based on whether the cell is selected
        let index = collectionView.indexPathsForSelectedItems()!.indexOf({(anIndexPath) -> Bool in
            return indexPath == anIndexPath
        })
        
        cell.alpha = index == nil ? 1.0: 0.5
        
        // Add the gesture to hold resulting in a pop up view that shows a larger photo
        let holdGesture = UILongPressGestureRecognizer(target: self, action: "displayLargerPhoto:")
        cell.addGestureRecognizer(holdGesture)
        
        return cell
    }
    
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        toggleSelection(indexPath)
        
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        toggleSelection(indexPath)        
    }
    
    // MARK: - IBActions
    
    @IBAction func toolBarButtonPressed(sender: AnyObject) {
        // Check what action we need to do by checking the selection count, remove or refresh
        guard let selectedIndexPaths = collectionView.indexPathsForSelectedItems() else {
            return
        }
        
        if selectedIndexPaths.count == 0 {
            // disable the UI
            toggleUI()
            
            if pin.photos.count != 0 {
                // First scroll all the way to to the top to prevent the snapshot warning
                // We know that there's an item at the first indexpath from the photo count
                collectionView.scrollToItemAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), atScrollPosition: .Top, animated: false)
            }
            
            // Reset the page if there isn't enough photos
            pin.page = pin.originalPhotoCount == 21 ? ++pin.page: 1
            
            let dictionary: [String: AnyObject] = [
                Pin.Keys.Longitude: coordinate.longitude,
                Pin.Keys.Latitude: coordinate.latitude,
                Flickr.ParameterKeys.Page: pin.page
            ]
            
            // Remove all photos related to this pin
            pin.removePhotos()
            
            Flickr.sharedInstance().retrieveImages(pin, dictionary: dictionary, completionHandler: nil)
            CoreDataStackManager.sharedInstance().saveContext()
        } else {
            // Create the dictionary send to the Update initializer
            let dictionary: [String: AnyObject] = [
                Update.Keys.Description: "Image(s) Deleted",
                Update.Keys.Latitude: pin.latitude,
                Update.Keys.Longitude: pin.longitude,
                Update.Keys.NumberOfItems: selectedIndexPaths.count,
                Update.Keys.UpdateType: "Image Deletion"
            ]
            
            // Create an update
            let _ = Update(dictionary: dictionary, context: sharedContext)
            
            // Sort the index paths for deletion, backwards
            let reverseSortedIndexPaths = selectedIndexPaths.sort({ (i1, i2) -> Bool in
                i1.row > i2.row
            })
            
            for indexPath in reverseSortedIndexPaths {
                guard let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as? Photo else {
                    print("Invalid index at \(indexPath.row)")
                    return
                }
                
                // Remove the photos (underlying document objects are being deleted by the managedobject preparefordelete
                self.fetchedResultsController.managedObjectContext.deleteObject(photo)
                CoreDataStackManager.sharedInstance().saveContext()
            }
        }
        
        // After deletion, toggle the bar button title
        toggleSelection(nil)
    }
    
    // MARK: - Selectors
    
    func displayLargerPhoto(gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .Began: break  // Will display the imagePopUpView
        case .Ended: break  // Will remove the imagePopUpView
        default: break
        }
    }
    
    // MARK: - Helper methods
    
    func toggleSelection(indexPath: NSIndexPath?) {
        if let indexPath = indexPath {
            let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
            cell.alpha = cell.alpha == 1.0 ? 0.5: 1.0
        }
        
        // If there is more than one indexpath selected
        guard let count = collectionView.indexPathsForSelectedItems()?.count else {
            return
        }
        
        toolbarButton.title = count > 0 ? "Remove Selected Pictures": "New Collection"
    }
    
    func toggleUI() {
        activityIndicator.isAnimating() ? activityIndicator.stopAnimating(): activityIndicator.startAnimating()
        toolbarButton.enabled = !toolbarButton.enabled
    }
    
    func checkToEnableUI() -> Bool {
        // Check if there are any other photos loading
        let photos = self.fetchedResultsController.fetchedObjects as! [Photo]
        let unloadedPhotos = photos.filter {!$0.imageLoaded}
        
        print(unloadedPhotos.count)
        
        // There are no photos that are still loading, if stopped here
        // Enable the toolbarbutton and stop the activity indicator
        guard unloadedPhotos.count > 0 else {
            print("Enabling UI")
            self.toolbarButton.enabled = true
            self.activityIndicator.stopAnimating()
            
            return true
        }
        
        return false
    }
}

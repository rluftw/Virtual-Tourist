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
    var imagePopUpView: ImagePopUpView?
    
    // MARK: - Core Data
    
    // Using this to monitor changes
    lazy var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> = { () -> NSFetchedResultsController<NSFetchRequestResult> in
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Photo")
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
            case .running: print("Disabling the UI - Running")
            case .canceling: print("Disabling the UI - Canceling"); pin.task?.resume()
            case .completed: print("Completed"); _ = checkToEnableUI()
            case .suspended: print("Suspended"); pin.task?.resume();
            @unknown default: fatalError()
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
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let dimension = (view.bounds.size.width - (gapSize*2.0))/3.0
        return CGSize(width: dimension, height: dimension)
    }
    
    
    // MARK: - MKMapVieWDelegate methods
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseableMapIdentifier = "Pin"
        
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseableMapIdentifier) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseableMapIdentifier)
        } else {
            pinView!.annotation = annotation
        }
        
        pinView!.pinTintColor = UIColor(red: 16.0/255, green: 58.0/255, blue: 143.0/255, alpha: 1.0)
        
        return pinView
    }
    
    
    // MARK: - NSFetchedResultsControllerDelegate methods
    
    var operationQueue: [BlockOperation]!
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        operationQueue = [BlockOperation]()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        switch type {
        case .update:
            print("Updating")
            let operation = BlockOperation(block: { () -> Void in
                guard let indexPath = indexPath else {
                    return
                }
                
                guard let cell = self.collectionView.cellForItem(at: indexPath) as? PhotoCollectionViewCell else {
                    return
                }
                
                let updatedPhoto = anObject as! Photo
                cell.photoView.image = updatedPhoto.image
                if cell.activityIndicator.isAnimating {
                    cell.toggleUI()
                }
                
                // Add the gesture to hold resulting in a pop up view that shows a larger photo
                let holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.displayLargerPhoto(_:)))
                cell.addGestureRecognizer(holdGesture)
            })
            
            _ = self.checkToEnableUI()
            operationQueue.append(operation)
        case .delete:
            let operation = BlockOperation(block: { () -> Void in
                guard let indexPath = indexPath else {
                    return
                }
                
                self.collectionView.deleteItems(at: [indexPath])
            })
            operationQueue.append(operation)
        case .insert:
            print("Inserting")
            let operation = BlockOperation(block: { () -> Void in
                guard let indexPath = newIndexPath else {
                    return
                }
                self.collectionView.insertItems(at: [indexPath])
            })
            operationQueue.append(operation)
        default: break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        for operation in operationQueue {
            operation.start()
        }
        
        // self.checkToEnableUI()
        operationQueue = nil
    }
    
    // MARK: - UICollectionViewDataSource methods
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reuseableCellIdentifier = "PhotoCell"
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseableCellIdentifier, for: indexPath) as! PhotoCollectionViewCell
        
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
            URLSession.shared.invalidateAndCancel()
            _ = Flickr.sharedInstance().loadImagesWithSize(photo, size: Flickr.ImageSizesForURL.LargeSquare, completionHandler: nil, photoDataHandler: nil)
            
            return cell
        }
        
        cell.photoView.image = image
        if cell.activityIndicator.isAnimating {
            cell.toggleUI()
        }
        
        // Change alpha value based on whether the cell is selected
        let index = collectionView.indexPathsForSelectedItems!.firstIndex(where: {(anIndexPath) -> Bool in
            return indexPath == anIndexPath
        })
        
        cell.alpha = index == nil ? 1.0: 0.5
        
        // Add the gesture to hold resulting in a pop up view that shows a larger photo
        let holdGesture = UILongPressGestureRecognizer(target: self, action: #selector(displayLargerPhoto(_:)))
        cell.addGestureRecognizer(holdGesture)
        
        return cell
    }
    
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        toggleSelection(indexPath)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        toggleSelection(indexPath)        
    }
    
    // MARK: - IBActions
    
    @IBAction func toolBarButtonPressed(_ sender: AnyObject) {
        // Check what action we need to do by checking the selection count, remove or refresh
        guard let selectedIndexPaths = collectionView.indexPathsForSelectedItems else {
            return
        }
        
        if selectedIndexPaths.count == 0 {
            // disable the UI
            toggleUI()
            
            if pin.photos.count != 0 {
                // First scroll all the way to to the top to prevent the snapshot warning
                // We know that there's an item at the first indexpath from the photo count
                collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
            }
            
            // Reset the page if there isn't enough photos
            pin.page = (pin.originalPhotoCount == 21) ? NSNumber(value: 1+pin.page.intValue): NSNumber(value: 1)
            
            let dictionary: [String: AnyObject] = [
                Pin.Keys.Longitude: coordinate.longitude as AnyObject,
                Pin.Keys.Latitude: coordinate.latitude as AnyObject,
                Flickr.ParameterKeys.Page: pin.page as AnyObject
            ]
            
            // Remove all photos related to this pin
            pin.removePhotos()
            
            Flickr.sharedInstance().retrieveImages(pin, dictionary: dictionary, completionHandler: nil)
            CoreDataStackManager.sharedInstance().saveContext()
        } else {
            // Create the dictionary send to the Update initializer
            let dictionary: [String: AnyObject] = [
                Update.Keys.Description: "Image(s) Deleted" as AnyObject,
                Update.Keys.Latitude: pin.latitude as AnyObject,
                Update.Keys.Longitude: pin.longitude as AnyObject,
                Update.Keys.NumberOfItems: selectedIndexPaths.count as AnyObject,
                Update.Keys.UpdateType: "Image Deletion" as AnyObject
            ]
            
            // Create an update
            let _ = Update(dictionary: dictionary, context: sharedContext)
            
            // Sort the index paths for deletion, backwards
            let reverseSortedIndexPaths = selectedIndexPaths.sorted(by: { (i1, i2) -> Bool in
                i1.row > i2.row
            })
            
            for indexPath in reverseSortedIndexPaths {
                guard let photo = self.fetchedResultsController.object(at: indexPath) as? Photo else {
                    print("Invalid index at \(indexPath.row)")
                    return
                }
                
                // Remove the photos (underlying document objects are being deleted by the managedobject preparefordelete
                self.fetchedResultsController.managedObjectContext.delete(photo)
                CoreDataStackManager.sharedInstance().saveContext()
            }
        }
        
        // After deletion, toggle the bar button title
        toggleSelection(nil)
    }
    
    // MARK: - Selectors
    
    @objc func displayLargerPhoto(_ gesture: UILongPressGestureRecognizer) {
        let cell = gesture.view as! PhotoCollectionViewCell
        if !cell.activityIndicator.isAnimating {
            switch gesture.state {
            case .began:
                let cell = gesture.view as! PhotoCollectionViewCell
                guard let indexPath = collectionView.indexPath(for: cell) else {
                    print("Cell not in this indexPath")
                    return
                }
                
                let photo = fetchedResultsController.fetchedObjects![indexPath.row] as! Photo
                
                imagePopUpView = ImagePopUpView.imagePopUpViewInView(view, animated: true, photo: photo)
            case .ended:
                imagePopUpView?.removeFromSuperview()
                imagePopUpView = nil
            default: break
            }
        } else {
            print("Small photo still loading")
        }
    }
    
    // MARK: - Helper methods
    
    func toggleSelection(_ indexPath: IndexPath?) {
        if let indexPath = indexPath {
            let cell = collectionView.cellForItem(at: indexPath) as! PhotoCollectionViewCell
            cell.alpha = cell.alpha == 1.0 ? 0.5: 1.0
        }
        
        // If there is more than one indexpath selected
        guard let count = collectionView.indexPathsForSelectedItems?.count else {
            return
        }
        
        toolbarButton.title = count > 0 ? "Remove Selected Pictures": "New Collection"
    }
    
    func toggleUI() {
        activityIndicator.isAnimating ? activityIndicator.stopAnimating(): activityIndicator.startAnimating()
        toolbarButton.isEnabled = !toolbarButton.isEnabled
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
            self.toolbarButton.isEnabled = true
            self.activityIndicator.stopAnimating()
            
            return true
        }
        
        return false
    }
}

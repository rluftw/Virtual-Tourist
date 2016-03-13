//
//  Pins.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 2/27/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import Foundation
import CoreData
import MapKit

// TODO: Test if the pins are actually being deleted

class Pin: NSManagedObject {
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var dateCreated: NSDate
    @NSManaged var photos: [Photo]
    
    // Used for paginating through the photo search API
    // Increment if new photos are requested.
    @NSManaged var page: Int
    
    // This is to check if the photo collection has been modified. (i.e deleted some photos)
    @NSManaged var originalPhotoCount: Int
    
    // A task related to this pin, can be used to check if the task state
    var task: NSURLSessionTask?
    
    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // Assign the creation time to this managed object.
        self.dateCreated = NSDate()
        
        self.latitude = dictionary[Keys.Latitude] as! Double
        self.longitude = dictionary[Keys.Longitude] as! Double
        
        self.page = dictionary[Flickr.ParameterKeys.Page] as! Int
    }
    
    override func prepareForDeletion() {
        print("Preparing to delete the pin at - lat: \(latitude), long: \(longitude)")
    }
    
    func removePhotos() {
        guard photos.count > 0 else {
            return
        }
        
        // Create the dictionary send to initialize an update object
        let dictionary: [String: AnyObject] = [
            Update.Keys.Description: "Image(s) Deleted",
            Update.Keys.Latitude: latitude,
            Update.Keys.Longitude: longitude,
            Update.Keys.NumberOfItems: photos.count,
            Update.Keys.UpdateType: "Image Deletion"
        ]
        
        let _ = Update(dictionary: dictionary, context: CoreDataStackManager.sharedInstance().managedObjectContext)
        
        
        // Remove previous photos
        for photo in photos {
            // Delete the image associated with this photo object
            photo.image = nil
    
            // Take the photo out of the pin for core data
            photo.pin = nil
            
            // Delete the entire photo object from core data, and save
            CoreDataStackManager.sharedInstance().managedObjectContext.deleteObject(photo)
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
}
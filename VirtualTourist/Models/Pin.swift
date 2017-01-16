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
    @NSManaged var dateCreated: Date
    @NSManaged var photos: [Photo]
    
    // Used for paginating through the photo search API
    // Increment if new photos are requested.
    @NSManaged var page: NSNumber
    
    // This is to check if the photo collection has been modified. (i.e deleted some photos)
    @NSManaged var originalPhotoCount: Int
    
    // A task related to this pin, can be used to check if the task state
    var task: URLSessionTask?
    
    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
    }
    
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    init(dictionary: [String: Any], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Pin", in: context)!
        super.init(entity: entity, insertInto: context)
        
        // Assign the creation time to this managed object.
        self.dateCreated = Date()
        
        self.latitude = dictionary[Keys.Latitude] as! Double
        self.longitude = dictionary[Keys.Longitude] as! Double
        
        self.page = dictionary[Flickr.ParameterKeys.Page] as! NSNumber
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
            Update.Keys.Description: "Image(s) Deleted" as AnyObject,
            Update.Keys.Latitude: latitude as AnyObject,
            Update.Keys.Longitude: longitude as AnyObject,
            Update.Keys.NumberOfItems: photos.count as AnyObject,
            Update.Keys.UpdateType: "Image Deletion" as AnyObject
        ]
        
        let _ = Update(dictionary: dictionary, context: CoreDataStackManager.sharedInstance().managedObjectContext)
        
        
        // Remove previous photos
        for photo in photos {
            // Delete the image associated with this photo object
            photo.image = nil
    
            // Take the photo out of the pin for core data
            photo.pin = nil
            
            // Delete the entire photo object from core data, and save
            CoreDataStackManager.sharedInstance().managedObjectContext.delete(photo)
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
}

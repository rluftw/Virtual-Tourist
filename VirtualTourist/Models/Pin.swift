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

class Pin: NSManagedObject {
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var dateCreated: NSDate
    @NSManaged var photos: [Photo]
    
    // Used for paginating through the photo search API
    // Increment if new photos are requested.
    @NSManaged var page: Int
    
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
        
        self.page = dictionary[FlickrNetworkRequest.ParameterKeys.Page] as! Int
    }
}
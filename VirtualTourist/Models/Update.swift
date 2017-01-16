//
//  LastUpdated.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 3/7/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import Foundation
import CoreData

class Update: NSManagedObject {
    @NSManaged var dateCreated: Date
    @NSManaged var updateType: String
    @NSManaged var updateDescription: String
    @NSManaged var numberOfItems: Int
    @NSManaged var longitude: Double
    @NSManaged var latitude: Double 
    
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    struct Keys {
        static let Description = "updateDescription"
        static let NumberOfItems = "numberOfItems"
        static let Longitude = "longitude"
        static let Latitude = "latitude"
        static let UpdateType = "type"
    }
    
    init(dictionary: [String: Any], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Update", in: context)
        super.init(entity: entity!, insertInto: context)
        
        self.updateType = dictionary[Keys.UpdateType] as! String
        self.updateDescription = dictionary[Keys.Description] as! String
        self.longitude = dictionary[Keys.Longitude] as! Double
        self.latitude = dictionary[Keys.Latitude] as! Double
        self.numberOfItems = dictionary[Keys.NumberOfItems] as! Int
        
        self.dateCreated = Date()
    }
}

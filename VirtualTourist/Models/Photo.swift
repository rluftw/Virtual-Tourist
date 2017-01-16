//
//  Photo.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 2/26/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class Photo: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var owner: String
    @NSManaged var secret: String
    @NSManaged var server: String
    @NSManaged var title: String
    @NSManaged var pin: Pin?
    @NSManaged var dateCreated: Date
    @NSManaged var farm: Int
    @NSManaged var imageLoaded: Bool
    
    @NSManaged var imagePath: String
    
    struct Keys {
        static let ID = "id"
        static let Owner = "owner"
        static let Secret = "secret"
        static let Server = "server"
        static let Title = "title"
        static let Farm = "farm"
    }
    
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    init(dictionary: [String: Any], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Photo", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.dateCreated = Date()
        
        self.id = dictionary[Keys.ID] as! String
        self.owner = dictionary[Keys.Owner] as! String
        self.secret = dictionary[Keys.Secret] as! String
        self.server = dictionary[Keys.Server] as! String
        self.title = dictionary[Keys.Title] as! String
        self.farm = dictionary[Keys.Farm] as! Int
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddGHHmmsszzz"
        
        self.imagePath = "/\(formatter.string(from: dateCreated))_\(self.id)_\(self.secret)_q.jpg"
        
        // Used to notify fetchresultscontroller
        self.imageLoaded = false
    }

    override func prepareForDeletion() {
        super.prepareForDeletion()
        
        // Removes the image from cache and disk
        image = nil
    }
    
    // Image
    var image: UIImage? {
        get {
            return Flickr.Caches.imageCache.imageWithIdentifier(imagePath)
        }
        set {
            Flickr.Caches.imageCache.storeImage(newValue, withIdentifier: imagePath)
        }
    }
}

//
//  ImageCache.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 3/6/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import Foundation
import UIKit

class ImageCache {
    
    fileprivate var inMemoryCache = NSCache<AnyObject, AnyObject>()
    
    // MARK: - Saving images
    
    func imageWithIdentifier(_ identifier: String) -> UIImage? {
        // Verify that the image is not an empty string
        guard identifier != "" else {
            print("Unable to retrieve photo due to invalid identifier")
            return nil
        }
        
        let path = pathForIdentifier(identifier)
        
        // First try the memory cache
        if let image = inMemoryCache.object(forKey: path as AnyObject) as? UIImage {
            return image
        }
        
        // Next Try the hard drive
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    // MARK: - Retrieving images
    
    func storeImage(_ image: UIImage?, withIdentifier identifier: String) {
        let path = pathForIdentifier(identifier)
        
        // if the image is nil, then remove the object that is already at the path
        if image == nil {
            inMemoryCache.removeObject(forKey: path as AnyObject)
            
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {}
            
            return
        }
        
        inMemoryCache.setObject(image!, forKey: path as AnyObject)
        
        let data = image!.pngData()!
        try? data.write(to: URL(fileURLWithPath: path), options: [.atomic])
    }
    
    // MARK: - Helper methods
    
    func pathForIdentifier(_ identifier: String) -> String {
        let documentsDirectoryURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullURL = documentsDirectoryURL.appendingPathComponent(identifier)
        
        return fullURL.path
    }
}

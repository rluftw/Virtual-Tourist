//
//  Flickr.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 2/26/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import Foundation
import UIKit

extension Flickr {
    
    // Convenience method - Retrieve all photo information
    
    func retrieveImages(pin: Pin, dictionary: [String: AnyObject], completionHandler: (()->Void)?) {
        let searchParameters: [String: AnyObject] = [
            ParameterKeys.APIKey: ParameterValues.APIKey,
            ParameterKeys.Format: ParameterValues.Format,
            ParameterKeys.NoJSONCallBack: ParameterValues.NoJSONCallBack,
            ParameterKeys.Method: Methods.PhotoSearchMethod,
            ParameterKeys.Privacy: ParameterValues.Privacy,
            ParameterKeys.Accuracy: ParameterValues.Accuracy,
            ParameterKeys.PerPage: ParameterValues.PerPage,
            ParameterKeys.Page: dictionary[ParameterKeys.Page] as! Int,
            ParameterKeys.Latitude: dictionary[Pin.Keys.Latitude] as! Double,
            ParameterKeys.Longitude: dictionary[Pin.Keys.Longitude] as! Double
        ]
        
        // 1. Search method to make the photo objects
        let task = httpGetRequest(searchParameters) { (result, error) -> Void in
            // make sure there are no errors
            guard error == nil else {
                print("(Long, Lat): (\(pin.longitude), \(pin.latitude)) - Retrieving the Image - Photo")
                return
            }
            
            // convert the result into a dictionary
            guard let result = result as? [String: AnyObject] else {
                print("(Long, Lat): (\(pin.longitude), \(pin.latitude)) - Invalid results - photo")
                return
            }
            
            // retrieve the photo dictionary and array
            guard let photoDictionary = result["photos"] as? [String: AnyObject], let photoArray = photoDictionary["photo"] as? [[String: AnyObject]] else {
                print("(Long, Lat): (\(pin.longitude), \(pin.latitude)) - Invalid positioning - Photo")
                return
            }
            
            pin.originalPhotoCount = photoArray.count
            
            // Check if the photo count is more than 0
            guard photoArray.count > 0 else {
                
                // Can't leave the UI hanging
                completionHandler?()
                return
            }
            
            // Create the dictionary send to the Update initializer
            let dictionary: [String: AnyObject] = [
                Update.Keys.Description: "Photo Object(s) Created",
                Update.Keys.Latitude: pin.latitude,
                Update.Keys.Longitude: pin.longitude,
                Update.Keys.NumberOfItems: photoArray.count,
                Update.Keys.UpdateType: "Photo Creation"
            ]
            
            let _ = Update(dictionary: dictionary, context: CoreDataStackManager.sharedInstance().managedObjectContext)
            
            // Use the photoArray and point it to the pin
            for photo in photoArray {
                // Needs to be on the main thread since we're using the default managedObjectContext
                // Created on the main thread
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    let newPhoto = Photo(dictionary: photo, context: CoreDataStackManager.sharedInstance().managedObjectContext)
                    
                    // Assign the photo to its pin
                    newPhoto.pin = pin

                    // This allows the empty boxes to appear before the photos are loaded
                    CoreDataStackManager.sharedInstance().saveContext()
                    
                    // 2. Create the photo URL and grab the image (prefetch)
                    self.loadImagesWithSize(newPhoto, size: ImageSizesForURL.LargeSquare, completionHandler: completionHandler)
                })
            }
        }
        
        pin.task = task
    }
    
    func loadImagesWithSize(photo: Photo, size: String, completionHandler: (()->Void)?) {
        let url = self.createPhotoURL(photo, withSize: size)
        let request = NSURLRequest(URL: url)
        let task = self.session.dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
            guard error == nil else {
                print("Photo ID: \(photo.id) - Error retrieving photo: \(error!.localizedDescription)")
                return
            }
            
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where 200...299 ~= statusCode else {
                print("Photo ID: \(photo.id) - Invalid Status code retrieving photo data")
                return
            }
            
            guard let data = data else {
                print("No data returned")
                return
            }
        
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                photo.image = UIImage(data: data)
                photo.imageLoaded = true
                
                CoreDataStackManager.sharedInstance().saveContext()
                
                // Maybe the pin was removed.
                guard let pin = photo.pin else {
                    print("The photo is not associated with a pin yet")
                    return
                }
                
                // Check if all of the pin's photos have been loaded.
                let photos = pin.photos
                
                // 1. find an index with the property image loaded false
                let photosWithNoImages = photos.filter({ !$0.imageLoaded })
                
                // 2. If the image are no photos with no images, execute the completion handler
                if photosWithNoImages.count == 0 {
                    
                    // There may be a completion handler (or not)
                    // Thats because we're also using this method while loading the cells
                    completionHandler?()
                    
                    // Create the dictionary send to the Update initializer
                    let dictionary: [String: AnyObject] = [
                        Update.Keys.Description: "Image(s) Created",
                        Update.Keys.Latitude: pin.latitude,
                        Update.Keys.Longitude: pin.longitude,
                        Update.Keys.NumberOfItems: photos.count,
                        Update.Keys.UpdateType: "Image Creation"
                    ]
                    
                    // Create an update
                    let _ = Update(dictionary: dictionary, context: CoreDataStackManager.sharedInstance().managedObjectContext)
                    CoreDataStackManager.sharedInstance().saveContext()
                }
            })
        })
        
        task.resume()
    }
    
    // MARK: - Helper method
    
    func createPhotoURL(photo: Photo, withSize size: String) -> NSURL {
        let urlString = "https://farm\(photo.farm).staticflickr.com/\(photo.server)/\(photo.id)_\(photo.secret)_\(size).jpg"
        // print(urlString)
        
        let url = NSURL(string: urlString)!
        
        return url
    }
}
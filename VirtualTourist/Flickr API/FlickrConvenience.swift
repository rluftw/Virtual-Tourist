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
    
    func retrieveImages(_ pin: Pin, dictionary: [String: Any], completionHandler: (()->Void)?) {
        let searchParameters: [String: Any] = [
            ParameterKeys.APIKey: ParameterValues.APIKey,
            ParameterKeys.Format: ParameterValues.Format,
            ParameterKeys.NoJSONCallBack: ParameterValues.NoJSONCallBack,
            ParameterKeys.Method: Methods.PhotoSearchMethod,
            ParameterKeys.Privacy: ParameterValues.Privacy,
            ParameterKeys.Accuracy: ParameterValues.Accuracy,
            ParameterKeys.PerPage: ParameterValues.PerPage,
            ParameterKeys.Page: dictionary[ParameterKeys.Page] as! NSNumber,
            ParameterKeys.Latitude: dictionary[Pin.Keys.Latitude] as! Double,
            ParameterKeys.Longitude: dictionary[Pin.Keys.Longitude] as! Double
        ]
        
        // 1. Search method to make the photo objects
        let task = httpGetRequest(searchParameters) { (result, error) -> Void in
            // make sure there are no errors
            guard error == nil else {
                print("Retrieving the Image - Photo")
                return
            }
            
            // convert the result into a dictionary
            guard let result = result as? [String: AnyObject] else {
                print("Invalid results - photo")
                return
            }
            
            // retrieve the photo dictionary and array
            guard let photoDictionary = result["photos"] as? [String: AnyObject], let photoArray = photoDictionary["photo"] as? [[String: AnyObject]] else {
                print("Invalid positioning - Photo")
                return
            }
            
            DispatchQueue.main.async(execute: { () -> Void in
                pin.originalPhotoCount = photoArray.count
                
                // Check if the photo count is more than 0
                guard photoArray.count > 0 else {
                    
                    // Can't leave the UI hanging
                    completionHandler?()
                    return
                }

                // Use the photoArray and point it to the pin
                for photo in photoArray {
                    let newPhoto = Photo(dictionary: photo, context: CoreDataStackManager.sharedInstance().managedObjectContext)
                    
                    // Assign the photo to its pin
                    newPhoto.pin = pin
                    
                    // This allows the empty boxes to appear before the photos are loaded
                    CoreDataStackManager.sharedInstance().saveContext()
                    
                    // 2. Create the photo URL and grab the image (prefetch)
                    _ = self.loadImagesWithSize(newPhoto, size: ImageSizesForURL.LargeSquare, completionHandler: completionHandler, photoDataHandler: nil)
                }
            })
        }
        pin.task = task
    }
    
    func loadImagesWithSize(_ photo: Photo, size: String, completionHandler: (()->Void)?, photoDataHandler: ((Data)->Void)?) -> URLSessionTask {
        let url = self.createPhotoURL(photo, withSize: size)
        let request = URLRequest(url: url)
        let task = self.session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            guard error == nil else {
                print("\(error!.localizedDescription)")
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, 200...299 ~= statusCode else {
                print("Invalid Status code retrieving photo data")
                return
            }
            
            guard let data = data else {
                print("No data returned")
                return
            }
            
            
            DispatchQueue.main.async(execute: { () -> Void in
                // check if the size requested was small
                if size == Flickr.ImageSizesForURL.LargeSquare {
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
                        let dictionary: [String: Any] = [
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
                } else {
                    guard let photoDataHandler = photoDataHandler else {
                        return
                    }
                    
                    photoDataHandler(data)
                }
            })
        })
        
        task.resume()
        
        return task
    }
    
    // MARK: - Helper method
    
    func createPhotoURL(_ photo: Photo, withSize size: String) -> URL {
        let urlString = "https://farm\(photo.farm).staticflickr.com/\(photo.server)/\(photo.id)_\(photo.secret)_\(size).jpg"
        print(urlString)
        
        let url = URL(string: urlString)!
        
        return url
    }
}

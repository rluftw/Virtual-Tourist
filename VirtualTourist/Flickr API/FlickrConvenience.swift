//
//  FlickrNetworkRequest.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 2/26/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import Foundation

extension FlickrNetworkRequest {
    
    // Convenience method - Retrieve all photo information
    
    func retrieveImages(pin: Pin, dictionary: [String: AnyObject]) {
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
        
        // 1. Search method to retrieve photo IDs
        httpGetRequest(searchParameters) { (result, error) -> Void in
            // make sure there are no errors
            guard error == nil else {
                print("(Long, Lat): (\(pin.longitude), \(pin.latitude)) - Retrieving the Image Life")
                return
            }
            
            // convert the result into a dictionary
            guard let result = result as? [String: AnyObject] else {
                print("(Long, Lat): (\(pin.longitude), \(pin.latitude)) - Invalid results - Photo")
                return
            }
            
            // retrieve the photo dictionary and array
            guard let photoDictionary = result["photos"] as? [String: AnyObject], let photoArray = photoDictionary["photo"] as? [[String: AnyObject]] else {
                print("(Long, Lat): (\(pin.longitude), \(pin.latitude)) - Invalid positioning - Photo")
                return
            }
            
            // Use the photoArray and point it to the pin
            for photo in photoArray {
                
                // Needs to be on the main thread since we're using the default managedObjectContext
                // Created on the main thread
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    let newPhoto = Photo(dictionary: photo, context: CoreDataStackManager.sharedInstance().managedObjectContext)
                    newPhoto.pin = pin
                    
                    CoreDataStackManager.sharedInstance().saveContext()
                    
                    // 2. Create the photo URL and grab the image
                    let url = self.createPhotoURLSize(newPhoto, withSize: ImageSizesForURL.LargeSquare)
                    let request = NSURLRequest(URL: url)
                    let task = self.session.dataTaskWithRequest(request, completionHandler: { (data, response, error) -> Void in
                        guard error == nil else {
                            print("Photo ID: \(newPhoto.id) - Error retrieving photo")
                            return
                        }
                        
                        guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where 200...299 ~= statusCode else {
                            print("Photo ID: \(newPhoto.id) - Invalid Status code retrieving photo data")
                            return
                        }
                        
                        guard let data = data else {
                            print("No data returned")
                            return
                        }
                        
                        // Image assignment and saving on the main thread
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            // Assign image path and save the path to core data
                            newPhoto.image = data
                            CoreDataStackManager.sharedInstance().saveContext()
                            
                            // TODO: Store the data in the documents directory
                            
                        })
                    })
                    
                    task.resume()
                })
            }
        }
    }
    
    // MARK: - Helper method
    
    func createPhotoURLSize(photo: Photo, withSize size: String) -> NSURL {
        let urlString = "https://farm\(photo.farm).staticflickr.com/\(photo.server)/\(photo.id)_\(photo.secret)_\(size).jpg"
        print(urlString)
        
        let url = NSURL(string: urlString)!
        
        return url
    }
}
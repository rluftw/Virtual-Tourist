//
//  Flickr.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 2/26/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import Foundation
import UIKit

class Flickr {
    let session = NSURLSession.sharedSession()
    
    class func sharedInstance() -> Flickr {
        struct Singleton {
            static let networkOperation = Flickr()
        }
        return Singleton.networkOperation
    }
    
    struct Caches {
        static let imageCache = ImageCache()
    }
    
    // MARK: - Canceling network task
    func cancelAllNetworkTask() {
        NSURLSession.sharedSession().getAllTasksWithCompletionHandler({ (tasks) -> Void in
            for task in tasks {
                task.cancel()
            }
        })
    }

    // MARK: - All purpose task method for data
    
    func httpGetRequest(parameters: [String: AnyObject]?, completionHandler: (result: AnyObject!, error: NSError?)->Void) -> NSURLSessionTask {
        let request = NSURLRequest(URL: getCompleteURL(parameters))
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
            // Check for errors
            guard error == nil else {
                // Use the completion handler to notify unsuccessful task
                self.createErrorWithCompletionHandler(error!.code, error: error!.localizedDescription, completionHandler: completionHandler)
                return
            }
            
            // Check the response
            let statusCode = (response as! NSHTTPURLResponse).statusCode

            // Excluded responses include: Write Fail (106), Unknown User (2), Parameterless Search (3), Permission (4)
            // Own Contact Search (17), Invalid API Key (100), No Valid Machine Tag (11, 12), XML-RPC (115), Too many tags (1)
            // SOAP (114), Formats (111, 112)
            
            switch statusCode {
            case 10: self.createErrorWithCompletionHandler(10, error: "Search is currently not available", completionHandler: completionHandler)
            case 18: self.createErrorWithCompletionHandler(18, error: "Illogical arguments", completionHandler: completionHandler)
            case 105: self.createErrorWithCompletionHandler(105, error: "Service currently unavailable", completionHandler: completionHandler)

            // TODO: Remove - Staying here for testing
            case 116: self.createErrorWithCompletionHandler(116, error: "Bad URL found", completionHandler: completionHandler)
            default: break
            }

            // Check if the response is an answer between 200...299, otherwise return
            guard 200...299 ~= statusCode else {
               return
            }
            
            // Check if there's data
            guard let data = data else {
                 self.createErrorWithCompletionHandler(999, error: "No data retrieved", completionHandler: completionHandler)
                return
            }
            
            // Everything's a success Handle the data
            self.parseJSONWithCompletionHandler(data, completionHandler: completionHandler)
        }
        
        // Start the task
        task.resume()
        
        return task
    }
}


extension Flickr {
    
    // MARK: - Helper methods
    
    // Create a URL based on the parameters given to the method
    
    private func getCompleteURL(parameters: [String: AnyObject]?) -> NSURL {
        let components = NSURLComponents()
        
        // Protocol
        components.scheme = Constants.Scheme
        components.host = Constants.Domain
        components.path = Constants.Path

        guard let parameters = parameters else {
            return components.URL!
        }
        
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in parameters {
            let value = "\(value)"
            let query = NSURLQueryItem(name: key, value: value)
            components.queryItems?.append(query)
        }
        
        return components.URL!
    }
    
    // Serializes the data to JSON and completes the task
    
    func parseJSONWithCompletionHandler(data: NSData, completionHandler: (AnyObject!, NSError?)->Void) {
        var parseError: NSError?
        
        let parsedResults: AnyObject?
        do {
            parsedResults = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
        } catch let error as NSError {
            parseError = error
            parsedResults = nil
        }
        
        guard let error = parseError else {
            // Results were good.
            completionHandler(parsedResults, nil)
            return
        }
        
        completionHandler(nil, error)
    }
    
    // Helper method to create an error for httpGetRequest
    
    func createErrorWithCompletionHandler(code: Int, error: String, completionHandler: (AnyObject!, NSError?)->Void) -> NSError {
        var userInfo = [String: AnyObject]()
        userInfo[NSLocalizedDescriptionKey] = error
        
        return NSError(domain:"httpGetRequest", code: code, userInfo: userInfo)
    }
}
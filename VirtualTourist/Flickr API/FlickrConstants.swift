//
//  FlickrConstants.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 2/26/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import Foundation

extension Flickr {
    
    // API Methods
    struct Methods {
        static let PhotoSearchMethod = "flickr.photos.search"
        static let GetPhotoInfo = "flickr.photos.getInfo"
        static let GetPhotoSizes = "flickr.photos.getSizes"
    }
    
    // API Constants
    struct Constants {
        static let Scheme = "https"
        static let Domain = "api.flickr.com"
        static let Path = "/services/rest/"
    }
    
    // Parameter keys
    struct ParameterKeys {
        static let Longitude = "lon"
        static let Latitude = "lat"
        static let APIKey = "api_key"
        static let NoJSONCallBack = "nojsoncallback"
        static let Format = "format"
        static let Method = "method"
        static let Privacy = "privacy_filter"
        static let Accuracy = "accuracy"
        static let PerPage = "per_page"
        static let Page = "page"
        static let ID = "photo_id"
        
        static let Context = "geo_context"
        
        // Used for image fetching (Size)
        static let Label = "label"
    }
    
    
    // Parameter values
    struct ParameterValues {
        static let APIKey = "API KEY HERE"
        static let NoJSONCallBack = "1"
        static let Format = "json"
        static let Accuracy = "16"  // Street
        static let PerPage = "21"
        
        // Indoors (1) / Outdoors (2)
        static let Context = "2"
        
        /*
            1 public photos
            2 private photos visible to friends
            3 private photos visible to family
            4 private photos visible to friends & family
            5 completely private photos
        */
        static let Privacy = "1"
    }
    
    // Image Size Constants
    struct ImageSizeLabelValues {
                                                    // Width * Height
        static let Square = "Square"                // (75 * 75)
        static let LargeSquare = "Large Square"     // (150 * 150)
        static let Thumbnail = "Thumbnail"          // (100 * 79)
        static let Small = "Small"                  // (240 * 190)
        static let Small320 = "Small 320"           // (320 * 254)
        static let Medium = "Medium"                // (500 * 396)
        static let Medium640 = "Medium 640"         // (640 * 508)
        static let Medium800 = "Medium 800"         // (800 * 634)
        static let Large = "Large"                  // (1024 * 812)
        static let Large1600 = "Large 1600"         // (1600 * 1268)
        static let Original = "Original"            // Varies
    }
    
    // Used for creating the Image URL
    // Sizes can be found at the below
    // https://www.flickr.com/services/api/misc.urls.html
    struct ImageSizesForURL {
        static let Square = "s"
        static let LargeSquare = "q"
        static let Thumbnail = "t"
        static let Small = "m"
        static let Small320 = "n"
        static let Medium = "-"
        static let Medium640 = "z"
        static let Medium800 = "c"
        static let Large = "b"
        static let Large1600 = "h"
        static let Large2048 = "k"
        static let Original = "o"
    }
    
}

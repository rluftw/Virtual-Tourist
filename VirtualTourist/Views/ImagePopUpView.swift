//
//  imagePopUpView.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 3/9/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import UIKit

class ImagePopUpView: UIView {
    var photo: Photo!
    var task: NSURLSessionTask?
    
    convenience init(frame: CGRect, photo: Photo) {
        self.init(frame: frame)
        
        self.photo = photo
    }
    
    deinit {
        task?.cancel()
    }
    
    class func imagePopUpViewInView(view: UIView, animated: Bool, photo: Photo) -> ImagePopUpView {
        let imageView = ImagePopUpView(frame: view.bounds, photo: photo)
        imageView.backgroundColor = UIColor.clearColor()
        view.addSubview(imageView)
        
        return imageView
    }
    
    override func drawRect(rect: CGRect) {
        // Blur effect
        let blurEffect = UIBlurEffect(style: .Light)
        let blurVisualEffectView = UIVisualEffectView(effect: blurEffect)
        blurVisualEffectView.frame = rect
        addSubview(blurVisualEffectView)
        
        // Calculate the positioning and sizing of the box view
        let spaceOnTheSide: CGFloat = 10
        
        let boxDimension = rect.width-(spaceOnTheSide*2)
        let boxVerticalPosition = (rect.height/2) - (boxDimension/2)
        let boxHorizontalPosition = (rect.width/2) - (boxDimension/2)
        
        let boxViewFrame = CGRect(x: boxHorizontalPosition, y: boxVerticalPosition, width: boxDimension, height: boxDimension)
        
        // Create an innerview with the actual image
        let imageView = UIImageView(frame: boxViewFrame)
        imageView.backgroundColor = UIColor(red: 16.0/255, green: 58.0/255, blue: 143.0/255, alpha: 1.0)
        imageView.layer.cornerRadius = 5.0
        imageView.clipsToBounds = true
        imageView.contentMode = .ScaleAspectFill
        
        blurVisualEffectView.contentView.addSubview(imageView)
        
        
        // Calculate the positioning and sizing of the activity indicator
        let activityDimension: CGFloat = 50
        let activityVerticalPosition = (imageView.frame.height/2) - (activityDimension/2)
        let activityHorizontalPosition = (imageView.frame.width/2) - (activityDimension/2)

        let activityViewFrame = CGRect(x: activityHorizontalPosition, y: activityVerticalPosition, width: activityDimension, height: activityDimension)
        
        // Create the activity Indicator
        let activityView = UIActivityIndicatorView(frame: activityViewFrame)
        activityView.startAnimating()
        activityView.hidesWhenStopped = true
        
        // add the activity indicator onto the imageView
        imageView.addSubview(activityView)
        
        // Load the image
        task = Flickr.sharedInstance().loadImagesWithSize(photo, size: Flickr.ImageSizesForURL.Medium640, completionHandler: nil) { (imageData) -> Void in
            imageView.image = UIImage(data: imageData)
            activityView.stopAnimating()
        }
    }

}

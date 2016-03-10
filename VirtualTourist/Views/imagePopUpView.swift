//
//  imagePopUpView.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 3/9/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import UIKit

class imagePopUpView: UIView {
    var image: UIImage!
    
    convenience init(frame: CGRect, image: UIImage) {
        self.init(frame: frame)
        
        self.image = image
    }
    
    
    class func imagePopUpViewInView(view: UIView, animated: Bool, image: UIImage) -> imagePopUpView {
        let spaceOnTheSide: CGFloat = 10
        
        // Calculate the positioning and sizing of the view
        let dimension = view.frame.width-(spaceOnTheSide*2)
        let verticalPosition = (view.frame.height/2) - (dimension/2)
        let horizontalPosition = (view.frame.width/2) - (dimension/2)
        
        // Create the popImageView
        let popUpImageViewFrame = CGRect(x: horizontalPosition, y: verticalPosition, width: dimension, height: dimension)
        let popUpImageView = imagePopUpView(frame: popUpImageViewFrame, image: image)
        
        // Add the view onto the subview
        view.addSubview(popUpImageView)
        
        return popUpImageView
    }
    
}

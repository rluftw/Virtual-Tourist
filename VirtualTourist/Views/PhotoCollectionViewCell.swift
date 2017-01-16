//
//  PhotoCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Xing Hui Lu on 3/1/16.
//  Copyright © 2016 Xing Hui Lu. All rights reserved.
//

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
    // MARK: - IBOutlets
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var photoView: UIImageView!
    
    // MARK: - Helper methods
    
    func toggleUI() {
        activityIndicator.isAnimating ? activityIndicator.stopAnimating(): activityIndicator.startAnimating()
    }
}

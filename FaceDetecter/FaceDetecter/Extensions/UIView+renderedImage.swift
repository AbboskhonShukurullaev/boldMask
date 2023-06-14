//
//  UIView+renderedImage.swift
//  FaceDetecter
//
//  Created by Abboskhon on 14/06/23.
//

import UIKit

extension UIView {
    var renderedImage: UIImage {
        let renderer = UIGraphicsImageRenderer(size: self.bounds.size)
        return renderer.image { ctx in
            self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        }
    }
}

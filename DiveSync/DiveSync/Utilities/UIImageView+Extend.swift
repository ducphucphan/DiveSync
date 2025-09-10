//
//  UIImageView+Extend.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/8/24.
//

import UIKit

extension UIImage {
    
    
//    func scaleImage(toSize newSize: CGSize) -> UIImage? {
//        var newImage: UIImage?
//        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height).integral
//        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
//        if let context = UIGraphicsGetCurrentContext(), let cgImage = self.cgImage {
//            context.interpolationQuality = .high
//            let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: newSize.height)
//            context.concatenate(flipVertical)
//            context.draw(cgImage, in: newRect)
//            if let img = context.makeImage() {
//                newImage = UIImage(cgImage: img)
//            }
//            UIGraphicsEndImageContext()
//        }
//        return newImage
//    }
    
    func scaleImage(toSize newSize: CGSize) -> UIImage? {
            let renderer = UIGraphicsImageRenderer(size: newSize)
            
            return renderer.image { _ in
                self.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    
    func scaleAspectFit(toSize targetSize: CGSize) -> UIImage? {
            let widthRatio = targetSize.width / self.size.width
            let heightRatio = targetSize.height / self.size.height
            let scaleFactor = min(widthRatio, heightRatio)
            
            // Calculate the scaled image size that maintains the aspect ratio
            let scaledSize = CGSize(width: self.size.width * scaleFactor, height: self.size.height * scaleFactor)
            
            // Render the image with the calculated aspect fit size
            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            return renderer.image { _ in
                self.draw(in: CGRect(origin: .zero, size: scaledSize))
            }
        }
}

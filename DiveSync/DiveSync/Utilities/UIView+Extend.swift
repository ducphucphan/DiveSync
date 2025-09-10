//
//  Extend.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/7/24.
//

import UIKit

extension UIView {
    func applyShadow(color: UIColor = UIColor.black) {
        self.layer.shadowColor = color.cgColor
        self.layer.shadowOpacity = 0.3
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 2
        self.layer.cornerRadius = self.frame.height/2
    }
    
    func applyShadow(color: UIColor = UIColor.black, cornerRadius: CGFloat) {
        self.layer.shadowColor = color.cgColor
        self.layer.shadowOpacity = 0.3
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 2
        self.layer.cornerRadius = cornerRadius
    }
}

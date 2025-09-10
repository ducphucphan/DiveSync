//
//  CustomCalloutView.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/16/24.
//

import UIKit

class CustomCalloutView: UIView {
    
    // Hàm khởi tạo từ xib
    static func loadFromNib() -> CustomCalloutView {
        return UINib(nibName: "CustomCalloutView", bundle: nil).instantiate(withOwner: nil, options: nil).first as! CustomCalloutView
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 250, height: 145) // Kích thước mong muốn của callout
    }
    
}

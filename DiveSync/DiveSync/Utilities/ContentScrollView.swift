//
//  ContentScrollView.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/18/24.
//

import UIKit

class ContentScrollView: UIScrollView {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // alternatively, you can set an IBOutlet weak var contentView: UIView! instead of assuming one subview.
        if let contentView = self.subviews.first {
            self.contentSize = contentView.bounds.size
        }
    }
}

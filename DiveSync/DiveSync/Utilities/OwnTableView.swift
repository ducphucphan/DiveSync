//
//  OwnTableView.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/14/24.
//

import UIKit

class OwnTableView: UITableView {
    override var intrinsicContentSize: CGSize {
        self.layoutIfNeeded()
        return self.contentSize
    }
    
    override var contentSize: CGSize {
        didSet{
            self.invalidateIntrinsicContentSize()
        }
    }
}

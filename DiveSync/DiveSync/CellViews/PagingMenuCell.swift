//
//  PagingMenuCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/8/25.
//

import UIKit
import PagingKit

class PagingMenuCell: PagingMenuViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    
    
    override public var isSelected: Bool {
        didSet {
            if isSelected {
                titleLabel.textColor = UIColor(hex: "#001E62")
            } else {
                titleLabel.textColor = UIColor(hex: "#A1A1A1")
            }
        }
    }
    
}

//
//  DSNormalCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/14/25.
//

import UIKit

class DSNormalCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var arrowImv: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configure(title: String, value: String?) {
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.isHidden = (value == nil)
    }
    
    func setHideAccessory(hide: Bool) {
        arrowImv.isHidden = !hide
    }
}

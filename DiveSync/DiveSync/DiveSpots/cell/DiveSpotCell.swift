//
//  DiveSpotCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/3/25.
//

import UIKit

class DiveSpotCell: UITableViewCell {
    
    @IBOutlet weak var spotNameLb: UILabel!
    @IBOutlet weak var spotCountryLb: UILabel!
    @IBOutlet weak var checkbox: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        checkbox.setImage(UIImage(systemName: "circle"), for: .normal)
        checkbox.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        checkbox.isUserInteractionEnabled = false
        
        // Xóa background (nếu có)
        checkbox.backgroundColor = .clear
        
        // Xử lý update khi selected
        checkbox.configurationUpdateHandler = { button in
            var updatedConfig = button.configuration
            let isSelected = button.isSelected
            updatedConfig?.image = UIImage(systemName: isSelected ? "checkmark.circle" : "circle")
            updatedConfig?.baseBackgroundColor = .clear
            updatedConfig?.background.backgroundColor = .clear
            button.configuration = updatedConfig
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
}

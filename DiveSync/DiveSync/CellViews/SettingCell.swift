//
//  SettingCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/17/25.
//

import UIKit

class SettingCell: UITableViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var arrowImageView: UIImageView!
    @IBOutlet weak var titleLb: UILabel!
    @IBOutlet weak var valueLb: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func bindRow(row: SettingsRow) {
        titleLb.text = row.title
        valueLb.text = row.value
        
        if let value = row.value, row.id == "conservatism" {
            if value.toInt() == 0 {
                valueLb.text = value + " (GF: 90 - 90)"
            } else if value.toInt() == 1 {
                valueLb.text = value + " (GF: 85 - 35)"
            } else {
                valueLb.text = value + " (GF: 70 - 35)"
            }
        }
        
        if let icon = row.icon, !icon.isEmpty {
            iconImageView.image = UIImage(named: icon)
        } else {
            iconImageView.isHidden = true
        }
        
        if row.subRows?.count ?? 0 > 0 {
            arrowImageView.isHidden = false
        } else {
            arrowImageView.isHidden = true
        }
        
        if let disable = row.disable, disable == 1 {
            titleLb.textColor = UIColor.G_4
            valueLb.textColor = UIColor.G_4
        } else {
            titleLb.textColor = UIColor.black
            valueLb.textColor = UIColor.black
        }
    }
}

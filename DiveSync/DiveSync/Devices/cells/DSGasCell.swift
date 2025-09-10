//
//  DSDetailedCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/14/25.
//

import UIKit

class DSGasCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var modLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func bindRow(row: SettingsRow) {
        titleLabel.text = row.title
        typeLabel.text = row.value
        
        if let disable = row.disable, disable == 1 {
            titleLabel.textColor = UIColor.G_4
            typeLabel.textColor = UIColor.G_4
        } else {
            titleLabel.textColor = UIColor.black
            typeLabel.textColor = UIColor.black
        }
        
        var mod = row.gasMod ?? 0
        if DeviceSettings.shared.unit == M {
            mod = Int(converFeet2Meter(Double(mod)))
        }
        modLabel.text = String(format: "(MOD: %d%@)", mod, (DeviceSettings.shared.unit == M) ? "M":"FT")
    }
}

//
//  DSToggleCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/14/25.
//

import UIKit

class DSToggleCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var toggleSwitch: UISwitch!
    
    var onToggle: ((Bool) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        toggleSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
    }
    
    func configure(title: String, isOn: Bool, onToggle: ((Bool) -> Void)?) {
        titleLabel.text = title.localized
        toggleSwitch.isOn = isOn
        self.onToggle = onToggle
    }
    
    @objc private func switchChanged() {
        onToggle?(toggleSwitch.isOn)
        DeviceSettings.shared.useSystemDateTime = toggleSwitch.isOn
    }
 
    func bindRow(row: SettingsRow) {
        titleLabel.text = row.title.localized
        toggleSwitch.isOn = DeviceSettings.shared.useSystemDateTime
    }
}

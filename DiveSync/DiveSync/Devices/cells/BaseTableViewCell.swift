//
//  BaseTableViewCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 4/10/25.
//

import UIKit

class BaseTableViewCell: UITableViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func bindCell(title: String?, value: String?, imageName: String? = nil) {
        titleLabel.text = title
        valueLabel.text = value
        if let imageName = imageName, !imageName.isEmpty {
            iconImageView.image = UIImage(named: imageName)
        } else {
            iconImageView.isHidden = true
        }
    }
    
}

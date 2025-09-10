//
//  MenuCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/17/25.
//

import UIKit

class MenuCell: UITableViewCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLb: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    func bind(imageName: String, title: String) {
        iconImageView.image = UIImage(named: imageName)
        if iconImageView.image == nil {
            iconImageView.image = UIImage(systemName: imageName)
        }
        titleLb.text = title
        
        selectionStyle = .none
        backgroundColor = .clear
    }
}

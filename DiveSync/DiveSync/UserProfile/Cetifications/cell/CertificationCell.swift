//
//  CertificationCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/4/25.
//

import UIKit

class CertificationCell: UITableViewCell {

    @IBOutlet weak var checkbox: UIButton!
    @IBOutlet weak var certNoLb: UILabel!
    @IBOutlet weak var certNameLb: UILabel!
    @IBOutlet weak var dateLb: UILabel!
    @IBOutlet weak var imv: UIImageView!
    
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 10
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 3
        return v
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Thêm cardView bao ngoài contentView
        contentView.insertSubview(cardView, at: 0)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        
        // Ảnh
        imv.layer.cornerRadius = 8
        imv.clipsToBounds = true
        imv.contentMode = .scaleAspectFill
        imv.layer.borderWidth = 0.5
        imv.layer.borderColor = UIColor.clear.cgColor
        
        // Label style
        certNoLb.font = .boldSystemFont(ofSize: 16)
        certNoLb.textColor = .label
        
        certNameLb.font = .systemFont(ofSize: 14)
        certNameLb.textColor = .secondaryLabel
        
        dateLb.font = .systemFont(ofSize: 13)
        dateLb.textColor = .tertiaryLabel
        
        // Checkbox style
        checkbox.setImage(UIImage(systemName: "circle"), for: .normal)
        checkbox.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        checkbox.isUserInteractionEnabled = false
        checkbox.tintColor = .systemBlue
        checkbox.configurationUpdateHandler = { button in
            var updatedConfig = button.configuration
            let isSelected = button.isSelected
            updatedConfig?.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            updatedConfig?.baseBackgroundColor = .clear
            button.configuration = updatedConfig
        }
        
        backgroundColor = .clear
        selectionStyle = .none
    }
}

//
//  ShadowTableViewCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/10/24.
//

import UIKit

class ShadowTableViewCell: UITableViewCell {
    private let shadowView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupShadow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupShadow()
    }
    
    // Cấu hình shadow
    private func setupShadow() {
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.2
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 2)
        shadowView.layer.shadowRadius = 1
        shadowView.layer.cornerRadius = 10
        shadowView.backgroundColor = .white
        shadowView.layer.masksToBounds = false
        
        // Set shadowView as backgroundView
        backgroundView = shadowView
        
        // Disable default backgrounds
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update shadow frame and path
        shadowView.frame = contentView.bounds.insetBy(dx: 0, dy: 4) // Adjust padding for Inset Grouped style
        shadowView.layer.shadowPath = UIBezierPath(
            roundedRect: shadowView.bounds,
            cornerRadius: 10
        ).cgPath
    }
}


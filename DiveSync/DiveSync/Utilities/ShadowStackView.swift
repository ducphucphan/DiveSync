//
//  ShadowStackView.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/11/24.
//

import UIKit

class ShadowStackView: UIStackView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupShadow()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupShadow()
    }
    
    private func setupShadow() {
        self.layer.shadowColor = UIColor.darkGray.cgColor
        self.layer.shadowOpacity = 0.3
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.layer.shadowRadius = 2
        self.layer.cornerRadius = 15
        self.layer.masksToBounds = false // Add this line
    }
}


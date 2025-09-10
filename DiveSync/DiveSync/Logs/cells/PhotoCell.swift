//
//  PhotoCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/7/25.
//

import UIKit

class PhotoCell: UICollectionViewCell {
    @IBOutlet weak var mainImageView:UIImageView!
    @IBOutlet weak var checkImageView:UIImageView!
    
    var isChecked: Bool = false {
        didSet {
            updateCheckState()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        updateCheckState()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func updateCheckState() {
        checkImageView.isHidden = !isChecked
        mainImageView.layer.borderWidth = isChecked ? 2 : 0
    }
}

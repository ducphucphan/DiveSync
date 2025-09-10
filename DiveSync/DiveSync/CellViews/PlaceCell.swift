//
//  PlaceCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/16/24.
//

import UIKit

class PlaceCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var placeLb1: UILabel!
    @IBOutlet weak var placeLb2: UILabel!
    @IBOutlet weak var placeLb3: UILabel!
    
    var previousNumber: Int? = nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.layer.cornerRadius = 12
    }
    
    func loadData(at index: Int) {
        switch index {
        case 0:
            self.imageView.image = UIImage(named: "place_01")
            self.placeLb1.text = "El Amarradero"
            self.placeLb2.text = "Puerto Vallarta"
            self.placeLb3.text = "Paciﬁc Coast of Mexico"
            break
        case 1:
            self.imageView.image = UIImage(named: "place_02")
            self.placeLb1.text = "El Natural"
            self.placeLb2.text = "Puerto Rico"
            self.placeLb3.text = "Caribbean"
            break
        case 2:
            self.imageView.image = UIImage(named: "place_03")
            self.placeLb1.text = "TURQ"
            self.placeLb2.text = "St Croix"
            self.placeLb3.text = "U.S. Virgin"
            break
        default:
            break
        }
    }
}

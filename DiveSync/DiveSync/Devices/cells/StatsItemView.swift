//
//  StatsItemView.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/30/26.
//

import UIKit

class StatsItemView: UIView {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    
    static func loadFromNib() -> StatsItemView {
        return Bundle.main.loadNibNamed("StatsItemView", owner: nil, options: nil)?.first as! StatsItemView
    }

}

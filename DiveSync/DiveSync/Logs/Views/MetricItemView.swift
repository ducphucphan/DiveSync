//
//  MetricItemView.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/11/26.
//

import UIKit

class MetricItemView: UIView {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    static func loadFromNib() -> MetricItemView {
        return Bundle.main.loadNibNamed("MetricItemView", owner: nil, options: nil)?.first as! MetricItemView
    }
    
}

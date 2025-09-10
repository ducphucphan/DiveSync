//
//  DCDeviceView.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 11/28/24.
//

import UIKit

class DCDeviceView: UIView {
    
    @IBOutlet weak var deviceImageView: UIImageView!
    
    // Hàm khởi tạo từ xib
    static func loadFromNib() -> DCDeviceView {
        return UINib(nibName: "DCDevice", bundle: nil).instantiate(withOwner: nil, options: nil).first as! DCDeviceView
    }
    
    func fillData(mDevice: Devices) {
        deviceImageView.image = UIImage(named: "\(mDevice.modelId ?? 0)")
    }
}

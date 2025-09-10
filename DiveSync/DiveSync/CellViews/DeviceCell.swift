//
//  DeviceCell.swift
//  DiveSync
//
//  Created by Minhlv_MacOS14.7 on 27/11/24.
//

import UIKit

class DeviceCell: UITableViewCell {
    
    @IBOutlet weak var deviceImg: UIImageView!
    @IBOutlet weak var modelNameLb: UILabel!
    @IBOutlet weak var modelSerialLb: UILabel!
    @IBOutlet weak var lastSyncLb: UILabel!
    
    func fillData(mDevice: Devices) {
        deviceImg.image = UIImage(named: "\(mDevice.modelId ?? 0)")
        if deviceImg.image == nil {
            deviceImg.image = UIImage(named: "8682")
        }
        
        modelNameLb.text = mDevice.ModelName ?? ""
        modelSerialLb.text = "Serial: \(String(format: "%05d", (mDevice.SerialNo?.toInt() ?? 0))), v \(mDevice.Firmware ?? "")"
        lastSyncLb.text = "Last Connection \(mDevice.LastSync ?? "")"
    }
}

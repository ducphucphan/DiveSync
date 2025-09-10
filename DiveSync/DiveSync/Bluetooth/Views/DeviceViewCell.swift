//
//  DeviceViewCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 2/24/25.
//

import UIKit
import RxSwift
import RxCocoa
import RxBluetoothKit

class DeviceViewCell: UITableViewCell {
    
    @IBOutlet weak var deviceImg: UIImageView!
    @IBOutlet weak var modelNameLb: UILabel!
    @IBOutlet weak var modelSerialLb: UILabel!
    
    var disposeBag = DisposeBag()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }
    
    func fillData(mDevice: ScannedPeripheral) {
        
        guard let (bleName, serialNo) = mDevice.peripheral.peripheral.splitDeviceName() else { return }
        
        modelSerialLb.text = String(format: "Serial Number: %05d", serialNo.toInt())
        
        if let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            modelNameLb.text = dcInfo[1]
            deviceImg.image = UIImage(named: dcInfo[2])
        }
    }
    
}

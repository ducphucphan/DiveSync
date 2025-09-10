//
//  LogCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/5/25.
//

import UIKit
import GRDB

class LogCell: UITableViewCell {
    
    @IBOutlet weak var checkbox: UIButton!
    @IBOutlet weak var favoriteBtn: UIButton!
    
    @IBOutlet weak var locLb: UILabel!
    @IBOutlet weak var deviceNameLb: UILabel!
    @IBOutlet weak var diveInfoLb: UILabel!
    @IBOutlet weak var diveDateLb: UILabel!
    @IBOutlet weak var diveTimeLb: UILabel!
    
    var isFavorite = false
    
    var onFavoriteTapped: ((Bool) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        checkbox.setImage(UIImage(systemName: "circle"), for: .normal)
        checkbox.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        checkbox.isUserInteractionEnabled = false
        
        // Xóa background (nếu có)
        checkbox.backgroundColor = .clear
        checkbox.isHidden = true
        
        // Xử lý update khi selected
        checkbox.configurationUpdateHandler = { button in
            var updatedConfig = button.configuration
            let isSelected = button.isSelected
            updatedConfig?.image = UIImage(systemName: isSelected ? "checkmark.circle" : "circle")
            updatedConfig?.baseBackgroundColor = .clear
            updatedConfig?.background.backgroundColor = .clear
            button.configuration = updatedConfig
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    func bindData(row: Row) {
        locLb.text = row.stringValue(key: "SpotName")
        if row.stringValue(key: "SpotName").isEmpty {
            locLb.text = "---"
        }
                
        let deviceNameStr = row.stringValue(key: "DeviceName")
        let deviceSerialNo = row.stringValue(key: "SerialNo").toInt()
        
        let diveMode = row.stringValue(key: "DiveMode").toInt()
        if diveMode >= 100 { // Manual
            deviceNameLb.text = deviceNameStr.isEmpty ? "---":deviceNameStr
        } else {
            deviceNameLb.text = String(format: "%@, SN: %05d", deviceNameStr, deviceSerialNo)
        }
        
        let diveDateTime = row.stringValue(key: "DiveStartLocalTime")
        
        let diveDate = Utilities.convertDateFormat(from: diveDateTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: "dd.MM.yy")
        let diveTime = Utilities.convertDateFormat(from: diveDateTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: "hh:mm a")
        let diveOfTheDay = row.stringValue(key: "DiveOfTheDay")
        
        diveDateLb.text = diveDate
        diveTimeLb.text = String(format: "#%@ %@", diveOfTheDay, diveTime)
        
        let unitOfDive = row.stringValue(key: "Units").toInt()
        let unitString = unitOfDive == M ? "M":"FT"
        let tempUnitString = unitOfDive == M ? "°C":"°F"
        
        var diveInfo:[String] = []
        let mix1Fo2Percent = row.stringValue(key: "Mix1Fo2Percent").toInt()
        if mix1Fo2Percent > 21 {
            if mix1Fo2Percent == 100 {
                diveInfo.append("O2")
            } else {
                let ean = mix1Fo2Percent
                diveInfo.append(String(format: "EAN%d", ean))
            }
        } else {
            diveInfo.append("AIR")
        }
        
        var mdepth = row.stringValue(key: "MaxDepthFT")
        if unitOfDive == M {
            mdepth = String(format: "%.1f", converFeet2Meter(mdepth.toDouble()))
        } else {
            mdepth = String(format: "%.0f", mdepth.toDouble())
        }
        diveInfo.append(String(format: "%@ %@", mdepth, unitString))
        
        let dTime = row.stringValue(key: "TotalDiveTime").toInt()
        diveInfo.append(String(format: "%02d min", dTime / 60))
        
        var temp = row.stringValue(key: "MaxTemperatureF")
        if unitOfDive == M {
            temp = String(format: "%.1f", convertF2C(temp.toDouble()))
        } else {
            temp = String(format: "%.0f", temp.toDouble())
        }
        diveInfo.append(String(format: "%@ %@", temp, tempUnitString))
        
        diveInfoLb.text = diveInfo.joined(separator: ", ")
        
        // Check Favorite.
        isFavorite = (row.intValue(key: "IsFavorite") != 0)
        favoriteBtn.setImage(UIImage(named: isFavorite ? "favorite" : "un_favorite"), for: .normal)
    }

    @IBAction func favoriteTapped(_ sender: Any) {
        isFavorite.toggle()
        
        favoriteBtn.setImage(UIImage(named: isFavorite ? "favorite" : "un_favorite"), for: .normal)
        
        self.onFavoriteTapped?(isFavorite)
    }
}

//
//  LogCell.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/5/25.
//

import UIKit
import GRDB

class LogCell: UITableViewCell {
    
    @IBOutlet weak var checkboxImv: UIImageView!
    @IBOutlet weak var favoriteBtn: UIButton!
    
    @IBOutlet weak var locLb: UILabel!
    @IBOutlet weak var deviceNameLb: UILabel!
    @IBOutlet weak var diveInfoLb: UILabel!
    @IBOutlet weak var diveDateLb: UILabel!
    @IBOutlet weak var diveTimeLb: UILabel!
    @IBOutlet weak var diveOfTheDayLb: UILabel!
    
    var isFavorite = false
    
    var onFavoriteTapped: ((Bool) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Xóa background (nếu có)
        checkboxImv.backgroundColor = .clear
        checkboxImv.isHidden = true
        checkboxImv.image = UIImage(named: isSelected ? "checked" : "unchecked1")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    func updateCheckbox(isVisible: Bool, isChecked: Bool) {
        checkboxImv.isHidden = !isVisible

        UIView.transition(
            with: checkboxImv,
            duration: 0.15,
            options: .transitionCrossDissolve,
            animations: {
                self.checkboxImv.image = UIImage(
                    named: isChecked ? "checked" : "uncheck1"
                )
            }
        )
    }
    
    func bindData(row: Row) {
        let dFormat = AppSettings.shared.get(forKey: AppSettings.Keys.dateFormatIdentify) ?? 0
        let tFormat = AppSettings.shared.get(forKey: AppSettings.Keys.timeFormatIdentify) ?? 0
        
        let modelID = row.stringValue(key: "ModelID").toInt()
        
        locLb.text = row.stringValue(key: "SpotName")
        if row.stringValue(key: "SpotName").isEmpty {
            locLb.text = "---"
        }
        
        let deviceNameStr = row.stringValue(key: "DeviceName")
        var deviceSerialNo = ""
        switch modelID {
        case C_LOG, C_LOGPLUS, C_GRA, C_CEN:
            deviceSerialNo = row.stringValue(key: "SerialNo")
        default:
            deviceSerialNo = String(format: "%05d", row.stringValue(key: "SerialNo").toInt())
            break
        }
        
        let diveMode = row.stringValue(key: "DiveMode").toInt()
        if diveMode >= 100 { // Manual
            deviceNameLb.text = deviceNameStr.isEmpty ? "N/A":deviceNameStr
        } else {
            deviceNameLb.text = String(format: "%@, %@: %@", deviceNameStr, "SN".localized, deviceSerialNo)
        }
        
        let diveDateTime = row.stringValue(key: "DiveStartLocalTime")
        
        // Định dạng Ngày: 0 -> dd.MM.yy, 1 -> MM.dd.yy
        let datePattern = (dFormat == 0) ? "dd.MM.yy" : "MM.dd.yy"
        
        // Định dạng Giờ: 0 -> hh:mm a (12h), 1 -> HH:mm (24h)
        let timePattern = (tFormat == 0) ? "hh:mm a" : "HH:mm"
        
        let diveDate = Utilities.convertDateFormat(from: diveDateTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: datePattern)
        let diveTime = Utilities.convertDateFormat(from: diveDateTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: timePattern)
        let diveOfTheDay = row.stringValue(key: "DiveOfTheDay")
        
        diveDateLb.text = diveDate
        diveTimeLb.text = diveTime
        
        diveOfTheDayLb.text = "#\(diveOfTheDay)"
        if diveMode >= 100 || diveOfTheDay.isEmpty { // Manual
            diveOfTheDayLb.text = ""
        }
        
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
        /*
        var mdepth = row.stringValue(key: "MaxDepthFT")
        if unitOfDive == M {
            mdepth = String(format: "%.1f", converFeet2Meter(mdepth.toDouble()))
        } else {
            mdepth = String(format: "%.0f", mdepth.toDouble())
        }
        diveInfo.append(String(format: "%@ %@", mdepth, unitString))
        */
        diveInfo.append(getMaxDepth(row: row))
        
        let dTime = row.stringValue(key: "TotalDiveTime").toInt()
        diveInfo.append(String(format: "%02d min", dTime / 60))
        
        if modelID == C_LOGPLUS || modelID == C_LOG || modelID == C_GRA || modelID == C_CEN {
            diveInfo.append(getMinTemp(row: row))
        } else {
            var temp = row.stringValue(key: "MaxTemperatureF")
            if unitOfDive == M {
                temp = String(format: "%.1f", convertF2C(temp.toDouble()))
            } else {
                temp = String(format: "%.0f", temp.toDouble())
            }
            diveInfo.append(String(format: "%@ %@", temp, tempUnitString))
        }
        
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
    
    private func getMaxDepth(row: Row) -> String {
        let unitOfDive = row.stringValue(key: "Units").toInt()
        
        let unitString = unitOfDive == M ? "M":"FT"
        
        var mdepth = row.stringValue(key: "MaxDepthFT")
        
        if unitOfDive == M {
            mdepth = formatNumber(converFeet2Meter(mdepth.toDouble()))
        } else {
            mdepth = formatNumber(mdepth.toDouble(), decimalIfNeeded: 0)
        }
        return String(format: "%@ %@", mdepth, unitString)
    }
    
    private func getMinTemp(row: Row) -> String {
        let unitOfDive = row.stringValue(key: "Units").toInt()
        
        let tempUnitString = unitOfDive == M ? "°C":"°F"
        
        var minTemp = row.stringValue(key: "MinTemperatureF")
        if unitOfDive == M {
            minTemp = formatNumber(convertF2C(minTemp.toDouble()))
        } else {
            minTemp = formatNumber(minTemp.toDouble(), decimalIfNeeded: 0)
        }
        return String(format: "%@ %@", minTemp, tempUnitString)
    }
}

//
//  LogSettingsUsedViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/9/25.
//

import UIKit
import GRDB

class LogSettingsUsedViewController: BaseViewController {

    @IBOutlet weak var tableView: UITableView!
    
    let titleData = ["Units", "Light", "Sound", "Water", "Sample Rate", "Safety Stop", "Deep Stop", "Depth Alarm", "Dive Time Alarm", "No Deco Alarm", "Oxtox Alarm"]
    
    var profileValues = ["M - °C", "10 SEC", "ON", "SALT", "2 SEC", "3 M - 5 MIN", "OFF", "30 M", "OFF", "10 MIN", "OFF"]
    
    var diveLog: Row!
    
    var unitOfDive: Int = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Log - Settings Used".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
                
        // Register the default cell
        tableView.backgroundColor = .clear
        tableView.register(UINib(nibName: "BaseTableViewCell", bundle: nil), forCellReuseIdentifier: "BaseTableViewCell")
        
        unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
    }
    

}

extension LogSettingsUsedViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titleData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BaseTableViewCell", for: indexPath) as! BaseTableViewCell
        
        var value = "---"
        switch indexPath.row {
        case 0:
            value = unitOfDive == M ? "M - °C":"FT - °F"
        case 1:
            let light = diveLog.stringValue(key: "Light").toInt()
            value = String(format: "%d%%", light)
        case 2:
            let sound = diveLog.stringValue(key: "Sound").toInt()
            if sound == 0 {
                value = OFF
            } else {
                value = "ON"
            }
        case 3:
            let sound = diveLog.stringValue(key: "Water").toInt()
            if sound == 0 {
                value = "SALT"
            } else {
                value = "FRESH"
            }
        case 4:
            value = diveLog.stringValue(key: "SamplingTime") + " " + "SEC"
        case 5:
            let safetyStop = diveLog.stringValue(key: "SafetyStopMode").toInt()
            if safetyStop == 0 {
                value = OFF
            } else {
                let safetyStopMin = diveLog.stringValue(key: "SafetyStopTime").toInt()
                var safetyStopDepth = String(format:"%d M", diveLog.stringValue(key: "SafetyStopDepthMT").toInt())
                if unitOfDive == FT {
                    safetyStopDepth =  String(format:"%d FT", diveLog.stringValue(key: "SafetyStopDepthFT").toInt())
                }
                value = String(format: "%@ - %d MIN", safetyStopDepth, safetyStopMin)
            }
        case 6:
            let deepStop = diveLog.stringValue(key: "DeepStopMode").toInt()
            if deepStop == 0 {
                value = OFF
            } else {
                value = "ON"
            }
        case 7:
            var mdepth = 0
            if unitOfDive == M {
                mdepth = diveLog.stringValue(key: "DepthAlarmMT").toInt()
                value = (mdepth == 0) ? OFF : "\(mdepth) M"
            } else {
                mdepth = diveLog.stringValue(key: "DepthAlarmFT").toInt()
                value = (mdepth == 0) ? OFF : "\(mdepth) FT"
            }
        case 8:
            let diveTime = diveLog.stringValue(key: "DiveTimeAlarm").toInt()
            value = (diveTime == 0) ? OFF : String(format: "%d:%02d", diveTime / 60, diveTime % 60)
        case 9:
            let noDeco = diveLog.stringValue(key: "NoDecoTimeAlarm").toInt()
            value = String(format: "%d:%02d", noDeco / 60, noDeco % 60)
        case 10:
            let oxtox = diveLog.stringValue(key: "OxToxAlarmPercent").toInt()
            value = (oxtox == 0) ? OFF : String(format: "%d%%", oxtox)
        default:
            break
        }
        
        cell.bindCell(title: titleData[indexPath.row].localized, value: value)
        
        cell.accessoryType = .none
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        
        return cell
    }
}

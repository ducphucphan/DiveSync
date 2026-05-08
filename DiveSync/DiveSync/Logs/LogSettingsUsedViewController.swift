//
//  LogSettingsUsedViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/9/25.
//

import UIKit
import GRDB

enum LogSettingUsed {
    case units, light, sound, water, sampleRate, safetyStop, deepStop, depthAlarm, diveTimeAlarm, noDecoAlarm, oxtoxAlarm, backLight, h20Sensor
    // Bạn có thể dễ dàng thêm các case mới ở đây như .tankPressure, .nitrox...

    var title: String {
        switch self {
        case .units: return "Units"
        case .light: return "Light"
        case .sound: return "Sound"
        case .water: return "Water"
        case .sampleRate: return "Sample Rate"
        case .safetyStop: return "Safety Stop"
        case .deepStop: return "Deep Stop"
        case .depthAlarm: return "Depth Alarm"
        case .diveTimeAlarm: return "Dive Time Alarm"
        case .noDecoAlarm: return "No Deco Alarm"
        case .oxtoxAlarm: return "Oxtox Alarm"
        case .backLight: return "Backlight"
        case .h20Sensor: return "H20 Sensor"
        }
    }
}

class LogSettingsUsedViewController: BaseViewController {

    @IBOutlet weak var tableView: UITableView!
        
    var diveLog: Row!
    var unitOfDive: Int = 1
    var modelId = 0
    
    var activeSettings: [LogSettingUsed] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupData()
    }
    
    private func setupUI() {
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: "Log - Settings Used".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        tableView.backgroundColor = .clear
        tableView.register(UINib(nibName: "BaseTableViewCell", bundle: nil), forCellReuseIdentifier: "BaseTableViewCell")
    }
    
    private func setupData() {
        unitOfDive = diveLog.stringValue(key: "Units").toInt()
        
        // Ví dụ: Nếu là device đặc biệt, bạn có thể remove hoặc chèn thêm setting
        modelId = diveLog.stringValue(key: "ModelID").toInt()
        
        switch modelId {
        case C_LOG, C_LOGPLUS:
            activeSettings = [.units, .water, .sampleRate]
        case C_GRA:
            activeSettings = [.units, .water, .sampleRate]
        case C_WIS5:
            activeSettings = [.units, .backLight, .h20Sensor, .sampleRate, .deepStop, .depthAlarm, .noDecoAlarm]
        default:
            activeSettings = [.units, .light, .sound, .water, .sampleRate, .safetyStop, .deepStop, .depthAlarm, .diveTimeAlarm, .noDecoAlarm, .oxtoxAlarm]
        }
        
        tableView.reloadData()
    }
}

extension LogSettingsUsedViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return activeSettings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BaseTableViewCell", for: indexPath) as! BaseTableViewCell
        
        let setting = activeSettings[indexPath.row]
        let value = getValue(for: setting)
        
        // Xử lý đổi tên title đặc biệt cho Brightness nếu cần
        var displayTitle = setting.title.localized
        if setting == .light && modelId == C_DAV {
            displayTitle = "Brightness"
        }
        
        cell.bindCell(title: displayTitle.localized, value: value)
        
        cell.accessoryType = .none
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        
        return cell
    }
    
    private func getValue(for setting: LogSettingUsed) -> String {
            switch setting {
            case .units:
                return unitOfDive == M ? "M - °C" : "FT - °F"
                
            case .light:
                let modelID = diveLog.stringValue(key: "ModelID").toInt()
                if modelID == C_SKI || modelID == C_SPI {
                    let dim = diveLog.stringValue(key: "BacklightDimTime").toInt()
                    return dim == 0 ? OFF : String(format: "%02d SEC", dim)
                } else {
                    return String(format: "%d%%", diveLog.stringValue(key: "Light").toInt())
                }

            case .sound:
                return diveLog.stringValue(key: "Sound").toInt() == 0 ? OFF : "ON"

            case .water:
                let water = diveLog.stringValue(key: "Water").toInt()
                if modelId == C_GRA || modelId == C_LOG || modelId == C_LOGPLUS {
                    if water == 103 { // SALT
                        return "SALT"
                    } else { // FRESH
                        return "FRESH"
                    }
                } else {
                    return water == 0 ? "SALT" : "FRESH"
                }

            case .sampleRate:
                return "\(diveLog.stringValue(key: "SamplingTime")) SEC"

            case .safetyStop:
                if diveLog.stringValue(key: "SafetyStopMode").toInt() == 0 { return OFF }
                let min = diveLog.stringValue(key: "SafetyStopTime").toInt()
                let depth = unitOfDive == FT ?
                    "\(diveLog.stringValue(key: "SafetyStopDepthFT").toInt()) FT" :
                    "\(diveLog.stringValue(key: "SafetyStopDepthMT").toInt()) M"
                return "\(depth) - \(min) MIN"

            case .deepStop:
                return diveLog.stringValue(key: "DeepStopMode").toInt() == 0 ? OFF : "ON"

            case .depthAlarm:
                let depth = unitOfDive == M ? diveLog.stringValue(key: "DepthAlarmMT").toInt() : diveLog.stringValue(key: "DepthAlarmFT").toInt()
                let unitStr = unitOfDive == M ? "M" : "FT"
                return depth == 0 ? OFF : "\(depth) \(unitStr)"

            case .diveTimeAlarm:
                let time = diveLog.stringValue(key: "DiveTimeAlarm").toInt()
                return time == 0 ? OFF : String(format: "%d:%02d", time / 60, time % 60)

            case .noDecoAlarm:
                let noDeco = diveLog.stringValue(key: "NoDecoTimeAlarm").toInt()
                return String(format: "%d:%02d", noDeco / 60, noDeco % 60)

            case .oxtoxAlarm:
                let oxtox = diveLog.stringValue(key: "OxToxAlarmPercent").toInt()
                return oxtox == 0 ? OFF : "\(oxtox)%"
            case .backLight:
                let light = diveLog.stringValue(key: "BacklightDimTime").toInt()
                if light > 0 {
                    return "ON"
                } else {
                    return OFF
                }
                
            case .h20Sensor:
                let h20Sensor = diveLog.stringValue(key: "Water").toInt()
                return h20Sensor == 0 ? OFF : "ON"
            }
        }
}

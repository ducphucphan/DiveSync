//
//  DeviceSettingViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/17/25.
//

import UIKit
import RxSwift
import ProgressHUD
import RxBluetoothKit

class DeviceSettingViewController: BaseViewController {
    
    @IBOutlet weak var tableview: UITableView!
    @IBOutlet weak var downloadSettingsLb: UILabel!
    @IBOutlet weak var uploadSettingsLb: UILabel!
    
    @IBOutlet weak var deviceImageView: UIImageView!
    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var deviceSerial: UILabel!
    
    var device: Devices!
    
    private struct Item {
        let imageName: String
        let title: String
        var value: String
        let hasChild: Bool
    }
        
    private var settings:[SettingsRow] = []
    
    private var dbGasSettings: [String:String] = [:]
    
    private let dispose = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Device Settings".localized,
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        // Set delegate and data source
        tableview.delegate = self
        tableview.dataSource = self
        
        loadSettings()
        
    }
    
    private func loadSettings() {
        switch Int(device.modelId ?? 0) {
        case C_LOG, C_LOGPLUS:
            applyLogicDeciceValues()
        case C_GRA:
            applyCR5DeviceValues()
        case C_CEN:
            applyCR4DeviceValues()
        case C_WIS5:
            applyWisdom5Values()
        default: // DAV
            applyValues()
            break
        }
    }
    
    override func updateTexts() {
        super.updateTexts()
        
        downloadSettingsLb.text = "Download Settings".localized
        uploadSettingsLb.text = "Upload Settings".localized
    }
    
    func loadSettingsSections(from filename: String) -> [SettingsSection]? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            PrintLog("❌ File \(filename).json không tồn tại.")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let sections = try decoder.decode([SettingsSection].self, from: data)
            return sections
        } catch {
            PrintLog("❌ Lỗi parse file: \(error)")
            return nil
        }
    }
    
    private func loadCommonDeviceInfo() {
        let modelId = Int(device.modelId ?? 0)
        deviceImageView.image = UIImage(named: "\(modelId)") ?? UIImage(named: "8682")
        deviceName.text = device.ModelName
        
        switch modelId {
        case C_LOG, C_LOGPLUS, C_GRA, C_CEN:
            deviceSerial.text = "Serial".localized + ": \(device.SerialNo ?? "")"
        default:
            deviceSerial.text = String(format: "Serial".localized + ": %05d", device.SerialNo?.toInt() ?? 0)
        }
    }
    
    func applyValues() {
        if let sections = loadSettingsSections(from: "SE_device"), sections.count > 0 {
            //settings = sections[0].rows
            
            var excludedIDsForModel: [String] = []
            
            let modelId = Int(device.modelId ?? 0)
            switch modelId {
            case C_SKI, C_SPI:
                excludedIDsForModel = ["set_brightness", "set_autoDim"]
            default: // DAV
                excludedIDsForModel = ["set_backlight_duration"]
                break
            }
            
            loadCommonDeviceInfo()
            
            let rows = sections[0].rows
            let filtered = rows.filter { row in
                !excludedIDsForModel.contains(row.id ?? "")
            }
            settings = filtered
            
            var dbSettings: [String:String] = [:]
            do {
                let dcSettings = try DatabaseManager.shared.fetchData(from: "DeviceSettings", 
                                                                      where: "DeviceID=?",
                                                                      arguments: [device.deviceId])
                guard let row = dcSettings.first else { return }
                dbSettings = Utilities.convertRowToMap(row)
            } catch {
                PrintLog("Failed to fetch certificates data: \(error)")
            }
            
            do {
                let gasSettings = try DatabaseManager.shared.fetchData(from: "DeviceGasMixesSettings",
                                                                       where: "DeviceID=?",
                                                                       arguments: [device.deviceId])
                guard let row = gasSettings.first else { return }
                dbGasSettings = Utilities.convertRowToMap(row)
            } catch {
                PrintLog("Failed to fetch certificates data: \(error)")
            }
            
            if dbSettings.count <= 0 { return }
            
            // Gas 1 always ON
            //let gas1On = Utilities.intValue(at: 1, from: dbGasSettings["OC_Active"])
            let fo2Gas1 = Utilities.intValue(at: 1, from: dbGasSettings["OC_FO2"])
            let po2Gas1 = Utilities.intValue(at: 1, from: dbGasSettings["OC_MaxPo2"])
            let modGas1 = Utilities.intValue(at: 1, from: dbGasSettings["OC_ModFt"])
            
            let gas2On = Utilities.intValue(at: 2, from: dbGasSettings["OC_Active"])
            let fo2Gas2 = Utilities.intValue(at: 2, from: dbGasSettings["OC_FO2"])
            let po2Gas2 = Utilities.intValue(at: 2, from: dbGasSettings["OC_MaxPo2"])
            let modGas2 = Utilities.intValue(at: 2, from: dbGasSettings["OC_ModFt"])
            
            let gas3On = Utilities.intValue(at: 3, from: dbGasSettings["OC_Active"])
            let fo2Gas3 = Utilities.intValue(at: 3, from: dbGasSettings["OC_FO2"])
            let po2Gas3 = Utilities.intValue(at: 3, from: dbGasSettings["OC_MaxPo2"])
            let modGas3 = Utilities.intValue(at: 3, from: dbGasSettings["OC_ModFt"])
            
            let gas4On = Utilities.intValue(at: 4, from: dbGasSettings["OC_Active"])
            let fo2Gas4 = Utilities.intValue(at: 4, from: dbGasSettings["OC_FO2"])
            let po2Gas4 = Utilities.intValue(at: 4, from: dbGasSettings["OC_MaxPo2"])
            let modGas4 = Utilities.intValue(at: 4, from: dbGasSettings["OC_ModFt"])
            
            for i in 0..<settings.count {
                if let subRows = settings[i].subRows {
                    // Xử lý row ở đây
                    for row in subRows {
                        
                        let options = row.options
                        /*
                        let safetyStopDepthMOpts = row.safetyStopDepth_m
                        let safetyStopDepthFtOpts = row.safetyStopDepth_ft
                        let safetyStopTimeOpts = row.safetyStopTime
                        */
                        
                        switch row.id {
                        case "hour":
                            if let tf = dbSettings["TimeFormat"]?.toInt() {
                                row.value = options?[tf]
                            }
                        case "dates":
                            if let df = dbSettings["DateFormat"]?.toInt() {
                                row.value = options?[df]
                            }
                        case "set_date":
                            if let df = dbSettings["DateFormat"]?.toInt(), df == 1 { // M.D
                                row.value = Utilities.getDateTime(Date.now, "MM.dd.yyyy")
                            } else {
                                row.value = Utilities.getDateTime(Date.now, "dd.MM.yyyy")
                            }
                        case "set_time":
                            if let tf = dbSettings["TimeFormat"]?.toInt(), tf == 1 { // 12H
                                row.value = Utilities.getDateTime(Date.now, "hh:mm a")
                            } else {
                                row.value = Utilities.getDateTime(Date.now, "HH:mm")
                            }
                            
                        // Alarms
                        case "mdepth":
                            var mdepth = 0
                            if DeviceSettings.shared.unit == M {
                                mdepth = dbSettings["DepthAlarmM"]?.toInt() ?? 0
                                row.value = (mdepth == 0) ? OFF : "\(mdepth) M"
                            } else {
                                mdepth = dbSettings["DepthAlarmFt"]?.toInt() ?? 0
                                row.value = (mdepth == 0) ? OFF : "\(mdepth) FT"
                            }
                        case "dive_time":
                            let diveTime = dbSettings["DiveTimeAlarmMin"]?.toInt() ?? 0
                            row.value = (diveTime == 0) ? OFF : String(format: "%d:%02d", diveTime / 60, diveTime % 60)
                        case "no_deco":
                            let noDeco = dbSettings["NoDecoAlarmMin"]?.toInt() ?? 0
                            row.value = String(format: "%d:%02d", noDeco / 60, noDeco % 60)
                        case "oxtox":
                            let oxtox = dbSettings["OxToxAlarmPercent"]?.toInt() ?? 0
                            row.value = (oxtox == 0) ? OFF : String(format: "%d%%", oxtox)
                        //
                       
                        case "deep_stop":
                            if let deepStop = dbSettings["DeepStopOn"]?.toInt() {
                                row.value = options?[deepStop]
                            }
                        case "water":
                            if let water = dbSettings["WaterDensity"]?.toInt() {
                                row.value = options?[water]
                            }
                        case "conservatism":
                            if let GFLow = dbSettings["GFLow"]?.toInt(), let GFHigh = dbSettings["GFHigh"]?.toInt() {
                                var v = 0
                                if GFHigh >= 90 && GFLow >= 90 {
                                    v = 0
                                } else if GFHigh <= 70 && GFLow <= 35 {
                                    v = 2
                                } else {
                                    v = 1
                                }
                                
                                row.value = options?[v]
                            }
                            
                        case "safety_stop":
                            if let safetyStop = dbSettings["SafetyStopMode"]?.toInt() {
                                if safetyStop == 0 {
                                    row.value = OFF
                                } else {
                                    let safetyStopMin = dbSettings["SafetyStopMin"]?.toInt() ?? 0
                                    var safetyStopDepth = String(format:"%d M", dbSettings["SSDepthM"]?.toInt() ?? 0)
                                    if DeviceSettings.shared.unit == FT {
                                        safetyStopDepth =  String(format:"%d FT", dbSettings["SSDepthFt"]?.toInt() ?? 0)
                                    }
                                    row.value = String(format: "%@ - %d MIN", safetyStopDepth, safetyStopMin)
                                }
                            }
                        case "sample_rate":
                            if let sample = dbSettings["DiveLogSamplingTime"]?.toInt() {
                                row.value = String(format: "%d SEC", sample)
                            }
                            
                        // Gas
                        case "gas1":
                            if fo2Gas1 >= 21 {
                                row.value = options?[fo2Gas1 - 21]
                            }
                            row.gasMod = modGas1
                            
                        case "gas1_po2":
                            row.value = String(format: "%d.%02d", po2Gas1/100, po2Gas1 % 100)
                            
                        case "gas2":
                            if gas2On == 0 {
                                row.value = options?.last
                            } else {
                                row.value = options?[fo2Gas2 - 21]
                            }
                            row.gasMod = modGas2
                            
                        case "gas2_po2":
                            if gas2On == 0 {
                                row.disable = 1
                            }
                            row.value = String(format: "%d.%02d", po2Gas2/100, po2Gas2 % 100)
                            
                        case "gas3":
                            if gas2On == 0 {
                                row.disable = 1
                            }
                            
                            if gas3On == 0 {
                                row.value = options?.last
                            } else {
                                row.value = options?[fo2Gas3 - 21]
                            }
                            row.gasMod = modGas3
                            
                        case "gas3_po2":
                            if gas3On == 0 {
                                row.disable = 1
                            }
                            row.value = String(format: "%d.%02d", po2Gas3/100, po2Gas3 % 100)
                            
                        case "gas4":
                            if gas3On == 0 {
                                row.disable = 1
                            }
                            
                            if gas4On == 0 {
                                row.value = options?.last
                            } else {
                                row.value = options?[fo2Gas4 - 21]
                            }
                            row.gasMod = modGas4
                            
                        case "gas4_po2":
                            if gas4On == 0 {
                                row.disable = 1
                            }
                            row.value = String(format: "%d.%02d", po2Gas4/100, po2Gas4 % 100)
                            
                        // User Info
                        case "owner_name":
                            row.value = dbSettings["Name"]
                        /*
                        case "owner_surname":
                            row.value = dbSettings["SurName"]
                        */
                        case "owner_phone":
                            row.value = dbSettings["Phone"]
                        case "owner_mail":
                            row.value = dbSettings["Email"]
                        case "owner_blood_type":
                            row.value = dbSettings["Blood"]
                        case "owner_emname":
                            row.value = dbSettings["EmName"]
                        /*
                        case "owner_emsurname":
                            row.value = dbSettings["EmSurName"]
                         */
                        case "owner_emergency_contact_phone":
                            row.value = dbSettings["EmPhone"]
                        default:
                            break
                        }
                    }
                } else {
                    let row = settings[i]
                    let options = row.options
                    switch row.id {
                    case "units":
                        if let unit = dbSettings["Units"]?.toInt() {
                            row.value = options?[unit]
                            DeviceSettings.shared.unit = unit
                        }
                    case "set_brightness":
                        if let brightness = dbSettings["BacklightLevel"]?.toInt() {
                            row.value = String(format: "%d%%", brightness)
                        }
                    case "set_autoDim":
                        if let timeToDim = dbSettings["BacklightDimTime"]?.toInt(),
                           let backLightDimLev = dbSettings["BacklightDimLevel"]?.toInt() {
                            if timeToDim == 0 {
                                row.value = String(format: "%@ - %d%%", OFF, backLightDimLev)
                            } else {
                                let timeToDimFormated = String(format: "%d:%02d", timeToDim / 60, timeToDim % 60)
                                row.value = String(format: "%@ - %d%%", timeToDimFormated, backLightDimLev)
                            }
                        }
                    case "set_backlight_duration":
                        if let backlightDimTime = dbSettings["BacklightDimTime"]?.toInt() {
                            if backlightDimTime == 0 {
                                row.value = OFF
                            } else {
                                row.value = String(format: "%d SEC", backlightDimTime)
                            }
                        }
                    case "sound":
                        if let sound = dbSettings["BuzzerMode"]?.toInt() {
                            row.value = options?[sound]
                        }
                    default:
                        break
                    }
                }
            }
            
        }
    }
    
    func applyWisdom5Values() {
        if let sections = loadSettingsSections(from: "wisdom5_device"), sections.count > 0 {
            //settings = sections[0].rows
            
            var excludedIDsForModel: [String] = []
            switch Int(device.modelId ?? 0) {
            case C_SKI, C_SPI:
                excludedIDsForModel = ["set_brightness", "set_autoDim"]
            default: // DAV
                excludedIDsForModel = ["set_backlight_duration"]
                break
            }
            
            loadCommonDeviceInfo()
            
            let rows = sections[0].rows
            let filtered = rows.filter { row in
                !excludedIDsForModel.contains(row.id ?? "")
            }
            settings = filtered
            
            var dbSettings: [String:String] = [:]
            do {
                let dcSettings = try DatabaseManager.shared.fetchData(from: "DeviceSettings",
                                                                      where: "DeviceID=?",
                                                                      arguments: [device.deviceId])
                guard let row = dcSettings.first else { return }
                dbSettings = Utilities.convertRowToMap(row)
            } catch {
                PrintLog("Failed to fetch certificates data: \(error)")
            }
            
            do {
                let gasSettings = try DatabaseManager.shared.fetchData(from: "DeviceGasMixesSettings",
                                                                       where: "DeviceID=?",
                                                                       arguments: [device.deviceId])
                guard let row = gasSettings.first else { return }
                dbGasSettings = Utilities.convertRowToMap(row)
            } catch {
                PrintLog("Failed to fetch certificates data: \(error)")
            }
            
            if dbSettings.count <= 0 { return }
            
            // Gas 1 always ON
            //let gas1On = Utilities.intValue(at: 1, from: dbGasSettings["OC_Active"])
            let fo2Gas1 = Utilities.intValue(at: 1, from: dbGasSettings["OC_FO2"])
            let po2Gas1 = Utilities.intValue(at: 1, from: dbGasSettings["OC_MaxPo2"])
            
            for i in 0..<settings.count {
                if let subRows = settings[i].subRows {
                    // Xử lý row ở đây
                    for row in subRows {
                        
                        let options = row.options
                        /*
                        let safetyStopDepthMOpts = row.safetyStopDepth_m
                        let safetyStopDepthFtOpts = row.safetyStopDepth_ft
                        let safetyStopTimeOpts = row.safetyStopTime
                        */
                        
                        switch row.id {
                        case "hour":
                            if let tf = dbSettings["TimeFormat"]?.toInt() {
                                row.value = options?[tf]
                            }
                        case "dates":
                            if let df = dbSettings["DateFormat"]?.toInt() {
                                row.value = options?[df]
                            }
                        case "set_date":
                            row.value = Utilities.getDateTime(Date.now, "MM.dd.yyyy") // Trong device luôn là dạng MM.dd.yyy
                        case "set_time":
                            if let tf = dbSettings["TimeFormat"]?.toInt(), tf == 1 { // 12H
                                row.value = Utilities.getDateTime(Date.now, "hh:mm a")
                            } else {
                                row.value = Utilities.getDateTime(Date.now, "HH:mm")
                            }
                            
                        // Alarms
                        case "mdepth":
                            let DepthAlarmOn = dbSettings["DepthAlarmOn"]?.toInt() ?? 0
                            if DepthAlarmOn == 0 {
                                row.value = OFF
                            } else {
                                var mdepth = 0
                                if DeviceSettings.shared.unit == M {
                                    mdepth = dbSettings["DepthAlarmM"]?.toInt() ?? 0
                                    row.value = "\(mdepth) M"
                                } else {
                                    mdepth = dbSettings["DepthAlarmFt"]?.toInt() ?? 0
                                    row.value = "\(mdepth) FT"
                                }
                            }
                            
                        case "turn_pressure":
                            let TankTurnAlramOn = dbSettings["TankTurnAlramOn"]?.toInt() ?? 0
                            if TankTurnAlramOn == 0 {
                                row.value = OFF
                            } else {
                                var tankTurn = 0
                                if DeviceSettings.shared.unit == M {
                                    tankTurn = dbSettings["TankTurnAlramBar"]?.toInt() ?? 0
                                    row.value = "\(tankTurn) BAR"
                                } else {
                                    tankTurn = dbSettings["TankTurnAlramPsi"]?.toInt() ?? 0
                                    row.value = "\(tankTurn) PSI"
                                }
                            }
                        case "end_pressure":
                               let TankEndAlramOn = dbSettings["TankEndAlramOn"]?.toInt() ?? 0
                               if TankEndAlramOn == 0 {
                                   row.value = OFF
                               } else {
                                   var tankEnd = 0
                                   if DeviceSettings.shared.unit == M {
                                       tankEnd = dbSettings["TankEndAlramBar"]?.toInt() ?? 0
                                       row.value = "\(tankEnd) BAR"
                                   } else {
                                       tankEnd = dbSettings["TankEndAlramPsi"]?.toInt() ?? 0
                                       row.value = "\(tankEnd) PSI"
                                   }
                               }
                        case "deep_stop":
                            if let deepStop = dbSettings["DeepStopOn"]?.toInt() {
                                row.value = options?[deepStop]
                            }
                        case "set_light":
                            if let light = dbSettings["BacklightDimTime"]?.toInt(), light > 0 {
                                row.value = options?[1]
                            } else {
                                row.value = options?[0] // OFF
                            }
                        case "water":
                            if let water = dbSettings["WetContacts"]?.toInt() {
                                row.value = options?[water]
                            }
                        case "dive_mode":
                            /*
                            if let modeValue = dbSettings["DiveMode"]?.toInt() {
                                // Khai báo các row liên quan để xử lý hiển thị
                                let conservatismRow = subRows.first(where: { $0.id == "conservatism" })
                                let po2Row = subRows.first(where: { $0.id == "gas1_po2" })
                                let fo2Row = subRows.first(where: { $0.id == "gas1_fo2" })
                                
                                if modeValue == 3 { // GAUGE
                                    row.value = "GAUGE"
                                    conservatismRow?.hidden = 1
                                    po2Row?.hidden = 1
                                    fo2Row?.hidden = 1
                                } else { // SCUBA (Gồm AIR và NITROX)
                                    if fo2Gas1 <= 21 {
                                        row.value = "AIR"
                                        conservatismRow?.hidden = 0
                                        po2Row?.hidden = 0
                                        fo2Row?.hidden = 1 // AIR thì ẩn FO2
                                    } else {
                                        row.value = "NITROX"
                                        conservatismRow?.hidden = 0
                                        po2Row?.hidden = 0
                                        fo2Row?.hidden = 0 // NITROX thì hiện FO2
                                    }
                                }
                            }
                            */
                            break
                        case "conservatism":
                            if let GFLow = dbSettings["GFLow"]?.toInt(), let GFHigh = dbSettings["GFHigh"]?.toInt() {
                                var v = 0
                                if GFHigh >= 90 && GFLow >= 90 {
                                    v = 0
                                } else if GFHigh <= 70 && GFLow <= 35 {
                                    v = 2
                                } else {
                                    v = 1
                                }
                                
                                row.value = options?[v]
                            }
                        case "gas1_po2":
                            row.value = String(format: "%d.%02d", po2Gas1/100, po2Gas1 % 100)
                        case "gas1_fo2":
                            row.value = String(format: "%d%%", fo2Gas1)
                        case "sample_rate":
                            if let sample = dbSettings["DiveLogSamplingTime"]?.toInt() {
                                row.value = String(format: "%d SEC", sample)
                            }
                        case "set_all_alarm":
                            let asntRow = subRows.first(where: { $0.id == "set_asnt" })
                            let mdepthRow = subRows.first(where: { $0.id == "mdepth" })
                            let turnPressureRow = subRows.first(where: { $0.id == "turn_pressure" })
                            let endPressureRow = subRows.first(where: { $0.id == "end_pressure" })
                            let reserveTimeRow = subRows.first(where: { $0.id == "reserve_time" })
                            let setDecoRow = subRows.first(where: { $0.id == "set_deco" })
                            let setPo2Row = subRows.first(where: { $0.id == "set_po2" })
                            
                            var hidden = 0
                            if let tf = dbSettings["BuzzerMode"]?.toInt(), tf == 0 {
                                row.value = options?[0] // OFF
                                hidden = 1
                            } else {
                                row.value = options?[1] // ON
                            }
                            
                            asntRow?.hidden = hidden
                            mdepthRow?.hidden = hidden
                            turnPressureRow?.hidden = hidden
                            endPressureRow?.hidden = hidden
                            reserveTimeRow?.hidden = hidden
                            setDecoRow?.hidden = hidden
                            setPo2Row?.hidden = hidden
                        case "set_asnt":
                            if let asnt = dbSettings["AscentSpeedAlarmOn"]?.toInt() {
                                row.value = options?[asnt]
                            }
                        case "set_deco":
                            if let deco = dbSettings["DecoEntryAlarmOn"]?.toInt() {
                                row.value = options?[deco]
                            }
                        case "set_po2":
                            if let po2Alarm = dbSettings["ModAlarmOn"]?.toInt() {
                                row.value = options?[po2Alarm]
                            }
                        case "reserve_time":
                            if let TankReserveTimeAlramOn = dbSettings["TankReserveTimeAlramOn"]?.toInt(), TankReserveTimeAlramOn == 0 {
                                row.value = OFF
                            } else {
                                let TankReserveTimeAlramMin = dbSettings["TankReserveTimeAlramMin"]?.toInt()
                                row.value = String(format: "%d MIN", TankReserveTimeAlramMin ?? 0)
                            }
                        default:
                            break
                        }
                    }
                } else {
                    let row = settings[i]
                    let options = row.options
                    switch row.id {
                    case "units":
                        if let unit = dbSettings["Units"]?.toInt() {
                            row.value = options?[unit]
                            DeviceSettings.shared.unit = unit
                        }
                    default:
                        break
                    }
                }
            }
            
        }
    }
    
    func applyLogicDeciceValues() {
        if let sections = loadSettingsSections(from: "Logic_device"), sections.count > 0 {
            //settings = sections[0].rows
            
            loadCommonDeviceInfo()
            
            var excludedIDsForModel: [String] = []
            let rows = sections[0].rows
            let filtered = rows.filter { row in
                !excludedIDsForModel.contains(row.id ?? "")
            }
            settings = filtered
            
            var dbSettings: [String:String] = [:]
            do {
                let dcSettings = try DatabaseManager.shared.fetchData(from: "DeviceSettings",
                                                                      where: "DeviceID=?",
                                                                      arguments: [device.deviceId])
                guard let row = dcSettings.first else { return }
                dbSettings = Utilities.convertRowToMap(row)
            } catch {
                PrintLog("Failed to fetch certificates data: \(error)")
            }
            
            if dbSettings.count <= 0 { return }
            
            
            for i in 0..<settings.count {
                if let subRows = settings[i].subRows {
                    // Xử lý row ở đây
                    for row in subRows {
                        
                        let options = row.options
                        let options_ft = row.options_ft
                        
                        switch row.id {
                        case "hour":
                            if let tf = dbSettings["TimeFormat"]?.toInt() {
                                row.value = options?[tf]
                            }
                        case "set_date":
                            if let df = dbSettings["DateFormat"]?.toInt(), df == 0 { // M.D
                                row.value = Utilities.getDateTime(Date.now, "MM.dd.yyyy")
                            } else {
                                row.value = Utilities.getDateTime(Date.now, "dd.MM.yyyy")
                            }
                        case "set_time":
                            if let tf = dbSettings["TimeFormat"]?.toInt(), tf == 0 { // 12H
                                row.value = Utilities.getDateTime(Date.now, "hh:mm a")
                            } else {
                                row.value = Utilities.getDateTime(Date.now, "HH:mm")
                            }
                            
                        // Alarms
                        case "set_all_alarm":
                            let mdepthRow = subRows.first(where: { $0.id == "mdepth" })
                            let timeAlarmRow = subRows.first(where: { $0.id == "time_alarm" })
                            
                            var hidden = 0
                            if let tf = dbSettings["BuzzerMode"]?.toInt(), tf == 0 {
                                row.value = options?[0] // OFF
                                hidden = 1
                            } else {
                                row.value = options?[1] // ON
                            }
                            
                            mdepthRow?.hidden = hidden
                            timeAlarmRow?.hidden = hidden
                        case "mdepth":
                            let mdepth = dbSettings["DepthAlarmM"]?.toInt() ?? 0
                            let idx = Int((mdepth - 9) / 3) + 1
                            
                            if mdepth == 0 || idx == 0 {
                                row.value = OFF
                            } else {
                                if DeviceSettings.shared.unit == M {
                                    row.value = options?[idx]
                                } else {
                                    row.value = options_ft?[idx]
                                }
                            }
                        case "time_alarm":
                            let diveTime = dbSettings["DiveTimeAlarmMin"]?.toInt() ?? 0
                            row.value = (diveTime == 0) ? OFF : String(format: "%d:%02d", diveTime / 60, diveTime % 60)
                        //
                        case "conservatism":
                            if let conservatism = dbSettings["Conservatism"]?.toInt() {
                                row.value = options?[conservatism]
                            }
                        case "dive_mode":
                            if let diveMode = dbSettings["DiveMode"]?.toInt() {
                                row.value = options?[diveMode-1]
                            }
                        case "fo2":
                            if let fo2 = dbSettings["FO2"]?.toInt() {
                                row.value = options?[fo2-21]
                            }
                        case "po2":
                            if let rawPo2 = dbSettings["PO2"],
                               let doubleValue = Double(rawPo2) {
                                
                                // Chuyển "150" thành "1.50"
                                let formattedPo2 = String(format: "%.2f", doubleValue / 100.0)
                                
                                if let index = options?.firstIndex(of: formattedPo2) {
                                    row.value = options?[index]
                                }
                            }
                        case "log_start_depth":
                            let depth = dbSettings["LogStartDepth"]?.toInt() ?? 0
                            let idx = Int((depth - 10) / 5)
                            
                            if DeviceSettings.shared.unit == M {
                                row.value = options?[idx]
                            } else {
                                row.value = options_ft?[idx]
                            }
                        case "log_stop_time":
                            if let logStopTime = dbSettings["LogStopTime"], let index = options?.firstIndex(where: {
                                   $0.replacingOccurrences(of: " MIN", with: "") == logStopTime
                               }) {
                                row.value = options?[index]
                            }
                        case "sample_rate":
                            if let sample = dbSettings["DiveLogSamplingTime"]?.toInt() {
                                row.value = String(format: "%d SEC", sample)
                            }
                            
                        
                        default:
                            break
                        }
                    }
                } else {
                    let row = settings[i]
                    let options = row.options
                    switch row.id {
                    case "units":
                        if let unit = dbSettings["Units"]?.toInt() {
                            row.value = options?[unit]
                            DeviceSettings.shared.unit = unit
                        }
                        
                    case "deep_stop":
                        if let deepStop = dbSettings["DeepStopOn"]?.toInt() {
                            row.value = options?[deepStop]
                        }
                    case "water":
                        if let water = dbSettings["WaterDensity"]?.toInt() {
                            if water == 103 { // SEA
                                row.value = options?[0]
                            } else { // FRESH
                                row.value = options?[1]
                            }
                        }
                    default:
                        break
                    }
                }
            }
            
        }
    }
    
    func applyCR5DeviceValues() {
        if let sections = loadSettingsSections(from: "CR5_device"), sections.count > 0 {
            //settings = sections[0].rows
            
            loadCommonDeviceInfo()
            
            let excludedIDsForModel: [String] = []
            let rows = sections[0].rows
            let filtered = rows.filter { row in
                !excludedIDsForModel.contains(row.id ?? "")
            }
            settings = filtered
            
            var dbSettings: [String:String] = [:]
            do {
                let dcSettings = try DatabaseManager.shared.fetchData(from: "DeviceSettings",
                                                                      where: "DeviceID=?",
                                                                      arguments: [device.deviceId])
                guard let row = dcSettings.first else { return }
                dbSettings = Utilities.convertRowToMap(row)
            } catch {
                PrintLog("Failed to fetch certificates data: \(error)")
            }
            
            if dbSettings.count <= 0 { return }
            
            
            for i in 0..<settings.count {
                if let subRows = settings[i].subRows {
                    // Xử lý row ở đây
                    for row in subRows {
                        //print(row.id)
                        let options = row.options
                        let options_ft = row.options_ft
                        
                        switch row.id {
                        case "hour":
                            if let tf = dbSettings["TimeFormat"]?.toInt() {
                                row.value = options?[tf]
                            }
                        case "dates":
                            if let df = dbSettings["DateFormat"]?.toInt() {
                                row.value = options?[df]
                            }
                        case "set_date":
                            if let df = dbSettings["DateFormat"]?.toInt(), df == 0 { // M.D
                                row.value = Utilities.getDateTime(Date.now, "MM.dd.yyyy")
                            } else {
                                row.value = Utilities.getDateTime(Date.now, "dd.MM.yyyy")
                            }
                        case "dst":
                            if let dst = dbSettings["DST"]?.toInt(), dst == 0 {
                                row.value = options?[0] // OFF
                            } else {
                                row.value = options?[1] // ON
                            }
                        case "set_time":
                            if let tf = dbSettings["TimeFormat"]?.toInt(), tf == 0 { // 12H
                                row.value = Utilities.getDateTime(Date.now, "hh:mm a")
                            } else {
                                row.value = Utilities.getDateTime(Date.now, "HH:mm")
                            }
                        case "fo2":
                            if let fo2 = dbSettings["FO2"]?.toInt() {
                                row.value = options?[fo2-21]
                            }
                        case "po2":
                            if let po2Raw = dbSettings["PO2"], let po2Double = Double(po2Raw) {
                                let formattedPo2 = String(format: "%.1f", po2Double / 10.0)
                                if let index = options?.firstIndex(of: formattedPo2) {
                                    row.value = options?[index]
                                }
                            }
                        case "log_stop_time":
                            if let logStopTime = dbSettings["LogStopTime"]?.toInt() {
                                row.value = options?[logStopTime]
                            }
                        case "conservatism":
                            if let conservatism = dbSettings["Conservatism"]?.toInt() {
                                row.value = options?[conservatism]
                            }
                        case "sample_rate":
                            if let sample = dbSettings["DiveLogSamplingTime"]?.toInt() {
                                row.value = options?[sample]
                            }
                        case "mdepth":
                            // fill giá trị cho options.
                            row.options = [OFF] + (0...99).map { "\($0) M" }
                            row.options_ft = [OFF] + (0...325).map { "\($0) FT" }
                            
                            var mdepth = 0
                            if DeviceSettings.shared.unit == M {
                                mdepth = dbSettings["DepthAlarmM"]?.toInt() ?? -1
                                row.value = (mdepth == -1) ? OFF : "\(mdepth) M"
                            } else {
                                mdepth = dbSettings["DepthAlarmFt"]?.toInt() ?? -1
                                row.value = (mdepth == -1) ? OFF : "\(mdepth) FT"
                            }
                            
                        case "time_alarm":
                            row.options = [OFF] + (0...90).map { "\($0) MIN" }
                            
                            let diveTime = dbSettings["DiveTimeAlarmMin"]?.toInt() ?? -1
                            row.value = (diveTime == -1) ? OFF : String(format: "%d MIN", diveTime)
                            
                        case "free_depth_alarm1":
                            row.options = [OFF] + (0...99).map { "\($0) M" }
                            
                            if let freeDepth1Alarm = dbSettings["FREE_DEPTH_ALARM1"]?.toInt() {
                                row.value = (freeDepth1Alarm == -1) ? OFF : "\(freeDepth1Alarm) M"
                            }
                            
                        case "free_depth_alarm2":
                            row.options = [OFF] + (0...99).map { "\($0) M" }
                            
                            if let freeDepth2Alarm = dbSettings["FREE_DEPTH_ALARM2"]?.toInt() {
                                row.value = (freeDepth2Alarm == -1) ? OFF : "\(freeDepth2Alarm) M"
                            }
                            
                        case "free_depth_alarm3":
                            row.options = [OFF] + (0...99).map { "\($0) M" }
                            
                            if let freeDepth3Alarm = dbSettings["FREE_DEPTH_ALARM3"]?.toInt() {
                                row.value = (freeDepth3Alarm == -1) ? OFF : "\(freeDepth3Alarm) M"
                            }
                        
                        case "free_time_alarm1":
                            row.options = [OFF] + (0...1500).map { "\($0) SEC" }
                            
                            if let value = dbSettings["FREE_TIME_ALARM1"]?.toInt() {
                                row.value = (value == -1) ? OFF : "\(value) SEC"
                            }
                            
                        case "free_time_alarm2":
                            row.options = [OFF] + (0...1500).map { "\($0) SEC" }
                            
                            if let value = dbSettings["FREE_TIME_ALARM2"]?.toInt() {
                                row.value = (value == -1) ? OFF : "\(value) SEC"
                            }
                            
                        case "free_time_alarm3":
                            row.options = [OFF] + (0...1500).map { "\($0) SEC" }
                            
                            if let value = dbSettings["FREE_TIME_ALARM3"]?.toInt() {
                                row.value = (value == -1) ? OFF : "\(value) SEC"
                            }
                            
                        case "free_si_alarm1":
                            
                            if let value = dbSettings["FREE_SI_ALARM1"]?.toInt() {
                                row.value = (value == -1) ? OFF : "\(value) MIN"
                            }
                            
                        case "free_si_alarm2":
                            
                            if let value = dbSettings["FREE_SI_ALARM2"]?.toInt() {
                                row.value = (value == -1) ? OFF : "\(value) MIN"
                            }
                            
                        case "free_si_alarm3":
                            
                            if let value = dbSettings["FREE_SI_ALARM3"]?.toInt() {
                                row.value = (value == -1) ? OFF : "\(value) MIN"
                            }
                            
                        default:
                            break
                        }
                    }
                } else {
                    let row = settings[i]
                    let options = row.options
                    
                    let left_options = row.left_options
                    let right_options = row.right_options
                    
                    switch row.id {
                    case "units":
                        if let unit = dbSettings["Units"]?.toInt() {
                            row.value = options?[unit]
                            DeviceSettings.shared.unit = unit
                        }
                    case "set_lang":
                        if let lang = dbSettings["Language"]?.toInt() {
                            row.value = options?[lang]
                        }
                    case "set_buzzer":
                        if let tf = dbSettings["BuzzerMode"]?.toInt(), tf == 0 {
                            row.value = options?[0] // OFF
                        } else {
                            row.value = options?[1] // ON
                        }
                    case "set_vibration":
                        if let tf = dbSettings["Vibration"]?.toInt(), tf == 0 {
                            row.value = options?[0] // OFF
                        } else {
                            row.value = options?[1] // ON
                        }
                    case "set_gnss":
                        if let tf = dbSettings["GNSS"]?.toInt(), tf == 0 {
                            row.value = options?[0] // OFF
                        } else {
                            row.value = options?[1] // ON
                        }
                    case "set_backlight":
                        
                        if let backLightDuration = dbSettings["BacklightDimTime"]?.toInt(),
                           let backLightLev = dbSettings["BacklightDimLevel"]?.toInt() {
                            
                            let leftValue = backLightLev+1
                            let rightValue = right_options?[backLightDuration] ?? "5 SEC"
                            
                            row.value = String(format: "Level %d - %@", leftValue, rightValue)
                        }
                    case "set_divemode":
                        if let diveMode = dbSettings["DiveMode"]?.toInt(), let diveStartDepthIdx = dbSettings["LogStartDepth"]?.toInt(),
                           let leftValue = left_options?[diveMode]  {
                            
                            var rightValue = right_options?[diveStartDepthIdx]
                            if DeviceSettings.shared.unit == FT {
                                let rightValueInt = right_options?[diveStartDepthIdx].toDouble() ?? 0.0
                                let feet = floor(rightValueInt * CONST_M_TO_FT * 10) / 10
                                rightValue = String(format: "%.1f FT", feet)
                            }
                            
                            row.value = String(format: "%@ - %@", leftValue, rightValue ?? "1.0 M")
                            
                        }
                    case "set_water":
                        if let water = dbSettings["WaterDensity"]?.toInt() {
                            if water == 103 { // SALT
                                row.value = options?[0]
                            } else { // FRESH
                                row.value = options?[1]
                            }
                        }
                    case "set_twist":
                        if let tf = dbSettings["TWIST"]?.toInt(), tf == 0 {
                            row.value = options?[0] // OFF
                        } else {
                            row.value = options?[1] // ON
                        }
                    default:
                        break
                    }
                }
            }
            
        }
    }
    
    func applyCR4DeviceValues() {
        if let sections = loadSettingsSections(from: "CR4_device"), sections.count > 0 {
            //settings = sections[0].rows
            
            loadCommonDeviceInfo()
            
            let excludedIDsForModel: [String] = []
            let rows = sections[0].rows
            let filtered = rows.filter { row in
                !excludedIDsForModel.contains(row.id ?? "")
            }
            settings = filtered
            
            var dbSettings: [String:String] = [:]
            do {
                let dcSettings = try DatabaseManager.shared.fetchData(from: "DeviceSettings",
                                                                      where: "DeviceID=?",
                                                                      arguments: [device.deviceId])
                guard let row = dcSettings.first else { return }
                dbSettings = Utilities.convertRowToMap(row)
            } catch {
                PrintLog("Failed to fetch certificates data: \(error)")
            }
            
            if dbSettings.count <= 0 { return }
            
            
            for i in 0..<settings.count {
                if let subRows = settings[i].subRows {
                    // Xử lý row ở đây
                    for row in subRows {
                        //print(row.id)
                        let options = row.options
                        let options_ft = row.options_ft
                        
                        switch row.id {
                        case "hour":
                            if let tf = dbSettings["TimeFormat"]?.toInt() {
                                row.value = options?[tf]
                            }
                        case "dates":
                            if let df = dbSettings["DateFormat"]?.toInt() {
                                row.value = options?[df]
                            }
                        case "set_date":
                            if let df = dbSettings["DateFormat"]?.toInt(), df == 0 { // M.D
                                row.value = Utilities.getDateTime(Date.now, "MM.dd.yyyy")
                            } else {
                                row.value = Utilities.getDateTime(Date.now, "dd.MM.yyyy")
                            }
                        case "set_time":
                            if let tf = dbSettings["TimeFormat"]?.toInt(), tf == 0 { // 12H
                                row.value = Utilities.getDateTime(Date.now, "hh:mm a")
                            } else {
                                row.value = Utilities.getDateTime(Date.now, "HH:mm")
                            }
                        case "set_timezone":
                            if let tz = dbSettings["TimeZone"]?.toInt() {
                                row.value = options?[tz]
                            }
                        case "fo2":
                            if let fo2 = dbSettings["FO2"]?.toInt() {
                                row.value = options?[fo2-21]
                            }
                        case "po2":
                            if let po2Raw = dbSettings["PO2"]?.toInt() {
                                row.value = options?[po2Raw]
                            }
                        case "conservatism":
                            if let conservatism = dbSettings["Conservatism"]?.toInt() {
                                row.value = options?[conservatism]
                            }
                        case "sample_rate":
                            if let sample = dbSettings["DiveLogSamplingTime"]?.toInt() {
                                row.value = options?[sample]
                            }
                        case "log_stop_time":
                            if let logStopTime = dbSettings["LogStopTime"]?.toInt() {
                                row.value = options?[logStopTime]
                            }
                        case "depth_alarm_enable":
                            if let idx = dbSettings["DepthAlarmEnable"]?.toInt() {
                                row.value = options?[idx]
                            }
                        case "depth_alarm":
                            // fill giá trị cho options.
                            let metersRange = 0...99
                            
                            row.options = metersRange.map { "\($0) M" }
                            row.options_ft = metersRange.map { m in
                                let feet = Int(Double(m) * 3.28084)
                                return "\(feet) FT"
                            }
                            
                            let mdepth = dbSettings["DepthAlarmM"]?.toInt() ?? 0
                            if DeviceSettings.shared.unit == M {
                                row.value = "\(mdepth) M"
                            } else {
                                let feet = Int(Double(mdepth) * 3.28084)
                                row.value = "\(feet) FT"
                            }
                        case "time_alarm_enable":
                            if let idx = dbSettings["TimeAlarmEnable"]?.toInt() {
                                row.value = options?[idx]
                            }
                        case "time_alarm":
                            row.options = (0...90).map { "\($0) MIN" }
                            
                            let diveTime = dbSettings["DiveTimeAlarmMin"]?.toInt() ?? 0
                            row.value = String(format: "%d MIN", diveTime)
                            
                        case "free_depth_alarm_enable":
                            if let idx = dbSettings["FreeDiveDepthAlarmEnable"]?.toInt() {
                                row.value = options?[idx]
                            }
                        case "cr4_free_depth_alarm1":
                            let metersRange = 0...99
                            
                            row.options = metersRange.map { "\($0) M" }
                            row.options_ft = metersRange.map { m in
                                let feet = Int(Double(m) * 3.28084)
                                return "\(feet) FT"
                            }
                            
                            let fDepth1 = dbSettings["FREE_DEPTH_ALARM1"]?.toInt() ?? 0
                            if DeviceSettings.shared.unit == M {
                                row.value = "\(fDepth1) M"
                            } else {
                                let feet = Int(Double(fDepth1) * 3.28084)
                                row.value = "\(feet) FT"
                            }
                            
                        case "cr4_free_depth_alarm2":
                            let metersRange = 0...99
                            
                            row.options = metersRange.map { "\($0) M" }
                            row.options_ft = metersRange.map { m in
                                let feet = Int(Double(m) * 3.28084)
                                return "\(feet) FT"
                            }
                            
                            let fDepth2 = dbSettings["FREE_DEPTH_ALARM2"]?.toInt() ?? 0
                            if DeviceSettings.shared.unit == M {
                                row.value = "\(fDepth2) M"
                            } else {
                                let feet = Int(Double(fDepth2) * 3.28084)
                                row.value = "\(feet) FT"
                            }
                            
                        case "cr4_free_depth_alarm3":
                            let metersRange = 0...99
                            
                            row.options = metersRange.map { "\($0) M" }
                            row.options_ft = metersRange.map { m in
                                let feet = Int(Double(m) * 3.28084)
                                return "\(feet) FT"
                            }
                            
                            let fDepth3 = dbSettings["FREE_DEPTH_ALARM3"]?.toInt() ?? 0
                            if DeviceSettings.shared.unit == M {
                                row.value = "\(fDepth3) M"
                            } else {
                                let feet = Int(Double(fDepth3) * 3.28084)
                                row.value = "\(feet) FT"
                            }
                        
                        case "free_time_alarm_enable":
                            if let idx = dbSettings["FreeDiveTimeAlarmEnable"]?.toInt() {
                                row.value = options?[idx]
                            }
                        case "free_time_alarm1":
                            row.options = (0...360).map { "\($0) SEC" }
                            
                            if let value = dbSettings["FREE_TIME_ALARM1"]?.toInt() {
                                row.value = "\(value) SEC"
                            }
                            
                        case "free_time_alarm2":
                            row.options = (0...360).map { "\($0) SEC" }
                            
                            if let value = dbSettings["FREE_TIME_ALARM2"]?.toInt() {
                                row.value = "\(value) SEC"
                            }
                            
                        case "free_time_alarm3":
                            row.options = (0...360).map { "\($0) SEC" }
                            
                            if let value = dbSettings["FREE_TIME_ALARM3"]?.toInt() {
                                row.value = "\(value) SEC"
                            }
                            
                        case "free_si_alarm_enable":
                            if let idx = dbSettings["FreeDiveSurfaceTimeAlarmEnable"]?.toInt() {
                                row.value = options?[idx]
                            }
                        case "free_si_alarm1":
                            
                            row.options = (0...60).map { "\($0) MIN" }
                            
                            if let value = dbSettings["FREE_SI_ALARM1"]?.toInt() {
                                row.value = "\(value) MIN"
                            }
                            
                        case "free_si_alarm2":
                            row.options = (0...60).map { "\($0) MIN" }
                            
                            if let value = dbSettings["FREE_SI_ALARM2"]?.toInt() {
                                row.value = "\(value) MIN"
                            }
                            
                        case "free_si_alarm3":
                            
                            row.options = (0...60).map { "\($0) MIN" }
                            
                            if let value = dbSettings["FREE_SI_ALARM3"]?.toInt() {
                                row.value = "\(value) MIN"
                            }
                            
                        default:
                            break
                        }
                    }
                } else {
                    let row = settings[i]
                    let options = row.options
                    
                    let left_options = row.left_options
                    let right_options = row.right_options
                    
                    switch row.id {
                    case "units":
                        if let unit = dbSettings["Units"]?.toInt() {
                            row.value = options?[unit]
                            DeviceSettings.shared.unit = unit
                        }
                    case "set_lang":
                        if let lang = dbSettings["Language"]?.toInt() {
                            row.value = options?[lang]
                        }
                    case "set_buzzer":
                        if let tf = dbSettings["BuzzerMode"]?.toInt(), tf == 0 {
                            row.value = options?[0] // OFF
                        } else {
                            row.value = options?[1] // ON
                        }
                    case "set_vibration":
                        if let tf = dbSettings["Vibration"]?.toInt(), tf == 0 {
                            row.value = options?[0] // OFF
                        } else {
                            row.value = options?[1] // ON
                        }
                    case "set_power":
                        if let tf = dbSettings["PowerSaving"]?.toInt() {
                            row.value = options?[tf]
                        }
                    case "set_backlight":
                        
                        if let backLightLev = dbSettings["BacklightDimLevel"]?.toInt() {
                            row.value = options?[backLightLev]
                        }
                    case "set_divemode":
                        if let diveMode = dbSettings["DiveMode"]?.toInt(), let diveStartDepthIdx = dbSettings["ScubaAutoStartDepth"]?.toInt(),
                           let leftValue = left_options?[diveMode]  {
                            
                            var rightValue = right_options?[diveStartDepthIdx]
                            if DeviceSettings.shared.unit == FT {
                                let rightValueInt = right_options?[diveStartDepthIdx].toDouble() ?? 0.0
                                let feet = floor(rightValueInt * CONST_M_TO_FT * 10) / 10
                                rightValue = String(format: "%.1f FT", feet)
                            }
                            
                            row.value = String(format: "%@ - %@", leftValue, rightValue ?? "1.0 M")
                            
                        }
                    default:
                        break
                    }
                }
            }
            
        }
    }
    
    func getPDCSettings() -> [String: Any] {
        var dcSettings: [String: Any] = [:]
        
        dcSettings["DeviceID"] = device.deviceId
        dcSettings["SurName"] = ""
        dcSettings["EmSurName"] = ""
        
        for i in 0..<settings.count {
            if let subRows = settings[i].subRows {
                // Xử lý row ở đây
                for row in subRows {
                    var index = 0
                    let value = row.value ?? ""
                    
                    let options = row.options
                    if options != nil {
                        index = options!.firstIndex(of: value) ?? 0
                    }
                    
                    switch row.id {
                    // System Settings
                    case "hour":
                        dcSettings["TimeFormat"] = index
                    case "dates":
                        dcSettings["DateFormat"] = index
                    case "water":
                        dcSettings["WaterDensity"] = index
                    case "sample_rate":
                        dcSettings["DiveLogSamplingTime"] = value.toInt()
                        
                    // Scuba Settings
                    case "mdepth":
                        if DeviceSettings.shared.unit == M {
                            dcSettings["DepthAlarmM"] = value.toInt()
                        } else {
                            dcSettings["DepthAlarmFt"] = value.toInt()
                        }
                        
                    case "dive_time":
                        dcSettings["DiveTimeAlarmMin"] = Utilities.parseTimeToMins(from: value)
                    case "no_deco":
                        dcSettings["NoDecoAlarmMin"] = Utilities.parseTimeToMins(from: value)
                    case "oxtox":
                        dcSettings["OxToxAlarmPercent"] = value.toInt()
                    case "deep_stop":
                        dcSettings["DeepStopOn"] = index
                    case "conservatism":
                        var GFLow = 90, GFHigh = 90
                        switch index {
                        case 1:
                            GFHigh = 85
                            GFLow = 35
                        case 2:
                            GFHigh = 70
                            GFLow = 35
                        default:
                            break
                        }
                        dcSettings["GFHigh"] = GFHigh
                        dcSettings["GFLow"] = GFLow
                    case "safety_stop":
                        if value == OFF {
                            dcSettings["SafetyStopMode"] = 0
                        } else {
                            dcSettings["SafetyStopMode"] = 1
                            
                            let values = value.components(separatedBy: "-").map { String($0) }
                            let safetyStopMin = values[1].toInt()
                            let safetyStopDepth = values[0].toInt()
                            
                            dcSettings["SafetyStopMin"] = safetyStopMin
                            if DeviceSettings.shared.unit == M {
                                dcSettings["SSDepthM"] = safetyStopDepth
                            } else {
                                dcSettings["SSDepthFt"] = safetyStopDepth
                            }
                        }
                    
                    // Gas Info
                    case "gas1":
                        let fo2 = index + 21
                        dbGasSettings["OC_FO2"] = Utilities.updateValue(in: dbGasSettings["OC_FO2"] ?? "", at: 1, to: fo2)
                        
                    case "gas1_po2":
                        let po2 = index*10 + 100
                        dbGasSettings["OC_MaxPo2"] = Utilities.updateValue(in: dbGasSettings["OC_MaxPo2"] ?? "", at: 1, to: po2)
                        
                    case "gas2":
                        let fo2Gas2 = index + 21
                        if (fo2Gas2 > 100) {
                            dbGasSettings["OC_Active"] = Utilities.updateValue(in: dbGasSettings["OC_Active"] ?? "", at: 2, to: 0)
                        } else {
                            dbGasSettings["OC_Active"] = Utilities.updateValue(in: dbGasSettings["OC_Active"] ?? "", at: 2, to: 1)
                        }
                        dbGasSettings["OC_FO2"] = Utilities.updateValue(in: dbGasSettings["OC_FO2"] ?? "", at: 2, to: fo2Gas2 > 100 ? 21:fo2Gas2)
                        
                    case "gas2_po2":
                        let po2Gas2 = index*10 + 100
                        dbGasSettings["OC_MaxPo2"] = Utilities.updateValue(in: dbGasSettings["OC_MaxPo2"] ?? "", at: 2, to: po2Gas2)
                        
                    case "gas3":
                        let fo2Gas3 = index + 21
                        if (fo2Gas3 > 100) {
                            dbGasSettings["OC_Active"] = Utilities.updateValue(in: dbGasSettings["OC_Active"] ?? "", at: 3, to: 0)
                        } else {
                            dbGasSettings["OC_Active"] = Utilities.updateValue(in: dbGasSettings["OC_Active"] ?? "", at: 3, to: 1)
                        }
                        dbGasSettings["OC_FO2"] = Utilities.updateValue(in: dbGasSettings["OC_FO2"] ?? "", at: 3, to: fo2Gas3 > 100 ? 21:fo2Gas3)
                        
                    case "gas3_po2":
                        let po2Gas3 = index*10 + 100
                        dbGasSettings["OC_MaxPo2"] = Utilities.updateValue(in: dbGasSettings["OC_MaxPo2"] ?? "", at: 3, to: po2Gas3)
                        
                    case "gas4":
                        let fo2Gas4 = index + 21
                        if (fo2Gas4 > 100) {
                            dbGasSettings["OC_Active"] = Utilities.updateValue(in: dbGasSettings["OC_Active"] ?? "", at: 4, to: 0)
                        } else {
                            dbGasSettings["OC_Active"] = Utilities.updateValue(in: dbGasSettings["OC_Active"] ?? "", at: 4, to: 1)
                        }
                        dbGasSettings["OC_FO2"] = Utilities.updateValue(in: dbGasSettings["OC_FO2"] ?? "", at: 4, to: fo2Gas4 > 100 ? 21:fo2Gas4)
                        
                    case "gas4_po2":
                        let po2Gas4 = index*10 + 100
                        dbGasSettings["OC_MaxPo2"] = Utilities.updateValue(in: dbGasSettings["OC_MaxPo2"] ?? "", at: 4, to: po2Gas4)
                        
                        
                    // User Info
                    case "owner_name":
                         dcSettings["Name"] = value
                    /*
                    case "owner_surname":
                        dcSettings["SurName"] = value
                    */
                    case "owner_phone":
                        dcSettings["Phone"] = value
                    case "owner_mail":
                        dcSettings["Email"] = value
                    case "owner_blood_type":
                        dcSettings["Blood"] = value
                    case "owner_emname":
                        dcSettings["EmName"] = value
                    /*
                    case "owner_emsurname":
                        dcSettings["EmSurName"] = value
                    */
                    case "owner_emergency_contact_phone":
                        dcSettings["EmPhone"] = value
                    default:
                        break
                    }
                }
            } else {
                let row = settings[i]
                var index = 0
                let value = row.value ?? ""
                
                let options = row.options
                if options != nil {
                    index = options!.firstIndex(of: value) ?? 0
                }
                
                switch row.id {
                case "units":
                    dcSettings["Units"] = index
                case "set_brightness":
                    dcSettings["BacklightLevel"] = value.toInt()
                case "set_autoDim":
                    let values = value.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                    let timeToDim = values[0].toSeconds
                    let dimToBrightness = values[1].toInt()
                    
                    dcSettings["BacklightDimTime"] = timeToDim
                    dcSettings["BacklightDimLevel"] = dimToBrightness
                case "set_backlight_duration":
                    dcSettings["BacklightDimTime"] = value.toInt()
                case "sound":
                    dcSettings["BuzzerMode"] = index
                default:
                    break
                }
            }
        }
        
        var dcGasSettings: [String: Any] = [:]
        dcGasSettings["DeviceID"] = device.deviceId
        dcGasSettings["OC_Active"] = dbGasSettings["OC_Active"]
        dcGasSettings["OC_FO2"] = dbGasSettings["OC_FO2"]
        dcGasSettings["OC_MaxPo2"] = dbGasSettings["OC_MaxPo2"]
        
        dcSettings["GasMixes"] = dcGasSettings
        
        return dcSettings
    }
    
    func getWisdom5Settings() -> [String: Any] {
        var dcSettings: [String: Any] = [:]
        
        dcSettings["DeviceID"] = device.deviceId
        dcSettings["SurName"] = ""
        dcSettings["EmSurName"] = ""
        
        for i in 0..<settings.count {
            if let subRows = settings[i].subRows {
                // Xử lý row ở đây
                for row in subRows {
                    var index = 0
                    let value = row.value ?? ""
                    
                    let options = row.options
                    if options != nil {
                        index = options!.firstIndex(of: value) ?? 0
                    }
                    
                    switch row.id {
                    // System Settings
                    case "hour":
                        dcSettings["TimeFormat"] = index
                    case "set_light":
                        if index == 0 {
                            dcSettings["BacklightDimTime"] = 0
                        } else {
                            dcSettings["BacklightDimTime"] = 10
                        }
                    case "water":
                        dcSettings["WetContacts"] = index
                    case "sample_rate":
                        dcSettings["DiveLogSamplingTime"] = value.toInt()
                    case "set_all_alarm":
                        dcSettings["BuzzerMode"] = index
                    case "set_asnt":
                        dcSettings["AscentSpeedAlarmOn"] = index
                    case "set_deco":
                        dcSettings["DecoEntryAlarmOn"] = index
                    case "set_po2":
                        dcSettings["ModAlarmOn"] = index
                        
                    // Scuba Settings
                    case "mdepth":
                        let valueInt = value.toInt()
                        dcSettings["DepthAlarmOn"] = (valueInt == 0) ? 0 : 1
                        if valueInt > 0 {
                            if DeviceSettings.shared.unit == M {
                                dcSettings["DepthAlarmM"] = valueInt
                            } else {
                                dcSettings["DepthAlarmFt"] = valueInt
                            }
                        }
                    
                    case "turn_pressure":
                        let valueInt = value.toInt()
                        dcSettings["TankTurnAlramOn"] = (valueInt == 0) ? 0 : 1
                        if valueInt > 0 {
                            if DeviceSettings.shared.unit == M {
                                dcSettings["TankTurnAlramBar"] = valueInt
                            } else {
                                dcSettings["TankTurnAlramPsi"] = valueInt
                            }
                        }
                    
                    case "end_pressure":
                        let valueInt = value.toInt()
                        dcSettings["TankEndAlramOn"] = (valueInt == 0) ? 0 : 1
                        if valueInt > 0 {
                            if DeviceSettings.shared.unit == M {
                                dcSettings["TankEndAlramBar"] = valueInt
                            } else {
                                dcSettings["TankEndAlramPsi"] = valueInt
                            }
                        }
                    case "deep_stop":
                        dcSettings["DeepStopOn"] = index
                    case "conservatism":
                        var GFLow = 90, GFHigh = 90
                        switch index {
                        case 1:
                            GFHigh = 85
                            GFLow = 35
                        case 2:
                            GFHigh = 70
                            GFLow = 35
                        default:
                            break
                        }
                        dcSettings["GFHigh"] = GFHigh
                        dcSettings["GFLow"] = GFLow
                        
                    case "reserve_time":
                        dcSettings["TankReserveTimeAlramOn"] = (index == 0) ? 0 : 1
                        if index > 0 {
                            dcSettings["TankReserveTimeAlramMin"] = value.toInt()
                        }

                    // Gas Info
                    case "dive_mode":
                        /*
                        if index == 2 { // GAUGE
                            dcSettings["DiveMode"] = 3
                        } else {
                            // Cả AIR và NITROX đều lưu là 0 (SCUBA)
                            dcSettings["DiveMode"] = 0
                        }
                        */
                        break
                    case "gas1_fo2":
                        let fo2 = index + 21
                        dbGasSettings["OC_FO2"] = Utilities.updateValue(in: dbGasSettings["OC_FO2"] ?? "", at: 1, to: fo2)
                        
                    case "gas1_po2":
                        let po2 = Int(value.toDouble() * 100)
                        dbGasSettings["OC_MaxPo2"] = Utilities.updateValue(in: dbGasSettings["OC_MaxPo2"] ?? "", at: 1, to: po2)

                    default:
                        break
                    }
                }
            } else {
                let row = settings[i]
                var index = 0
                let value = row.value ?? ""
                
                let options = row.options
                if options != nil {
                    index = options!.firstIndex(of: value) ?? 0
                }
                
                switch row.id {
                case "units":
                    dcSettings["Units"] = index
                default:
                    break
                }
            }
        }
        
        var dcGasSettings: [String: Any] = [:]
        dcGasSettings["DeviceID"] = device.deviceId
        dcGasSettings["OC_Active"] = dbGasSettings["OC_Active"]
        dcGasSettings["OC_FO2"] = dbGasSettings["OC_FO2"]
        dcGasSettings["OC_MaxPo2"] = dbGasSettings["OC_MaxPo2"]
        
        dcSettings["GasMixes"] = dcGasSettings
        
        return dcSettings
    }
    
    func printAllSettings(rows: [SettingsRow], level: Int = 0) {
        // Tạo khoảng trắng thụt đầu dòng để dễ phân biệt cấp độ cha-con
        let indentation = String(repeating: "    ", count: level)
        
        for row in rows {
            // Lấy giá trị id và value, nếu nil thì in ra chuỗi "nil"
            let idString = row.id ?? "nil (Title: \(row.title ?? "No Title"))"
            
            // Xử lý hiển thị value (vì value có thể là String hoặc Object)
            var displayValue = "nil"
            if let val = row.value {
                displayValue = "\(val)"
            }
            
            // In ra thông tin của row hiện tại
            print("\(indentation)▶️ ID: \(idString) | Value: \(displayValue)")
            
            // KIỂM TRA ĐỆ QUY: Nếu có subRows, tiếp tục in tất cả bên trong
            if let children = row.subRows, !children.isEmpty {
                printAllSettings(rows: children, level: level + 1)
            }
        }
    }
    
    func getLogicSettings() -> [String: Any] {
        var dcSettings: [String: Any] = [:]
        
        dcSettings["DeviceID"] = device.deviceId
        
        //printAllSettings(rows: settings)
        
        for i in 0..<settings.count {
            if let subRows = settings[i].subRows {
                // Xử lý row ở đây
                for row in subRows {
                    var index = 0
                    let value = row.value ?? ""
                    
                    let options = row.options
                    if options != nil {
                        index = options!.firstIndex(of: value) ?? 0
                    }
                    
                    switch row.id {
                    // System Settings
                    case "hour":
                        dcSettings["TimeFormat"] = index
                        
                    // Scuba Settings
                    case "mdepth":
                        
                        let options = row.options
                        let options_ft = row.options_ft
                        
                        if DeviceSettings.shared.unit == M {
                            dcSettings["DepthAlarmM"] = value.toInt()
                        } else {
                            if let idx = options_ft?.firstIndex(of: value) {
                                dcSettings["DepthAlarmM"] = options?[idx].toInt()
                            }
                        }
                        
                    case "time_alarm":
                        dcSettings["DiveTimeAlarmMin"] = Utilities.parseTimeToMins(from: value)
                        
                    case "dive_mode":
                        dcSettings["DiveMode"] = index+1
                        
                    case "fo2":
                        dcSettings["FO2"] = value.toInt()
                    case "po2":
                        dcSettings["PO2"] = value.toCleanInt(multiplier: 100)
                        
                    case "conservatism":
                        dcSettings["Conservatism"] = index
                        
                    case "log_start_depth":
                        let options = row.options
                        let options_ft = row.options_ft
                        
                        if DeviceSettings.shared.unit == M {
                            dcSettings["LogStartDepth"] = value.toCleanInt(multiplier: 10)
                        } else {
                            if let idx = options_ft?.firstIndex(of: value), let mString = options?[idx] {
                                // Tìm giá trị mét tương ứng rồi nhân 10
                                dcSettings["LogStartDepth"] = mString.toCleanInt(multiplier: 10)
                            }
                        }
                        
                    case "log_stop_time":
                        dcSettings["LogStopTime"] = value.toInt()
                        
                    case "sample_rate":
                        dcSettings["DiveLogSamplingTime"] = value.toInt()
                    default:
                        break
                    }
                }
            } else {
                let row = settings[i]
                var index = 0
                let value = row.value ?? ""
                
                let options = row.options
                if options != nil {
                    index = options!.firstIndex(of: value) ?? 0
                }
                
                switch row.id {
                case "units":
                    dcSettings["Units"] = index
                    
                case "water":
                    dcSettings["WaterDensity"] = (index == 0) ? 103:100
                    
                case "deep_stop":
                    dcSettings["DeepStopOn"] = index
                default:
                    break
                }
            }
        }
        
        return dcSettings
    }
    
    func getCR5Settings() -> [String: Any] {
        var dcSettings: [String: Any] = [:]
        
        dcSettings["DeviceID"] = device.deviceId
        
        //printAllSettings(rows: settings)
        
        for i in 0..<settings.count {
            if let subRows = settings[i].subRows {
                // Xử lý row ở đây
                for row in subRows {
                    var index = 0
                    let value = row.value ?? ""
                    
                    let options = row.options
                    if options != nil {
                        index = options!.firstIndex(of: value) ?? 0
                    }
                    
                    switch row.id {
                    // System Settings
                    case "hour":
                        dcSettings["TimeFormat"] = index
                        
                    case "dates":
                        dcSettings["DateFormat"] = index
                        
                    case "dst":
                        dcSettings["DST"] = index
                        
                    case "fo2":
                        dcSettings["FO2"] = value.toInt()
                        
                    case "po2":
                        dcSettings["PO2"] = Int(value.toDouble() * 10)
                        
                    case "log_stop_time":
                        dcSettings["LogStopTime"] = index
                        
                    case "conservatism":
                        dcSettings["Conservatism"] = index
                        
                    case "sample_rate":
                        dcSettings["DiveLogSamplingTime"] = index
                        
                        
                    // Scuba Settings
                    case "mdepth":
                        
                        if value == OFF {
                            dcSettings["DepthAlarmM"] = -1
                            dcSettings["DepthAlarmFt"] = -1
                        } else {
                            if DeviceSettings.shared.unit == M {
                                dcSettings["DepthAlarmM"] = value.toInt()
                            } else {
                                dcSettings["DepthAlarmFt"] = value.toInt()
                            }
                        }
                        
                    case "time_alarm":
                        if value == OFF {
                            dcSettings["DiveTimeAlarmMin"] = -1
                        } else {
                            dcSettings["DiveTimeAlarmMin"] = value.toInt()
                        }
                        
                    case "free_depth_alarm1":
                        if value == OFF {
                            dcSettings["FREE_DEPTH_ALARM1"] = -1
                        } else {
                            dcSettings["FREE_DEPTH_ALARM1"] = value.toInt()
                        }
                        
                    case "free_depth_alarm2":
                        if value == OFF {
                            dcSettings["FREE_DEPTH_ALARM2"] = -1
                        } else {
                            dcSettings["FREE_DEPTH_ALARM2"] = value.toInt()
                        }
                    
                    case "free_depth_alarm3":
                        if value == OFF {
                            dcSettings["FREE_DEPTH_ALARM3"] = -1
                        } else {
                            dcSettings["FREE_DEPTH_ALARM3"] = value.toInt()
                        }
                        
                    case "free_time_alarm1":
                        if value == OFF {
                            dcSettings["FREE_TIME_ALARM1"] = -1
                        } else {
                            dcSettings["FREE_TIME_ALARM1"] = value.toInt()
                        }
                        
                    case "free_time_alarm2":
                        if value == OFF {
                            dcSettings["FREE_TIME_ALARM2"] = -1
                        } else {
                            dcSettings["FREE_TIME_ALARM2"] = value.toInt()
                        }
                    
                    case "free_time_alarm3":
                        if value == OFF {
                            dcSettings["FREE_TIME_ALARM3"] = -1
                        } else {
                            dcSettings["FREE_TIME_ALARM3"] = value.toInt()
                        }
                        
                    case "free_si_alarm1":
                        if value == OFF {
                            dcSettings["FREE_SI_ALARM1"] = -1
                        } else {
                            dcSettings["FREE_SI_ALARM1"] = value.toInt()
                        }
                        
                    case "free_si_alarm2":
                        if value == OFF {
                            dcSettings["FREE_SI_ALARM2"] = -1
                        } else {
                            dcSettings["FREE_SI_ALARM2"] = value.toInt()
                        }
                    
                    case "free_si_alarm3":
                        if value == OFF {
                            dcSettings["FREE_SI_ALARM3"] = -1
                        } else {
                            dcSettings["FREE_SI_ALARM3"] = value.toInt()
                        }
                        
                    default:
                        break
                    }
                }
            } else {
                let row = settings[i]
                var index = 0
                let value = row.value ?? ""
                
                let options = row.options
                if options != nil {
                    index = options!.firstIndex(of: value) ?? 0
                }
                
                let leftOptions = row.left_options
                let rightOptions = row.right_options
                
                switch row.id {
                case "units":
                    dcSettings["Units"] = index
                
                case "set_lang":
                    dcSettings["Language"] = index
                    
                case "set_buzzer":
                    dcSettings["BuzzerMode"] = index
                    
                case "set_vibration":
                    dcSettings["Vibration"] = index
                    
                case "set_gnss":
                    dcSettings["GNSS"] = index
                    
                case "set_backlight":
                    
                    let components = value.components(separatedBy: " - ")
                    if components.count == 2 {
                        let prefix = components[0] // "Level 1"
                        dcSettings["BacklightDimLevel"] = leftOptions?.firstIndex(of: prefix)
                        
                        let suffix = components[1] // "5 SEC"
                        dcSettings["BacklightDimTime"] = rightOptions?.firstIndex(of: suffix)
                    }
                    
                case "set_divemode":
                    //if let diveMode = dbSettings["DiveMode"]?.toInt(), let diveStartDepthIdx = dbSettings["LogStartDepth"]?.toInt(),
                       let components = value.components(separatedBy: " - ")
                       if components.count == 2 {
                           let prefix = components[0] // "Free"
                           dcSettings["DiveMode"] = leftOptions?.firstIndex(of: prefix)
                           
                           let suffix = components[1] // "1.0 M" or "3.2 FT"
                           if DeviceSettings.shared.unit == M {
                               dcSettings["LogStartDepth"] = rightOptions?.firstIndex(of: suffix)
                           } else {
                               let doubleValue = suffix.toDouble()
                               
                               let meters = (doubleValue * CONST_FT_TO_M * 10).rounded() / 10
                               let metersValue = String(format: "%.1f M", meters)
                               
                               dcSettings["LogStartDepth"] = rightOptions?.firstIndex(of: metersValue)
                           }
                       }
                        
                case "set_water":
                    dcSettings["WaterDensity"] = (index == 0) ? 103:100
                 
                case "set_twist":
                    dcSettings["TWIST"] = index
                    
                default:
                    break
                }
            }
        }
        
        return dcSettings
    }
    
    func getCR4Settings() -> [String: Any] {
        var dcSettings: [String: Any] = [:]
        
        dcSettings["DeviceID"] = device.deviceId
        
        //printAllSettings(rows: settings)
        
        for i in 0..<settings.count {
            if let subRows = settings[i].subRows {
                // Xử lý row ở đây
                for row in subRows {
                    var index = 0
                    var ftIndex = 0
                    let value = row.value ?? ""
                    
                    let options = row.options
                    if options != nil {
                        index = options!.firstIndex(of: value) ?? 0
                    }
                    
                    if let optionsFt = row.options_ft {
                        ftIndex = optionsFt.firstIndex(of: value) ?? 0
                    }
                    
                    switch row.id {
//                    // System Settings
//                    case "hour":
//                        dcSettings["TimeFormat"] = index
//                        
//                    case "dates":
//                        dcSettings["DateFormat"] = index
//                        
                    case "fo2":
                        dcSettings["FO2"] = value.toInt()
                        
                    case "po2":
                        dcSettings["PO2"] = index
                        
                    case "log_stop_time":
                        dcSettings["LogStopTime"] = index
                        
                    case "conservatism":
                        dcSettings["Conservatism"] = index
                        
                    case "sample_rate":
                        dcSettings["DiveLogSamplingTime"] = index
                        
                    case "depth_alarm_enable":
                        dcSettings["DepthAlarmEnable"] = index
                    case "depth_alarm":
                        //Kiểm tra options không nil và index nằm trong dải cho phép
                        if let options = options, options.indices.contains(ftIndex) {
                            let mValue = options[ftIndex].toInt()
                            dcSettings["DepthAlarmM"] = mValue
                        }
                    case "time_alarm_enable":
                        dcSettings["TimeAlarmEnable"] = index
                    case "time_alarm":
                        dcSettings["DiveTimeAlarmMin"] = value.toInt()
                        
                    case "free_depth_alarm_enable":
                        dcSettings["FreeDiveDepthAlarmEnable"] = index
                    case "cr4_free_depth_alarm1":
                        if let options = options, options.indices.contains(ftIndex) {
                            let mValue = options[ftIndex].toInt()
                            dcSettings["FREE_DEPTH_ALARM1"] = mValue
                        }
                    case "cr4_free_depth_alarm2":
                        if let options = options, options.indices.contains(ftIndex) {
                            let mValue = options[ftIndex].toInt()
                            dcSettings["FREE_DEPTH_ALARM2"] = mValue
                        }
                    case "cr4_free_depth_alarm3":
                        if let options = options, options.indices.contains(ftIndex) {
                            let mValue = options[ftIndex].toInt()
                            dcSettings["FREE_DEPTH_ALARM3"] = mValue
                        }
                        
                    case "free_time_alarm_enable":
                        dcSettings["FreeDiveTimeAlarmEnable"] = index
                    case "free_time_alarm1":
                        dcSettings["FREE_TIME_ALARM1"] = value.toInt()
                    case "free_time_alarm2":
                        dcSettings["FREE_TIME_ALARM2"] = value.toInt()
                    case "free_time_alarm3":
                        dcSettings["FREE_TIME_ALARM3"] = value.toInt()
                        
                    case "free_si_alarm_enable":
                        dcSettings["FreeDiveSurfaceTimeAlarmEnable"] = index
                    case "free_si_alarm1":
                        dcSettings["FREE_SI_ALARM1"] = value.toInt()
                    case "free_si_alarm2":
                        dcSettings["FREE_SI_ALARM2"] = value.toInt()
                    case "free_si_alarm3":
                        dcSettings["FREE_SI_ALARM3"] = value.toInt()
//                    case "free_depth_alarm1":
//                        if value == OFF {
//                            dcSettings["FREE_DEPTH_ALARM1"] = -1
//                        } else {
//                            dcSettings["FREE_DEPTH_ALARM1"] = value.toInt()
//                        }
//                        
//                    case "free_depth_alarm2":
//                        if value == OFF {
//                            dcSettings["FREE_DEPTH_ALARM2"] = -1
//                        } else {
//                            dcSettings["FREE_DEPTH_ALARM2"] = value.toInt()
//                        }
//                    
//                    case "free_depth_alarm3":
//                        if value == OFF {
//                            dcSettings["FREE_DEPTH_ALARM3"] = -1
//                        } else {
//                            dcSettings["FREE_DEPTH_ALARM3"] = value.toInt()
//                        }
//                        
//                    case "free_time_alarm1":
//                        if value == OFF {
//                            dcSettings["FREE_TIME_ALARM1"] = -1
//                        } else {
//                            dcSettings["FREE_TIME_ALARM1"] = value.toInt()
//                        }
//                        
//                    case "free_time_alarm2":
//                        if value == OFF {
//                            dcSettings["FREE_TIME_ALARM2"] = -1
//                        } else {
//                            dcSettings["FREE_TIME_ALARM2"] = value.toInt()
//                        }
//                    
//                    case "free_time_alarm3":
//                        if value == OFF {
//                            dcSettings["FREE_TIME_ALARM3"] = -1
//                        } else {
//                            dcSettings["FREE_TIME_ALARM3"] = value.toInt()
//                        }
//                        
//                    case "free_si_alarm1":
//                        if value == OFF {
//                            dcSettings["FREE_SI_ALARM1"] = -1
//                        } else {
//                            dcSettings["FREE_SI_ALARM1"] = value.toInt()
//                        }
//                        
//                    case "free_si_alarm2":
//                        if value == OFF {
//                            dcSettings["FREE_SI_ALARM2"] = -1
//                        } else {
//                            dcSettings["FREE_SI_ALARM2"] = value.toInt()
//                        }
//                    
//                    case "free_si_alarm3":
//                        if value == OFF {
//                            dcSettings["FREE_SI_ALARM3"] = -1
//                        } else {
//                            dcSettings["FREE_SI_ALARM3"] = value.toInt()
//                        }
//                        
                    default:
                        break
                    }
                }
            } else {
                let row = settings[i]
                var index = 0
                let value = row.value ?? ""
                
                let options = row.options
                if options != nil {
                    index = options!.firstIndex(of: value) ?? 0
                }
                
                let leftOptions = row.left_options
                let rightOptions = row.right_options
                
                switch row.id {
                case "units":
                    dcSettings["Units"] = index
                
                case "set_lang":
                    dcSettings["Language"] = index
                    
                case "set_buzzer":
                    dcSettings["BuzzerMode"] = index
                    
                case "set_vibration":
                    dcSettings["Vibration"] = index
                    
                case "set_power":
                    dcSettings["PowerSaving"] = index
                    
                case "set_backlight":
                    dcSettings["BacklightDimLevel"] = index
                    
                case "set_divemode":
                       let components = value.components(separatedBy: " - ")
                       if components.count == 2 {
                           let prefix = components[0] // "Free"
                           dcSettings["DiveMode"] = leftOptions?.firstIndex(of: prefix)
                           
                           let suffix = components[1] // "1.0 M" or "3.2 FT"
                           if DeviceSettings.shared.unit == M {
                               dcSettings["ScubaAutoStartDepth"] = rightOptions?.firstIndex(of: suffix)
                           } else {
                               let doubleValue = suffix.toDouble()
                               
                               let meters = (doubleValue * CONST_FT_TO_M * 10).rounded() / 10
                               let metersValue = String(format: "%.1f M", meters)
                               
                               dcSettings["ScubaAutoStartDepth"] = rightOptions?.firstIndex(of: metersValue)
                           }
                       }
                    
                default:
                    break
                }
            }
        }
        
        return dcSettings
    }
    
    @IBAction func downloadTapped(_ sender: Any) {
        searchType = .kSetting
        syncType = .kDownloadSetting
        
        /*
        let storyboard = UIStoryboard(name: "Device", bundle: nil)
        let bluetoothScanVC = storyboard.instantiateViewController(withIdentifier: "BluetoothScanViewController") as! BluetoothScanViewController
        bluetoothScanVC.selectedDevice = device
        self.navigationController?.pushViewController(bluetoothScanVC, animated: true)
        */
        
        readSettings()
    }
    
    @IBAction func uploadTapped(_ sender: Any) {
        searchType = .kSetting
        syncType = .kUploadSetting
        
        var settings:[String: Any] = [:]
        
        switch Int(device.modelId ?? 0) {
        case C_LOG, C_LOGPLUS:
            settings = getLogicSettings()
        case C_GRA:
            settings = getCR5Settings()
        case C_CEN:
            settings = getCR4Settings()
        case C_WIS5:
            settings = getWisdom5Settings()
        default: // DAV
            settings = getPDCSettings()
            break
        }
        
        let basePath = HomeDirectory().appendingFormat("%@", PDC_DATA)

        try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)

        // 2. Tạo đường dẫn đến file
        let path = (basePath as NSString).appendingPathComponent("settingToWrite.plist")

        // 3. Nếu file tồn tại, xóa nó
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                PrintLog("[GET_HEADER_DATA_PDC] \(error)")
            }
        }
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: settings, format: .xml, options: 0)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            PrintLog("Lỗi khi ghi file: \(error)")
        }
        
        readSettings()
    }
    
    private func readSettings() {
        BluetoothDeviceCoordinator.shared.delegate = self
        if let deviceConnected = BluetoothDeviceCoordinator.shared.activeDataManager {
            // Da ket noi thi doc ngay
            deviceConnected.readAllSettings()
        } else {
            // Chua ket noi thi thuc hien ket noi
            
            let peripherals = BluetoothDeviceCoordinator.shared.scannedDevices.value
            guard let matchedDevice = peripherals.first(where: { $0.advertisementData.localName == device.Identity }) else {
                PrintLog("Device not found in scannedDevices yet")
                
                showAlert(on: self, title: "Device not found!".localized, message: "Ensure that your Device is ON and Bluetooth is opened.".localized)
                
                return
            }
            
            BluetoothDeviceCoordinator.shared
                .connect(to: matchedDevice, discover: true)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] session in
                    guard self != nil else { return }
                    
                    let manager: BluetoothManagerProtocol
                    switch session {
                    case .normalSession(let m): manager = m
                    case .crSession(let m): manager = m
                    case .cr4Session(let m): manager = m
                    case .cr5Session(let m): manager = m
                    }
                    
                    if let (bleName, _) = matchedDevice.splitDeviceName(),
                       let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                        manager.ModelID = dcInfo[2].toInt()
                    }
                    manager.readAllSettings(completion: nil)
                    
                }, onError: { [weak self] error in
                    guard self != nil else { return }
                    
                    ProgressHUD.dismiss()
                    if case BluetoothError.peripheralDisconnected = error, BluetoothDeviceCoordinator.shared.isExpectedDisconnect {
                        PrintLog("ℹ️ Peripheral disconnected (expected)")
                        BluetoothDeviceCoordinator.shared.isExpectedDisconnect = false
                    } else {
                        PrintLog("❌ Connect error: \(error.localizedDescription)")
                        BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: error.localizedDescription)
                    }
                    
                }).disposed(by: dispose)
        }
    }
    
    func resetSettings(in rows: inout [SettingsRow], with defaults: [String: String]) {
        for i in 0..<rows.count {
            if let id = rows[i].id {
                // Nếu có trong danh sách reset cứng (như OFF)
                if let defaultValue = defaults[id] {
                    rows[i].value = defaultValue
                }
                // Nếu là key cần chuyển đổi đơn vị (ví dụ: set_divemode)
                else if id == "set_divemode" {
                    let currentValue = rows[i].value ?? ""
                    rows[i].value = convertValueUnit(currentValue: currentValue, toUnit: DeviceSettings.shared.unit)
                }
                else if id == "log_start_depth" {
                    if DeviceSettings.shared.unit == M {
                        rows[i].value = rows[i].options?.first ?? "1.0 M"
                    } else {
                        rows[i].value = rows[i].options_ft?.first ?? "3.2 FT"
                    }
                }
                else if id == "depth_alarm" {
                    if DeviceSettings.shared.unit == M {
                        rows[i].value = rows[i].options?.first ?? "0 M"
                    } else {
                        rows[i].value = rows[i].options_ft?.first ?? "0 FT"
                    }
                }
            }

            if var sub = rows[i].subRows {
                resetSettings(in: &sub, with: defaults)
                rows[i].subRows = sub
            }
        }
    }
    
    func getIndexPaths(for ids: [String], in rows: [SettingsRow]) -> [IndexPath] {
        var indexPaths: [IndexPath] = []
        
        for (index, row) in rows.enumerated() {
            if let rowId = row.id, ids.contains(rowId) {
                indexPaths.append(IndexPath(row: index, section: 0)) // Giả định section là 0
            }
        }
        return indexPaths
    }
    
    func convertValueUnit(currentValue: String, toUnit unit: Int) -> String {
        // CR5 SET DIVE MODE value
        // "value": "Gauge - 3.0 M",
        
        let components = currentValue.components(separatedBy: " - ")
        guard components.count == 2 else { return currentValue }
        
        let prefix = components[0] // "Gauge"
        let suffix = components[1] // "3.0 M" hoặc "9.8 FT"
        
        let valueParts = suffix.components(separatedBy: " ")
        guard let numericValue = Double(valueParts.first ?? "") else { return currentValue }
        
        if unit == 1 { // Chuyển sang Feet (Imperial)
            if suffix.contains("M") {
                let feet = floor(numericValue * CONST_M_TO_FT * 10) / 10
                return "\(prefix) - \(String(format: "%.1f FT", feet))"
            }
        } else { // Chuyển sang Mét (Metric)
            if suffix.contains("FT") {
                // Ngược lại: 1 FT = 0.3048 M. Làm tròn 1 chữ số.
                let meters = (numericValue * CONST_FT_TO_M * 10).rounded() / 10
                return "\(prefix) - \(String(format: "%.1f M", meters))"
            }
        }
        
        return currentValue
    }
}

extension DeviceSettingViewController: BluetoothDeviceCoordinatorDelegate {
    func didConnectToDevice(message: String?) {
        if let msg = message {
            showAlert(on: self, message: msg, okHandler: {
                self.loadSettings()
                self.tableview.reloadData()
            })
        }
    }
}

// MARK: - UITableViewDataSource

extension DeviceSettingViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = settings[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath) as! SettingCell
        cell.bindRow(row: row, modelId: device.modelId ?? 0)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = settings[indexPath.row]
        
        if let subRows = row.subRows, !subRows.isEmpty {
            // Nếu có subRows thì push sang màn con
            let vc = UIStoryboard(name: "Device", bundle: nil)
                .instantiateViewController(withIdentifier: "SubSettingsViewController") as! SubSettingsViewController
            //vc.rows = subRows.filter { $0.hidden != 1 }
            vc.rows = subRows
            vc.rowId = row.id
            vc.sectionTitle = row.title.localized
            vc.device = device
            navigationController?.pushViewController(vc, animated: true)
        } else {
            // Xử lý các loại settings khác tại đây nếu cần
            
            switch row.type {
            case .twoValueSelector:
                
                guard let currentValue = row.value else {
                    return
                }
                
                var timeToDimValue = ""
                var dimToBrightnessValue = ""

                if currentValue == OFF {
                    timeToDimValue = OFF
                    timeToDimValue = "10%"
                } else {
                    let components = currentValue.components(separatedBy: " - ")
                    if components.count == 2 {
                        timeToDimValue = components[0]
                        dimToBrightnessValue = components[1]
                    }
                }
                
                let leftOptionsToUse: [String] = row.left_options ?? []
                var rightOptionsToUse: [String] = row.right_options ?? []
                
                // Nếu optionsToUse rỗng thì return
                guard !leftOptionsToUse.isEmpty else { return }
                guard !rightOptionsToUse.isEmpty else { return }
                
                var leftTitle: String? = nil
                var rightTitle: String? = nil
                if row.id == "set_backlight" {
                    leftTitle = "Brightness"
                    rightTitle = "Duration"
                } else if row.id == "set_divemode" {
                    leftTitle = "Auto Mode"
                    rightTitle = "Log Start Depth"
                    
                    // CR5
                    if DeviceSettings.shared.unit == FT {
                        rightOptionsToUse = rightOptionsToUse.map { item in
                            guard let meters = Double(item.components(separatedBy: " ").first ?? "") else { return item }
                            
                            var feet = meters * CONST_M_TO_FT
                            feet = floor(feet * 10) / 10
                            
                            return String(format: "%.1f FT", feet)
                        }
                    }
                }
                
                Set2ValueSettingAlert2.showMessage(message: row.title.localized,
                                                   leftTitle: leftTitle,
                                                   rightTitle: rightTitle,
                                                   leftValue: timeToDimValue,
                                                   rightValue: dimToBrightnessValue,
                                                   leftOptions: leftOptionsToUse,
                                                   rightOptions: rightOptionsToUse) { [weak self] action, selectedValue in
                    guard let self = self else { return }
                    
                    if let selectedValue = selectedValue, action == .allow {
                        self.settings[indexPath.row].value = selectedValue
                        self.tableview.reloadRows(at: [indexPath], with: .automatic)
                    }
                }
                
            default:
                guard let options = row.options, options.count > 0 else {
                    return
                }
                
                ItemSelectionAlert.showMessage(
                    message: row.title.localized,
                    options: options,
                    selectedValue: row.value
                ) { [weak self] action, value, index in
                    guard let self = self else { return }
                    
                    if action == .allow, let value = value {
                        if let id = row.id, id == "units" {
                            DeviceSettings.shared.unit = (value == "M - °C") ? 0 : 1
                            
                            let defaultValues: [String: String] = [
                                "mdepth": OFF,
                                "turn_pressure": OFF,
                                "end_pressure": OFF,
                                "safety_stop": OFF,
                            ]
                            
                            var idsToReload = ["units"]
                            
                            if Int(device.modelId ?? 0) == C_GRA || Int(device.modelId ?? 0) == C_CEN {
                                idsToReload.append("set_divemode")
                            }
                            
                            resetSettings(in: &self.settings, with: defaultValues)
                            
                            let indexPaths = getIndexPaths(for: idsToReload, in: self.settings)
                            if !indexPaths.isEmpty {
                                self.settings[indexPath.row].value = value
                                self.tableview.reloadRows(at: indexPaths, with: .automatic)
                            }
                        } else {
                            self.settings[indexPath.row].value = value
                            self.tableview.reloadRows(at: [indexPath], with: .automatic)
                        }
                        PrintLog("Save to backend: \(value)")
                    }
                }
            }
        }
    }
}

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
        
        applyValues()
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
    
    func applyValues() {
        if let sections = loadSettingsSections(from: "SE_device"), sections.count > 0 {
            //settings = sections[0].rows
            
            var excludedIDsForModel: [String] = []
            switch Int(device.modelId ?? 0) {
            case C_SKI, C_SPI:
                excludedIDsForModel = ["set_brightness", "set_autoDim"]
            default: // DAV
                excludedIDsForModel = ["set_backlight_duration"]
                break
            }
            
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
        
        let settings = getPDCSettings()
        
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
            guard let matchedDevice = peripherals.first(where: { $0.peripheral.name == device.Identity }) else {
                PrintLog("Device not found in scannedDevices yet")
                
                showAlert(on: self, title: "Device not found!".localized, message: "Ensure that your Device is ON and Bluetooth is opened.".localized)
                
                return
            }
            
            BluetoothDeviceCoordinator.shared
                .connect(to: matchedDevice.peripheral, discover: true)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] manager in
                    guard let self = self else { return }
                    
                    // Set ModelID nếu cần
                    if let (bleName, _) = matchedDevice.peripheral.peripheral.splitDeviceName(),
                       let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                        manager.ModelID = dcInfo[2].toInt()
                    }
                    
                    manager.readAllSettings()
                    
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    
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
            if let id = rows[i].id, let defaultValue = defaults[id] {
                rows[i].value = defaultValue
            }

            if var sub = rows[i].subRows {
                resetSettings(in: &sub, with: defaults)
                rows[i].subRows = sub
            }
        }
    }
}

extension DeviceSettingViewController: BluetoothDeviceCoordinatorDelegate {
    func didConnectToDevice(message: String?) {
        if let msg = message {
            showAlert(on: self, message: msg, okHandler: {
                self.applyValues()
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
        cell.bindRow(row: row)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = settings[indexPath.row]
        
        if let subRows = row.subRows, !subRows.isEmpty {
            // Nếu có subRows thì push sang màn con
            let vc = UIStoryboard(name: "Device", bundle: nil)
                .instantiateViewController(withIdentifier: "SubSettingsViewController") as! SubSettingsViewController
            vc.rows = subRows.filter { $0.hidden != 1 }
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
                let rightOptionsToUse: [String] = row.right_options ?? []
                
                // Nếu optionsToUse rỗng thì return
                guard !leftOptionsToUse.isEmpty else { return }
                guard !rightOptionsToUse.isEmpty else { return }
                
                Set2ValueSettingAlert2.showMessage(message: row.title.localized,
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
                                "mdepth": "OFF",
                                "safety_stop": "OFF",
                            ]
                            resetSettings(in: &self.settings, with: defaultValues)
                        }
                        
                        self.settings[indexPath.row].value = value
                        self.tableview.reloadRows(at: [indexPath], with: .automatic)
                        
                        PrintLog("Save to backend: \(value)")
                    }
                }
            }
        }
    }
}

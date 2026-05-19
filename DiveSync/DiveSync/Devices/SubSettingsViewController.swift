//
//  SubSettingsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/29/25.
//

import UIKit
import RxSwift
import ProgressHUD
import RxBluetoothKit

class SubSettingsViewController: BaseViewController {
    
    @IBOutlet weak var tableview: UITableView!
    
    @IBOutlet weak var uploadView: UIView!
    @IBOutlet weak var uploadDateView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var uploadDateTimeLb: UILabel!
    @IBOutlet weak var deleteLb: UILabel!
    
    var device: Devices!
    
    var rows: [SettingsRow] = []
    
    var visibleRows: [SettingsRow] {
        return rows.filter { $0.hidden != 1 }
    }
    
    var rowId: String? = nil
    var sectionTitle: String?
    
    private var disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: sectionTitle ?? "",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        tableview.register(UINib(nibName: "DSToggleCell", bundle: nil), forCellReuseIdentifier: "DSToggleCell")
        tableview.register(UINib(nibName: "DSGasCell", bundle: nil), forCellReuseIdentifier: "DSGasCell")
        
        tableview.dataSource = self
        tableview.delegate = self
        
        uploadDateView.isHidden = true
        deleteView.isHidden = true
        if let rowid = rowId, rowid == "set_date_time" || rowid == "set_owner_info" {
            uploadView.isHidden = false
            if rowid == "set_date_time" {
                uploadDateView.isHidden = false
            } else if rowid == "set_owner_info" {
                deleteView.isHidden = false
                if let modelId = device.modelId, modelId == C_DAV {
                    uploadDateView.isHidden = false
                    uploadDateTimeLb.text = "Upload Owner Info".localized
                }
            }
            
        } else {
            uploadView.isHidden = true
        }
    }
    
    override func updateTexts() {
        super.updateTexts()
        
        uploadDateTimeLb.text = "Upload Date/Time".localized
        deleteLb.text = "Delete".localized
    }
    
    func getPDCSettings() -> [String: Any] {
        if let rowid = rowId, rowid == "set_owner_info", let modelId = device.modelId, modelId == C_DAV {
            var ownerSettings: [String: Any] = [:]
            ownerSettings["DeviceID"] = device.deviceId
            
            for row in rows {
                let value = row.value ?? ""
                switch row.id {
                case "owner_name":
                    ownerSettings["Name"] = value
                case "owner_phone":
                    ownerSettings["Phone"] = value
                case "owner_mail":
                    ownerSettings["Email"] = value
                case "owner_blood_type":
                    ownerSettings["Blood"] = value
                case "owner_emname":
                    ownerSettings["EmName"] = value
                case "owner_emergency_contact_phone":
                    ownerSettings["EmPhone"] = value
                default:
                    break
                }
            }
            
            return ownerSettings
        } else {
            var dateTimeSetting: [String: Any] = [:]
            
            dateTimeSetting["DeviceID"] = device.deviceId
            
            for row in rows {
                var index = 0
                let value = row.value ?? ""
                
                let options = row.options
                if options != nil {
                    index = options!.firstIndex(of: value) ?? 0
                }
                
                switch row.id {
                    // System Settings
                case "hour":
                    dateTimeSetting["TimeFormat"] = index
                case "dates":
                    dateTimeSetting["DateFormat"] = index
                case "dst":
                    dateTimeSetting["DST"] = index
                case "set_date":
                    dateTimeSetting["SetDate"] = value
                case "set_time":
                    dateTimeSetting["SetTime"] = value
                case "set_timezone":
                    dateTimeSetting["TimeZone"] = index
                default:
                    break
                }
            }
            
            return dateTimeSetting
        }
    }
    
    @IBAction func uploadTapped(_ sender: Any) {
        
        searchType = .kSetting
        syncType = .kUploadDateTime
        if let rowid = rowId, rowid == "set_owner_info", let modelId = device.modelId, modelId == C_DAV {
            syncType = .kUploadOwnerInfo
        }
        
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
                    guard let self = self else { return }
                    
                    // 1. Ép kiểu về Protocol chung để xử lý logic cơ bản
                    let manager: BluetoothManagerProtocol
                    switch session {
                    case .normalSession(let m): manager = m
                    case .crSession(let m): manager = m
                    case .cr4Session(let m): manager = m
                    case .cr5Session(let m): manager = m
                    }
                    
                    // 2. Logic Set ModelID (Viết 1 lần cho cả 2)
                    if let (bleName, _) = matchedDevice.splitDeviceName(),
                       let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                        manager.ModelID = dcInfo[2].toInt()
                    }
                    
                    // 3. Xử lý riêng cho Owner Info bằng cách kiểm tra ép kiểu
                    if let modelId = device.modelId, modelId == C_DAV {
                        let uploadData = self.generateOwnerUploadData()
                        
                        // Kiểm tra xem manager hiện tại có hỗ trợ uploadOwnerInfoData không
                        if let dataManager = manager as? BluetoothDataManager {
                            dataManager.uploadOwnerInfoData = uploadData
                        }
                    }
                    
                    // 4. Luôn gọi readAllSettings sau cùng (vì thuộc Protocol chung)
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
                    
                }).disposed(by: disposeBag)
        }
        
    }
    
    @IBAction func deleteTapped(_ sender: Any) {
        for row in rows {
            row.value = ""
        }
        self.tableview.reloadData()
    }
    
    private func generateOwnerUploadData() -> Data {
        var ownerName = ""
        var ownerPhone = ""
        var ownerEmail = ""
        var ownerBloodType = ""
        var emName = ""
        var emPhone = ""
        
        // Lặp qua tất cả rows
        for row in rows {
            switch row.id {
            case "owner_name":
                ownerName = row.value ?? ""
            case "owner_phone":
                ownerPhone = row.value ?? ""
            case "owner_mail":
                ownerEmail = row.value ?? ""
            case "owner_blood_type":
                ownerBloodType = row.value ?? ""
            case "owner_emname":
                emName = row.value ?? ""
            case "owner_emergency_contact_phone":
                emPhone = row.value ?? ""
            default:
                break
            }
        }
        
        // Tạo struct từ các giá trị vừa lấy
        let owner = OwnerInfo(
            name: ownerName,
            phone: ownerPhone,
            email: ownerEmail,
            bloodType: ownerBloodType
        )
        
        let emergency = EmergencyContact(
            name: emName,
            phone: emPhone
        )
        
        let ownerInfoView = OwnerInfoCardViewBuilder.build(
            owner: owner,
            emergency: emergency
        )
        
        let image240 = renderViewToImage(ownerInfoView, size: CGSize(width: 240, height: 240))
        
        let uploadData = image240.rgb565Data(size: CGSize(width: 240, height: 240)) //imageToUploadData(image240)!
        
        return uploadData!
    }
}

extension SubSettingsViewController: BluetoothDeviceCoordinatorDelegate {
    func didConnectToDevice(message: String?) {
        if let msg = message {
            showAlert(on: self, message: msg, okHandler: {
            })
        }
    }
}

extension SubSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleRows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = visibleRows[indexPath.row]
        
        if row.type == .toggle {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DSToggleCell", for: indexPath) as! DSToggleCell
            cell.bindRow(row: row)
            return cell
        } else if row.type == .gasSelector {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DSGasCell", for: indexPath) as! DSGasCell
            cell.bindRow(row: row)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingCell", for: indexPath) as! SettingCell
            cell.bindRow(row: row, modelId: device.modelId ?? 0)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let modelID = Int(device.modelId ?? 0)
        
        let row = visibleRows[indexPath.row]
        
        if let disable = row.disable, disable == 1 {
            return
        }
        
        switch row.type {
        case .time:
            if let rowValue = row.value {
                /*
                let components = rowValue.split(separator: ":") // ["01", "58"]
                let hour = String(components[0])
                let minute = String(components[1])
                
                SetTimeAlert.showMessage(hourValue: hour, minValue: minute) { [weak self] action, value in
                    guard let self = self else { return }
                    self.rows[indexPath.row].value = value
                    self.tableview.reloadRows(at: [indexPath], with: .automatic)
                }
                */
                
                var outputFormat = "HH:mm"
                for row in rows {
                    if ["hour"].contains(row.id) {
                        if let value = row.value, value.toInt() == 12 {
                            outputFormat = "hh:mm a"
                        }
                        break
                    }
                }
                
                presentTimePicker(from: self, selectedTime: rowValue, outputFormat: outputFormat) { value in
                    row.value = value
                    self.tableview.reloadRows(at: [indexPath], with: .automatic)
                }
                
            }
        case .date:
            
            var dateFormatIdx = 0
            for row in rows {
                if ["dates"].contains(row.id) {
                    if let options = row.options {
                        dateFormatIdx = options.firstIndex(of: row.value ?? "") ?? 0
                    }
                    break
                }
            }
            
            EditProfilePopupManager.showBirthDatePicker(
                in: self,
                title: row.title,
                currentValue: row.value,
                inputFormat: (dateFormatIdx == 0) ? "dd.MM.yyyy":"MM.dd.yyyy",
                onSave: { [weak self] newDateString in
                    guard let self = self else { return }
                    
                    self.visibleRows[indexPath.row].value = newDateString
                    self.tableview.reloadRows(at: [indexPath], with: .automatic)
                }
            )
        case .inputText:
            
            var keyType: UIKeyboardType = .default
            if row.id == "owner_phone" || row.id == "owner_emergency_contact_phone" {
                keyType = .phonePad
            } else if row.id == "owner_mail" {
                keyType = .emailAddress
            }
            
            InputAlert.show(
                title: row.title.localized,
                saveTitle: "Set".localized.uppercased(),
                currentValue: row.value ?? "",
                keyboardType: keyType,
                maxLength: 20) { action in
                    switch action {
                    case .save(let value):
                        self.visibleRows[indexPath.row].value = value?.uppercased()
                        self.tableview.reloadRows(at: [indexPath], with: .automatic)
                    default:
                        break
                    }
                }
            
        case .twoValueSelector:
            guard let currentValue = row.value else {
                return
            }
            
            var safetyStopDepthValue = ""
            var safetyStopTimeValue = ""

            if currentValue == OFF {
                safetyStopDepthValue = OFF
                safetyStopTimeValue = ""
            } else {
                let components = currentValue.components(separatedBy: " - ")
                if components.count == 2 {
                    safetyStopDepthValue = components[0]
                    safetyStopTimeValue = components[1]
                }
            }
            
            var leftOptionsToUse: [String] = []
            let rightOptionsToUse: [String] = row.safetyStopTime ?? []
            
            if DeviceSettings.shared.unit == 0 {
                if let opts = row.safetyStopDepth_m, !opts.isEmpty {
                    leftOptionsToUse = opts
                }
            } else {
                if let opts = row.safetyStopDepth_ft, !opts.isEmpty {
                    leftOptionsToUse = opts
                }
            }
            
            // Nếu optionsToUse rỗng thì return
            guard !leftOptionsToUse.isEmpty else { return }
            guard !rightOptionsToUse.isEmpty else { return }
            
            Set2ValueSettingAlert.showMessage(message: row.title,
                                              leftValue: safetyStopDepthValue,
                                              rightValue: safetyStopTimeValue,
                                              leftOptions: leftOptionsToUse,
                                              rightOptions: rightOptionsToUse) { [weak self] action, selectedValue in
                guard let self = self else { return }
                
                if let selectedValue = selectedValue, action == .allow {
                    if selectedValue.hasPrefix(OFF) {
                        self.visibleRows[indexPath.row].value = OFF
                    } else {
                        self.visibleRows[indexPath.row].value = selectedValue
                    }
                    self.tableview.reloadRows(at: [indexPath], with: .automatic)
                }
            }
        
        default:
            guard var currentValue = row.value else {
                return
            }
            
            var optionsToUse: [String] = []

            if let id = row.id {
                if  id == "mdepth" ||
                    id == "log_start_depth" ||
                    id == "turn_pressure" ||
                    id == "end_pressure" ||
                    id == "depth_alarm" ||
                    id == "cr4_free_depth_alarm1" ||
                    id == "cr4_free_depth_alarm2" ||
                    id == "cr4_free_depth_alarm3" {
                    if DeviceSettings.shared.unit == 0 {
                        if let opts = row.options, !opts.isEmpty {
                            optionsToUse = opts
                        }
                    } else {
                        if let opts = row.options_ft, !opts.isEmpty {
                            optionsToUse = opts
                        }
                    }
                } else {
                    if let opts = row.options, !opts.isEmpty {
                        optionsToUse = opts
                    }
                }

                // Xử lý riêng cho các id cần convert thời gian
                if (id == "dive_time" || id == "no_deco") && currentValue != OFF {
                    let components = currentValue.split(separator: ":")
                    if components.count == 2,
                       let hours = Int(components[0]),
                       let minutes = Int(components[1]) {
                        let totalMinutes = hours * 60 + minutes
                        currentValue = "\(totalMinutes) MIN"
                    }
                }
            }

            // Nếu optionsToUse rỗng thì return
            guard !optionsToUse.isEmpty else { return }
            
            var notes: String? = nil
            if row.id == "conservatism" {
                switch modelID {
                case C_LOG, C_LOGPLUS, C_GRA, C_CEN:
                    notes = nil
                default:
                    notes = "GF"
                }
            }
            
            ItemSelectionAlert.showMessage(
                message: row.title.localized,
                options: optionsToUse,
                selectedValue: currentValue,
                notesValue: notes
            ) { [weak self] action, value, index in
                guard let self = self else { return }
                
                if action == .allow, var value = value {
                    var reloadAll = false
                    
                    if let id = row.id {
                        switch id {
                        case "dive_time", "no_deco":
                            // Convert "MIN" string to "H:MM" format
                            if value != OFF, value.hasSuffix("MIN") {
                                let numberPart = value.replacingOccurrences(of: " MIN", with: "")
                                if let totalMinutes = Int(numberPart) {
                                    let hours = totalMinutes / 60
                                    let minutes = totalMinutes % 60
                                    value = String(format: "%d:%02d", hours, minutes)
                                }
                            }
                            
                        case "gas2":
                            if value == OFF {
                                // Cap nhat lai gia tri cho max ppo2 và gas 4.
                                for row in rows {
                                    if ["gas2_po2", "gas3", "gas3_po2", "gas4", "gas4_po2"].contains(row.id) {
                                        row.disable = 1
                                        if ["gas3", "gas4"].contains(row.id) {
                                            row.value = OFF
                                        }
                                    }
                                }
                            } else {
                                for row in rows {
                                    if ["gas2_po2", "gas3", "gas3_po2"].contains(row.id) {
                                        row.disable = 0
                                    }
                                }
                            }
                            reloadAll = true
                        case "gas3":
                            if value == OFF {
                                // Cap nhat lai gia tri cho max ppo2 và gas 4.
                                for row in rows {
                                    if ["gas3_po2", "gas4", "gas4_po2"].contains(row.id) {
                                        row.disable = 1
                                        if ["gas4"].contains(row.id) {
                                            row.value = OFF
                                        }
                                    }
                                }
                            } else {
                                for row in rows {
                                    if ["gas3_po2", "gas4", "gas4_po2"].contains(row.id) {
                                        row.disable = 0
                                    }
                                }
                            }
                            reloadAll = true
                            
                            
                        // Set Date Time
                        case "dates":
                            
                            var fromFormat = ""
                            var toFormat = ""
                            
                            switch modelID {
                            case C_GRA, C_CEN:
                                // Ví dụ: value1 = "DD.MM.YY", value2 = "MM.DD.YY"
                                fromFormat = getStandardFormat(from: currentValue) // Trả về "dd.MM.yyyy"
                                toFormat = getStandardFormat(from: value)   // Trả về "MM.dd.yyyy"
                            default:
                                fromFormat = (index == 0) ? "MM.dd.yyyy" : "dd.MM.yyyy"
                                toFormat = (index == 0) ? "dd.MM.yyyy" : "MM.dd.yyyy"
                            }
                            
                            for row in rows {
                                if ["set_date"].contains(row.id) {
                                    let currentValue = row.value ?? ""
                                    row.value = Utilities.convertDateFormat(from: currentValue, fromFormat: fromFormat, toFormat: toFormat)
                                    break
                                }
                            }
                            
                            reloadAll = true
                        
                        case "hour":
                            var fromFormat: String = "HH:mm"
                            var toFormat: String = "hh:mm a"
                            if value == "24 H" {
                                fromFormat = "hh:mm a"
                                toFormat = "HH:mm"
                            }
                            
                            for row in rows {
                                if ["set_time"].contains(row.id) {
                                    let currentValue = row.value ?? ""
                                    row.value = Utilities.convertDateFormat(from: currentValue, fromFormat: fromFormat, toFormat: toFormat)
                                    break
                                }
                            }
                            
                            reloadAll = true
                        case "dive_mode":
                            if modelID == C_WIS5 {
                                /*
                                let conservatismRow = rows.first(where: { $0.id == "conservatism" })
                                let po2Row = rows.first(where: { $0.id == "gas1_po2" })
                                let fo2Row = rows.first(where: { $0.id == "gas1_fo2" })
                                
                                switch index {
                                case 0: // AIR
                                    conservatismRow?.hidden = 0
                                    po2Row?.hidden = 0
                                    fo2Row?.hidden = 1
                                    fo2Row?.value = "21%"
                                    po2Row?.value = "1.60"
                                    
                                case 1: // NITROX
                                    conservatismRow?.hidden = 0
                                    po2Row?.hidden = 0
                                    fo2Row?.hidden = 0
                                    fo2Row?.value = "22%"
                                    
                                default: // GAUGE (case 2)
                                    conservatismRow?.hidden = 1
                                    po2Row?.hidden = 1
                                    fo2Row?.hidden = 1
                                    fo2Row?.value = "21%"
                                    po2Row?.value = "1.60"
                                }
                                reloadAll = true
                                */
                            } else {
                                if value != "NITROX" {
                                    rows.first(where: { $0.id == "fo2" })?.value = "21"
                                    reloadAll = true
                                }
                            }
                        case "gas1_fo2":
                            if modelID == C_WIS5 {
                                /*
                                if index == 0 { // 21%
                                    // 1. Tìm dòng dive_mode để chuyển index về 0 (AIR)
                                    if let diveModeRow = rows.first(where: { $0.id == "dive_mode" }) {
                                        diveModeRow.value = "AIR"
                                    }
                                    
                                    // 2. Cập nhật lại trạng thái ẩn/hiện cho Wisdom 5 giống như mode AIR
                                    rows.first(where: { $0.id == "conservatism" })?.hidden = 0
                                    rows.first(where: { $0.id == "gas1_po2" })?.hidden = 0
                                    rows.first(where: { $0.id == "gas1_fo2" })?.hidden = 1
                                    
                                    reloadAll = true
                                }
                                */
                            }
                        case "fo2":
                            if value.toInt() > 21 {
                                rows.first(where: { $0.id == "dive_mode" })?.value = "NITROX"
                                reloadAll = true
                            }
                        case "set_all_alarm":
                            if modelID == C_WIS5 {
                                let asntRow = rows.first(where: { $0.id == "set_asnt" })
                                let mdepthRow = rows.first(where: { $0.id == "mdepth" })
                                let turnPressureRow = rows.first(where: { $0.id == "turn_pressure" })
                                let endPressureRow = rows.first(where: { $0.id == "end_pressure" })
                                let reserveTimeRow = rows.first(where: { $0.id == "reserve_time" })
                                let setDecoRow = rows.first(where: { $0.id == "set_deco" })
                                let setPo2Row = rows.first(where: { $0.id == "set_po2" })
                                
                                let hidden = (index == 0) ? 1 : 0
                                
                                asntRow?.hidden = hidden
                                mdepthRow?.hidden = hidden
                                turnPressureRow?.hidden = hidden
                                endPressureRow?.hidden = hidden
                                reserveTimeRow?.hidden = hidden
                                setDecoRow?.hidden = hidden
                                setPo2Row?.hidden = hidden
                                
                                reloadAll = true
                            }
                        default:
                            break
                        }
                    }
                    
                    self.visibleRows[indexPath.row].value = value
                    if reloadAll {
                        self.tableview.reloadData()
                    } else {
                        self.tableview.reloadRows(at: [indexPath], with: .automatic)
                    }
                    
                    PrintLog("Save to backend: \(value)")
                }
            }
        }
    }
}

func presentTimePicker(from viewController: UIViewController,
                       selectedTime: String? = nil,
                       outputFormat: String? = "HH:mm",
                       onTimePicked: @escaping (String) -> Void) {
    let alert = UIAlertController(title: nil, message: "\n\n\n\n\n\n", preferredStyle: .actionSheet)
    let title = "Set Time".localized
    let attributedTitle = NSAttributedString(string: title, attributes: [
        .font: UIFont.boldSystemFont(ofSize: 20),
        .foregroundColor: UIColor.systemBlue
    ])
    alert.setValue(attributedTitle, forKey: "attributedTitle")
    
    let picker = UIDatePicker()
    picker.datePickerMode = .time
    picker.preferredDatePickerStyle = .wheels
    picker.locale = Locale(identifier: "en_US_POSIX")
    
    // 👉 Nếu có selectedTime thì dùng, không thì dùng giờ hiện tại
    if let selectedTime = selectedTime {
        let formatter = DateFormatter()
        if Utilities.isLastCharacterLetterRegex(selectedTime) {
            formatter.dateFormat = "hh:mm a"
            formatter.locale = Locale(identifier: "en_US")
        } else {
            formatter.dateFormat = "HH:mm"
            picker.locale = Locale(identifier: "en_GB")
        }
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = formatter.date(from: selectedTime) {
            picker.date = date
        }
    } else {
        picker.date = Date() // ⏰ giờ hiện tại
    }
    
    picker.frame = CGRect(x: 0, y: 30, width: alert.view.bounds.width - 20, height: 160)
    alert.view.addSubview(picker)
    
    alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "Set".localized, style: .default, handler: { _ in
        let formatter = DateFormatter()
        formatter.dateFormat = outputFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timeString = formatter.string(from: picker.date)
        onTimePicked(timeString)
    }))
    
    viewController.present(alert, animated: true, completion: nil)
}

extension SubSettingsViewController {
    func renderViewToImage(_ view: UIView, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            view.layer.render(in: context.cgContext)
        }
    }
    
    func getStandardFormat(from jsonFormat: String) -> String {
        // Chuyển "YY.MM.DD" hoặc "DD.MM.YY" thành các thành phần riêng lẻ
        let components = jsonFormat.lowercased().components(separatedBy: ".")
        
        let standardComponents = components.map { comp -> String in
            switch comp {
            case "dd": return "dd"
            case "mm": return "MM"   // Ép tháng thành MM viết hoa
            case "yy": return "yyyy" // Ép năm thành yyyy (4 số)
            default: return comp
            }
        }
        
        return standardComponents.joined(separator: ".")
    }
}

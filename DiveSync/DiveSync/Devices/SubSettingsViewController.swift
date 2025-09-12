//
//  SubSettingsViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/29/25.
//

import UIKit
import RxSwift
import ProgressHUD

class SubSettingsViewController: UIViewController {
    
    @IBOutlet weak var tableview: UITableView!
    
    @IBOutlet weak var uploadView: UIView!
    @IBOutlet weak var uploadDateView: UIView!
    @IBOutlet weak var deleteView: UIView!
    
    var device: Devices!
    
    var rows: [SettingsRow] = []
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
            }
            
        } else {
            uploadView.isHidden = true
        }
    }
    
    func getPDCSettings() -> [String: Any] {
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
            case "set_date":
                dateTimeSetting["SetDate"] = value
            case "set_time":
                dateTimeSetting["SetTime"] = value
            default:
                break
            }
        }
        
        return dateTimeSetting
    }
    
    @IBAction func uploadTapped(_ sender: Any) {
        
        searchType = .kSetting
        syncType = .kUploadDateTime
        
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
            deviceConnected.readAllSettings2()
        } else {
            // Chua ket noi thi thuc hien ket noi
            
            let peripherals = BluetoothDeviceCoordinator.shared.scannedDevices.value
            guard let matchedDevice = peripherals.first(where: { $0.peripheral.name == device.Identity }) else {
                PrintLog("Device not found in scannedDevices yet")
                
                showAlert(on: self, title: "Device not found!", message: "Ensure that your device is ON and Bluetooth is opened.")
                
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
                    
                    manager.readAllSettings2()
                    
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    
                    ProgressHUD.dismiss()
                    
                    PrintLog("❌ Connect error: \(error.localizedDescription)")
                    BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: error.localizedDescription)
                    
                }).disposed(by: disposeBag)
        }
        
    }
    
    @IBAction func deleteTapped(_ sender: Any) {
        for row in rows {
            row.value = ""
        }
        self.tableview.reloadData()
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
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        
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
            cell.bindRow(row: row)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rows[indexPath.row]
        
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
                    
                    self.rows[indexPath.row].value = newDateString
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
            
            InputAlert.show(title: row.title, saveTitle: "SET", currentValue: row.value ?? "", keyboardType: keyType) { action in
                switch action {
                case .save(let value):
                    self.rows[indexPath.row].value = value?.uppercased()
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
            
            Set2ValueSettingAlert.showMessage(leftValue: safetyStopDepthValue,
                                              rightValue: safetyStopTimeValue,
                                              leftOptions: leftOptionsToUse,
                                              rightOptions: rightOptionsToUse) { [weak self] action, selectedValue in
                guard let self = self else { return }
                
                if let selectedValue = selectedValue, action == .allow {
                    if selectedValue.hasPrefix(OFF) {
                        self.rows[indexPath.row].value = OFF
                    } else {
                        self.rows[indexPath.row].value = selectedValue
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
                if id == "mdepth" {
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
            if row.id == "conservatism" { notes = "GF" }
            
            ItemSelectionAlert.showMessage(
                message: row.title,
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
                            var fromFormat: String = "dd.MM.yyyy"
                            var toFormat: String = "MM.dd.yyyy"
                            if index == 0 {
                                fromFormat = "MM.dd.yyyy"
                                toFormat = "dd.MM.yyyy"
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
                            if index == 0 {
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
                        default:
                            break
                        }
                    }
                    
                    self.rows[indexPath.row].value = value
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
    let title = "Set Time"
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
        } else {
            formatter.dateFormat = "HH:mm"
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
    
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "Set", style: .default, handler: { _ in
        let formatter = DateFormatter()
        formatter.dateFormat = outputFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timeString = formatter.string(from: picker.date)
        onTimePicked(timeString)
    }))
    
    viewController.present(alert, animated: true, completion: nil)
}

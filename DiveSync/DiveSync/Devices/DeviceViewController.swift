//
//  DeviceViewController.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/16/25.
//

//
//  DeviceViewController.swift
//  DiveSync
//

import UIKit
import RxSwift
import ProgressHUD
import RxBluetoothKit

class DeviceViewController: BaseViewController {

    @IBOutlet weak var deviceView: UIView!
    @IBOutlet weak var deviceImageView: UIImageView!
    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var serialNoLb: UILabel!
    @IBOutlet weak var versionLb: UILabel!
    @IBOutlet weak var syncedLb: UILabel!
    
    @IBOutlet weak var connectImv: UIImageView!
    @IBOutlet weak var connectLb: UILabel!
    
    @IBOutlet weak var autosyncSwitch: UISwitch!
    
    private var disposeBag = DisposeBag()
    
    var device: Devices!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem,
                                                  title: self.title ?? "Device",
                                                  pushBack: true,
                                                  backImage: "chevron.backward")
        self.title = nil
        
        setupUI()
        subscribeScannedDevices()
        updateDeviceStateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateDeviceStateUI()
    }
    
    private func setupUI() {
        deviceImageView.image = UIImage(named: "\(device.modelId ?? 0)") ?? UIImage(named: "8682")
        deviceName.text = device.ModelName ?? ""
        serialNoLb.text = String(format: "%05d", device.SerialNo?.toInt() ?? 0)
        versionLb.text = "Version: \(device.Firmware ?? "")"
        syncedLb.text = "Synced: " + (device.LastSync ?? "")
        
        if let deviceIdentify = device.Identity, let autosyncDeviceIdentify:String = AppSettings.shared.get(forKey: AppSettings.Keys.autosyncDeviceIdentify), deviceIdentify == autosyncDeviceIdentify {
            autosyncSwitch.isOn = true
        }
        
    }
    
    // 1️⃣ Subscribe relay 1 lần duy nhất
    private func subscribeScannedDevices() {
        BluetoothDeviceCoordinator.shared.scannedDevices
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] peripherals in
                guard let self = self else { return }
                
                if let matchedDevice = peripherals.first(where: { $0.peripheral.name == self.device.Identity }) {
                    PrintLog("Peripheral found: \(matchedDevice.peripheral.name ?? "")")
                    
                    // Update UI tự động khi thiết bị advertise hoặc scan lại
                    self.updateDeviceStateUI()
                }
            })
            .disposed(by: disposeBag)
    }
    
    // 2️⃣ Cập nhật trạng thái Connected/Disconnected
    private func updateDeviceStateUI() {
        if let activeManager = BluetoothDeviceCoordinator.shared.activeDataManager,
           activeManager.SerialNo == device.SerialNo?.toInt(),
           activeManager.ModelID == device.modelId ?? 0,
           activeManager.peripheral.peripheral.state == .connected {
            
            deviceView.layer.borderColor = UIColor.systemGreen.cgColor
            connectImv.image = UIImage(named: "disconnected_icon")
            connectLb.text = "Disconnect"
            
            PrintLog("CONNECTED")
        } else {
            deviceView.layer.borderColor = UIColor.lightGray.cgColor
            connectImv.image = UIImage(named: "connected_icon")
            connectLb.text = "Connect"
            
            PrintLog("DISCONNECTED")
        }
    }
    
    // Tách thành hàm tiện dụng để xóa dữ liệu DB và update autosync
    private func deleteDeviceData() {
        // Nếu device này đang là autosync → remove key
        if let targetIdentity: String = AppSettings.shared.get(forKey: AppSettings.Keys.autosyncDeviceIdentify),
           targetIdentity == self.device.Identity {
            AppSettings.shared.remove(forKey: AppSettings.Keys.autosyncDeviceIdentify)
        }

        // Xóa dữ liệu liên quan
        DatabaseManager.shared.deleteRows(from: "DeviceGasMixesSettings", where: "DeviceID=?", arguments: [self.device.deviceId])
        DatabaseManager.shared.deleteRows(from: "DeviceSettings", where: "DeviceID=?", arguments: [self.device.deviceId])
        DatabaseManager.shared.deleteRows(from: "Devices", where: "DeviceID=?", arguments: [self.device.deviceId])

        self.navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Actions
    @IBAction func connectTapped(_ sender: Any) {
        BluetoothDeviceCoordinator.shared.delegate = self
        
        if let activeManager = BluetoothDeviceCoordinator.shared.activeDataManager,
           activeManager.SerialNo == device.SerialNo?.toInt(),
           activeManager.ModelID == device.modelId ?? 0,
           activeManager.peripheral.peripheral.state == .connected {
            // Disconnect
            BluetoothDeviceCoordinator.shared.disconnect()
            
            // Reset
            //self.disposeBag = DisposeBag()
            self.updateDeviceStateUI()
            
        } else {
            // Tìm thiết bị trong relay
            let peripherals = BluetoothDeviceCoordinator.shared.scannedDevices.value
            guard let matchedDevice = peripherals.first(where: { $0.peripheral.name == device.Identity }) else {
                PrintLog("Device not found in scannedDevices yet")
                return
            }
            
            searchType = .kSetting
            syncType = .kConnectOnly
            
            // Connect
            BluetoothDeviceCoordinator.shared
                .connect(to: matchedDevice.peripheral, discover: true)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] manager in
                    guard let self = self else { return }
                    
                    //ProgressHUD.dismiss()
                    
                    // Set ModelID nếu cần
                    if let (bleName, _) = matchedDevice.peripheral.peripheral.splitDeviceName(),
                       let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                        manager.ModelID = dcInfo[2].toInt()
                    }
                    
                    manager.readAllSettings2()
                    
                    self.updateDeviceStateUI()
                    
                }, onError: { error in
                    ProgressHUD.dismiss()
                    
                    if case BluetoothError.peripheralDisconnected = error {
                        PrintLog("ℹ️ Peripheral disconnected (user requested)")
                    } else {
                        PrintLog("❌ Connect error: \(error.localizedDescription)")
                        BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: error.localizedDescription)
                    }
                })
                .disposed(by: disposeBag)
        }
    }
    
    @IBAction func downloadTapped(_ sender: Any) {
        searchType = .kAddDive
        syncType = .kDownloadDiveData
        
        BluetoothDeviceCoordinator.shared.delegate = self
        if let deviceConnected = BluetoothDeviceCoordinator.shared.activeDataManager {
            // Da ket noi thi doc ngay
            deviceConnected.readAllSettings2()
        } else {
            // Chua ket noi thi thuc hien ket noi
            
            let peripherals = BluetoothDeviceCoordinator.shared.scannedDevices.value
            guard let matchedDevice = peripherals.first(where: { $0.peripheral.name == device.Identity }) else {
                PrintLog("Device not found in scannedDevices yet")
                
                showAlert(on: self, message: "Device not found!")
                
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
                    
                    self.updateDeviceStateUI()
                    
                    manager.readAllSettings2()
                    
                }, onError: { error in
                    ProgressHUD.dismiss()
                    PrintLog("❌ Connect error: \(error.localizedDescription)")
                    BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: error.localizedDescription)
                }).disposed(by: disposeBag)
        }
    }
    
    @IBAction func checkFirmwareTapped(_ sender: Any) {
        
        guard let deviceConnected = BluetoothDeviceCoordinator.shared.activeDataManager else {
            DialogViewController.showMessage(title: "Firmware Update", message: "Please connect to your dive computer")
            return
        }
        
        let currentFw = deviceConnected.firmwareRev
        let msg = "Looking new firmware\nCurrent: v \(currentFw)"
        DialogViewController.showLoading(title: "Firmware Update", message: msg, task:  {_ in
            
            let group = DispatchGroup()
            var iniContent: String?
            var readmeContent: String?
            
            // .ini
            group.enter()
            FirmwareAPI.fetchText(from: "https://www.pelagicservices.com/firmware/PADAV_EN_Released.ini") { text in
                iniContent = text
                group.leave()
            }
            
            // .Readme
            group.enter()
            FirmwareAPI.fetchText(from: "https://www.pelagicservices.com/firmware/PADAV_EN_Released.Readme") { text in
                readmeContent = text
                group.leave()
            }
            
            group.notify(queue: .main) {
                // báo DialogViewController loading xong
                
                DialogViewController.dismissAlert() {
                    
                    if let ini = iniContent, let readme = readmeContent {
                        // Tách theo ký tự "|"
                        let parts = ini.components(separatedBy: "|")
                        if let latestVersion = parts.first {
                            // So sánh với currentFw
                            if latestVersion.compare(currentFw, options: .numeric) == .orderedDescending {
                                let fwVC = FirmwarePageViewController()
                                fwVC.iniContent = ini
                                fwVC.readmeContent = readme
                                fwVC.onAgree = { [self] in
                                    downloadFirmwareProcess(latestVersion: latestVersion)
                                }
                                self.present(fwVC, animated: true)
                            } else {
                                DialogViewController.showMessage(title: "Firmware Update", message: "Your dive computer firmware is up to date!")
                            }
                        }
                    }
                }
            }
            
        })
    }
    
    @IBAction func gotoDeviceSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Device", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "DeviceSettingViewController") as! DeviceSettingViewController
        vc.device = device
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func removeTapped(_ sender: Any) {
        
        PrivacyAlert.showMessage(message: "Are you sure to want to delete this device?", allowTitle: "YES", denyTitle: "NO") { action in
            switch action {
            case .allow:
                
                if let activeManager = BluetoothDeviceCoordinator.shared.activeDataManager,
                   activeManager.SerialNo == self.device.SerialNo?.toInt(),
                   activeManager.ModelID == self.device.modelId ?? 0,
                   activeManager.peripheral.peripheral.state == .connected {
                    // Disconnect
                    BluetoothDeviceCoordinator.shared.disconnect()
                    
                    // Reset
                    self.disposeBag = DisposeBag()
                    
                    self.deleteDeviceData()
                } else {
                    // Nếu không connect → xóa luôn
                    self.deleteDeviceData()
                }
                
            default:
                break
            }
        }
    }
    
    @IBAction func autoSyncSwitched(_ sender: Any) {
        
        guard let sw = sender as? UISwitch else { return }
        let isOn = sw.isOn
        if isOn {
            // Alert
            PrivacyAlert.showMessage(message: "Enabling this option allows the app to automatically connect and retrieve all dive logs each time it is launched.", allowTitle: "ENABLED", denyTitle: "CLOSE") { action in
                if  action == .deny {
                    self.autosyncSwitch.isOn = false
                } else {
                    print("ENABLED")
                    AppSettings.shared.set(self.device.Identity, forKey: AppSettings.Keys.autosyncDeviceIdentify)
                }
            }
        } else {
            AppSettings.shared.remove(forKey: AppSettings.Keys.autosyncDeviceIdentify)
        }
        
    }
    
}

extension DeviceViewController: BluetoothDeviceCoordinatorDelegate {
    func didConnectToDevice(message: String?) {
        if let msg = message {
            if syncType != .kConnectOnly {
                showAlert(on: self, message: msg)
            }
        }
    }
}

extension DeviceViewController {
    private func downloadFirmwareProcess(latestVersion: String) {
        DialogViewController.showProcess(
            title: "Firmware Update",
            message: "Downloading firmware v \(latestVersion)",
            task: { alertVC in
                
                guard let url = URL(string: "https://www.pelagicservices.com/firmware/PROASIA/PADAV.1_0_74.bin") else {
                    DialogViewController.finish(success: false)
                    return
                }
                
                // Tạo session có delegate để nhận tiến độ
                class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
                    var onProgress: ((Float) -> Void)?
                    var onFinish: ((Bool, URL?) -> Void)?
                    
                    func urlSession(_ session: URLSession,
                                    downloadTask: URLSessionDownloadTask,
                                    didWriteData bytesWritten: Int64,
                                    totalBytesWritten: Int64,
                                    totalBytesExpectedToWrite: Int64) {
                        guard totalBytesExpectedToWrite > 0 else { return }
                        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
                        DispatchQueue.main.async {
                            self.onProgress?(progress)
                        }
                    }
                    
                    func urlSession(_ session: URLSession,
                                    downloadTask: URLSessionDownloadTask,
                                    didFinishDownloadingTo location: URL) {
                        do {
                            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let destination = docs.appendingPathComponent(downloadTask.originalRequest?.url?.lastPathComponent ?? "firmware.bin")
                            if FileManager.default.fileExists(atPath: destination.path) {
                                try FileManager.default.removeItem(at: destination)
                            }
                            try FileManager.default.moveItem(at: location, to: destination)
                            DispatchQueue.main.async {
                                self.onFinish?(true, destination)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.onFinish?(false, nil)
                            }
                        }
                    }
                }
                
                let delegate = DownloadDelegate()
                let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
                let task = session.downloadTask(with: url)
                
                // Gán callback cập nhật UI
                delegate.onProgress = { progress in
                    DialogViewController.updateProgress(progress)
                }
                delegate.onFinish = { success, fileURL in
                    DialogViewController.dismissAlert {
                        if success {
                            PrintLog("✅ Saved firmware: \(fileURL?.path ?? "nil")")
                        } else {
                            DialogViewController.showMessage(title: "Firmware Update", message: "❌ Download failed")
                        }
                    }
                }
                
                // Start download
                task.resume()
                
                // Cho phép Cancel
                alertVC.cancelTask = {
                    task.cancel()
                }
            }
        )
    }
}

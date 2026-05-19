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

// ===== DownloadDelegate (file-scope) =====
private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((Float) -> Void)?
    var onFinish: ((Bool, URL?) -> Void)?
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        
        // Không có Content-Length → Content-Length: <file_size_in_bytes> thì sẽ không thể hiển thị % progress (phải sửa trên server)
        
        print("didWriteData called! bytesWritten=\(bytesWritten), totalBytesWritten=\(totalBytesWritten), totalExpected=\(totalBytesExpectedToWrite)")

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
            Utilities.removeAllBinFiles()
            
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            
            if let url = downloadTask.originalRequest?.url,
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let fileParam = components.queryItems?.first(where: { $0.name == "file" })?.value {
                
                let filename = (fileParam as NSString).lastPathComponent
                let destination = docs.appendingPathComponent(filename)
                
                try FileManager.default.moveItem(at: location, to: destination)
                
                DispatchQueue.main.async {
                    self.onFinish?(true, destination)
                }
            } else {
                DispatchQueue.main.async {
                    self.onFinish?(false, nil)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.onFinish?(false, nil)
            }
        }
    }
}

class DeviceViewController: BaseViewController {

    @IBOutlet weak var deviceCollectionView: UICollectionView!
    @IBOutlet weak var scrollContentView: UIScrollView!
    @IBOutlet weak var bottomView: UIView!
    
    @IBOutlet weak var deviceName: UILabel!
    @IBOutlet weak var serialNoLb: UILabel!
    @IBOutlet weak var versionLb: UILabel!
    @IBOutlet weak var syncedLb: UILabel!
    
    @IBOutlet weak var autosyncSwitch: UISwitch!
    
    @IBOutlet weak var nextBtn: UIButton!
    @IBOutlet weak var prevBtn: UIButton!
    
    @IBOutlet weak var statsTotalDivesValueLb: UILabel!
    @IBOutlet weak var statsTotalDiveTimeValueLb: UILabel!
    @IBOutlet weak var statsMdepthValueLb: UILabel!
    @IBOutlet weak var statsAvgDepthValueLb: UILabel!
    @IBOutlet weak var statsMinTempValueLb: UILabel!
    @IBOutlet weak var statsAltLevelValueLb: UILabel!
    
    @IBOutlet weak var autoSyncLb: UILabel!
    @IBOutlet weak var logStatisticLb: UILabel!
    @IBOutlet weak var totalDivesLb: UILabel!
    @IBOutlet weak var diveTimeLb: UILabel!
    @IBOutlet weak var maxDepthLb: UILabel!
    @IBOutlet weak var avgDepthLb: UILabel!
    @IBOutlet weak var minTempLb: UILabel!
    @IBOutlet weak var altLb: UILabel!
    @IBOutlet weak var logsLb: UILabel!
    @IBOutlet weak var settingsLb: UILabel!
    @IBOutlet weak var updateDcLb: UILabel!
    @IBOutlet weak var deleteLb: UILabel!
    @IBOutlet weak var tapOnLb: UILabel!
    
    @IBOutlet weak var updateDCView: UIView!
    
    @IBOutlet weak var autoSyncView: UIView!
    
    private var disposeBag = DisposeBag()

    private var currentIndex = 0
    
    var deviceCount = 0
    var deviceList: [Devices]?
    var currentDevice: Devices?
    
    // ✳️ Thêm properties để giữ delegate + session sống lâu
    private var firmwareDownloadDelegate: DownloadDelegate?
    private var firmwareDownloadSession: URLSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setCustomTitle(for: self.navigationItem, title: self.title ?? "", pushBack: true)
        self.title = nil
        
        var config = UIButton.Configuration.plain()
        config.title = "Add".localized
        config.image = UIImage(systemName: "plus")
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.baseForegroundColor = .white

        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in
            self.addBarButtonTapped()
        }, for: .touchUpInside)

        let addDeviceButton = UIBarButtonItem(customView: button)
        navigationItem.rightBarButtonItem = addDeviceButton
        
        // paging setup
        if let layout = deviceCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
        }
        
        subscribeScannedDevices()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadDevices()
    }
    
    override func updateTexts() {
        super.updateTexts()
        
        autoSyncLb.text = "Auto Sync".localized
        logStatisticLb.text = "Log Statistics".localized
        totalDivesLb.text = "Total Dives".localized
        diveTimeLb.text = "Dive Time".localized
        maxDepthLb.text = "Max Depth".localized
        avgDepthLb.text = "Avg Depth".localized
        minTempLb.text = "Min Temp".localized
        altLb.text = "Altitude Level".localized
        
        logsLb.text = "Logs".localized
        settingsLb.text = "Settings".localized
        updateDcLb.text = "Update DC".localized
        deleteLb.text = "Delete".localized
        tapOnLb.text = "Tap on + to add new device".localized
    }
    
    private func loadDevices() {
        deviceList = DatabaseManager.shared.fetchDevices()
        deviceCount = deviceList?.count ?? 0
        
        deviceCollectionView.reloadData()
        
        if let list = deviceList, !list.isEmpty {
            if let current = currentDevice,
               let matched = list.first(where: { $0.deviceId == current.deviceId }) {
                currentDevice = matched
            } else {
                currentDevice = list.first
            }
        } else {
            currentDevice = nil
        }
        
        if let index = deviceList?.firstIndex(where: { $0.deviceId == currentDevice?.deviceId }), index != currentIndex {
            currentIndex = index
            scrollToIndex(currentIndex)
        } else {
            updateButtonVisibility()
        }
        
        setupUI()
    }
    
    @objc func addBarButtonTapped() {
        searchType = .kAddDevice
        syncType = .kDownloadSetting
        
        let storyboard = UIStoryboard(name: "Device", bundle: nil)
        let bluetoothScanVC = storyboard.instantiateViewController(withIdentifier: "BluetoothScanViewController") as! BluetoothScanViewController
        self.navigationController?.pushViewController(bluetoothScanVC, animated: true)
    }
    
    private func setupUI() {
        guard
            let deviceList = deviceList,
            deviceList.indices.contains(currentIndex)
        else {
            scrollContentView.isHidden = true
            bottomView.isHidden = true
            return
        }
        
        let device = deviceList[currentIndex]
        let modelid = Int(device.modelId ?? 0)
        
        currentDevice = device
        scrollContentView.isHidden = false
        bottomView.isHidden = false
        
        deviceName.text = device.ModelName ?? ""
        
        switch modelid {
        case C_LOG, C_LOGPLUS, C_GRA, C_CEN:
            autoSyncView.alpha = 1
            updateDCView.isHidden = true
            serialNoLb.text = "Serial Number".localized + ": \(device.SerialNo ?? "")"
        default:
            autoSyncView.alpha = 0
            updateDCView.isHidden = false
            serialNoLb.text = String(format: "Serial Number".localized + ": %05d", device.SerialNo?.toInt() ?? 0)
        }
        
        var versionText = "Firmware Version".localized + ": \(device.Firmware ?? "")"
        if let lcd = device.LCDFirmware, !lcd.isEmpty {
            versionText += ".\(lcd)"
        }
        versionLb.text = versionText
        
        //syncedLb.text = "Synced".localized + ": " + (device.LastSync ?? "")
        
        let rawLastSync = device.LastSync ?? "" // Giá trị: "04/22/26 09:54AM"

        if !rawLastSync.isEmpty {
            // 1. Lấy cài đặt định dạng Ngày từ User
            let dateFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.dateFormatIdentify) ?? 0
            let datePattern = (dateFormatId == 0) ? "dd.MM.yy" : "MM.dd.yy"

            // 2. Lấy cài đặt định dạng Giờ từ User (0: 24h, 1: 12h)
            let timeFormatId: Int = AppSettings.shared.get(forKey: AppSettings.Keys.timeFormatIdentify) ?? 0
            let timePattern = (timeFormatId == 0) ? "hh:mma" : "HH:mm"

            // Kết hợp lại thành định dạng hiển thị cuối cùng
            let finalDisplayPattern = "\(datePattern) \(timePattern)"

            // 3. Định nghĩa chính xác format đang lưu trong DB để máy có thể parse được
            let oldDbFormat = "MM/dd/yy hh:mma"

            // 4. Thực hiện chuyển đổi
            let formattedSync = Utilities.convertDateFormat(
                from: rawLastSync,
                fromFormat: oldDbFormat,
                toFormat: finalDisplayPattern
            )

            syncedLb.text = "Synced".localized + ": " + formattedSync
        } else {
            syncedLb.text = "Synced".localized + ": ---"
        }
        
        
        if let deviceIdentify = device.Identity, let autosyncDeviceIdentify:String = AppSettings.shared.get(forKey: AppSettings.Keys.autosyncDeviceIdentify), deviceIdentify == autosyncDeviceIdentify {
            autosyncSwitch.isOn = true
        }
        
        // Stats
        
        // Lấy giá trị ra, nếu nil thì mặc định là "0" hoặc chuỗi rỗng
        let totalDivesStr = device.StatsLogTotalDives ?? "0"
        let totalSecondsStr = device.StatsTotalDiveSecond ?? "0"
        let maxDepthStr = device.StatsMaxDepthFT ?? "0"
        let avgDepthStr = device.StatsAvgDepthFT ?? "0"
        let minTempStr = device.StatsMinTemperatureF ?? "0"
        let altLevelStr = device.StatsMaxAltitudeLevel ?? "0"

        let totalDivesInt = totalDivesStr.toInt()

        statsTotalDivesValueLb.text = "---"
        statsTotalDiveTimeValueLb.text = "---"
        statsMdepthValueLb.text = "---"
        statsAvgDepthValueLb.text = "---"
        statsMinTempValueLb.text = "---"
        statsAltLevelValueLb.text = "---"
        
        // Kiểm tra nếu chưa có dive nào thì hiển thị "---"
        if totalDivesInt > 0 {
            // Xử lý hiển thị bình thường
            statsTotalDivesValueLb.text = "\(totalDivesInt)"
            statsTotalDiveTimeValueLb.text = Utilities.formatSecondsToHMS(totalSecondsStr.toInt())
            
            let unitOfDive = device.Units?.toInt()
            let isMetric = (unitOfDive == M)
            let unitString = isMetric ? "M" : "FT"
            let tempUnitString = isMetric ? "°C" : "°F"
            
            var mdepth: String
            var avgDepth: String
            var minTemp: String
            
            if isMetric {
                mdepth = formatNumber(converFeet2Meter(maxDepthStr.toDouble()))
                avgDepth = formatNumber(converFeet2Meter(avgDepthStr.toDouble()))
                minTemp = formatNumber(convertF2C(minTempStr.toDouble()))
            } else {
                mdepth = formatNumber(maxDepthStr.toDouble(), decimalIfNeeded: 0)
                avgDepth = formatNumber(avgDepthStr.toDouble(), decimalIfNeeded: 0)
                minTemp = formatNumber(minTempStr.toDouble(), decimalIfNeeded: 0)
            }
            
            statsMdepthValueLb.text = "\(mdepth) \(unitString)"
            statsAvgDepthValueLb.text = "\(avgDepth) \(unitString)"
            statsMinTempValueLb.text = "\(minTemp) \(tempUnitString)"
            
            switch modelid {
            case C_LOG, C_LOGPLUS, C_GRA, C_CEN:
                statsAltLevelValueLb.text = "SEA".localized
                statsAltLevelValueLb.alpha = 0
            default:
                statsAltLevelValueLb.alpha = 1
                let level = altLevelStr.toInt()
                statsAltLevelValueLb.text = (level == 0) ? "SEA" : "LEV\(level)"
            }
        }
        
        updateButtonVisibility()
    }
    
    // 1️⃣ Subscribe relay 1 lần duy nhất
    private func subscribeScannedDevices() {
        BluetoothDeviceCoordinator.shared.scannedDevices
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] peripherals in
                guard let self = self else { return }
                
                if let matchedDevice = peripherals.first(where: { $0.peripheral.name == self.currentDevice?.Identity }) {
                    PrintLog("Peripheral found: \(matchedDevice.peripheral.name ?? "")")
                    
                    // Update UI tự động khi thiết bị advertise hoặc scan lại
                    //self.updateDeviceStateUI()
                }
            })
            .disposed(by: disposeBag)
    }
    
    // 2️⃣ Cập nhật trạng thái Connected/Disconnected
    private func updateDeviceStateUI() {
        /*
        if let activeManager = BluetoothDeviceCoordinator.shared.activeDataManager,
           activeManager.SerialNo == currentDevice.SerialNo?.toInt(),
           activeManager.ModelID == currentDevice.modelId ?? 0,
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
        */
    }
    
    @IBAction func nextTapped(_ sender: Any) {
        guard currentIndex < deviceCount - 1 else { return }
        currentIndex += 1
        scrollToIndex(currentIndex)
    }

    @IBAction func prevTapped(_ sender: Any) {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        scrollToIndex(currentIndex)
    }

    private func scrollToIndex(_ index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        deviceCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
    private func updateButtonVisibility() {
        prevBtn.isHidden = (currentIndex == 0)
        nextBtn.isHidden = (currentIndex >= deviceCount - 1)
    }
    
    // Tách thành hàm tiện dụng để xóa dữ liệu DB và update autosync
    private func deleteDeviceData() {
        guard let device = currentDevice else {
            PrintLog("⚠️ No current device to delete.")
            return
        }
        
        // Nếu device này đang là autosync → remove key
        if let targetIdentity: String = AppSettings.shared.get(forKey: AppSettings.Keys.autosyncDeviceIdentify),
           targetIdentity == device.Identity {
            AppSettings.shared.remove(forKey: AppSettings.Keys.autosyncDeviceIdentify)
        }
        
        // Xóa dữ liệu liên quan
        DatabaseManager.shared.deleteRows(from: "DeviceGasMixesSettings", where: "DeviceID=?", arguments: [device.deviceId])
        DatabaseManager.shared.deleteRows(from: "DeviceSettings", where: "DeviceID=?", arguments: [device.deviceId])
        DatabaseManager.shared.deleteRows(from: "Devices", where: "DeviceID=?", arguments: [device.deviceId])
        
        self.navigationController?.popViewController(animated: true)
    }
    
    func connectToDevice(completion: @escaping (Result<BluetoothDataManager, Error>) -> Void) {
        guard let device = currentDevice else {
            PrintLog("⚠️ No current device to connectToDevice.")
            return
        }
        
        // Tìm thiết bị trong relay
        let peripherals = BluetoothDeviceCoordinator.shared.scannedDevices.value
        guard let matchedDevice = peripherals.first(where: { $0.advertisementData.localName == device.Identity }) else {
            PrintLog("Device not found in scannedDevices yet")
            showAlert(on: self, title: "Device not found!".localized, message: "Ensure that your Device is ON and Bluetooth is opened.".localized)
            completion(.failure(NSError(domain: "DeviceNotFound".localized, code: -1, userInfo: nil)))
            return
        }
        
        searchType = .kSetting
        syncType = .kConnectOnly
        
        BluetoothDeviceCoordinator.shared.delegate = self
        
        // Connect
        BluetoothDeviceCoordinator.shared
            .connect(to: matchedDevice, discover: true)
            .timeout(.seconds(25), scheduler: MainScheduler.instance)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] session in
                guard self != nil else { return }
                
                // Set ModelID nếu cần
                if case let .normalSession(manager) = session {
                    // Set ModelID nếu cần
                    if let (bleName, _) = matchedDevice.splitDeviceName(),
                       let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                        manager.ModelID = dcInfo[2].toInt()
                    }
                    
                    manager.readAllSettings() {
                        //self.updateDeviceStateUI()
                        completion(.success(manager))
                    }
                }
                
            }, onError: { error in
                ProgressHUD.dismiss()
                
                // --- ĐÂY LÀ PHẦN KIỂM TRA TIMEOUT ---
                if let rxError = error as? RxError, case .timeout = rxError {
                    BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: "Connection Failed".localized)
                }
                else if case BluetoothError.peripheralDisconnected = error {
                    PrintLog("ℹ️ Peripheral disconnected (user requested)")
                } else {
                    if case BluetoothError.peripheralDisconnected = error, BluetoothDeviceCoordinator.shared.isExpectedDisconnect {
                        PrintLog("ℹ️ Peripheral disconnected (expected)")
                        BluetoothDeviceCoordinator.shared.isExpectedDisconnect = false
                    } else {
                        PrintLog("❌ Connect error: \(error.localizedDescription)")
                        BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: error.localizedDescription)
                    }
                }
                
                completion(.failure(error))
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Actions
    @IBAction func connectTapped(_ sender: Any) {
        guard let device = currentDevice else {
            PrintLog("⚠️ No current device to connect.")
            return
        }
        
        BluetoothDeviceCoordinator.shared.delegate = self
        
        if let activeManager = BluetoothDeviceCoordinator.shared.activeDataManager,
           activeManager.SerialNo == device.SerialNo?.toInt(),
           activeManager.ModelID == device.modelId ?? 0,
           activeManager.scannedPeripheral.peripheral.peripheral.state == .connected {
            // Disconnect
            BluetoothDeviceCoordinator.shared.disconnect()
            
            // Reset
            //self.disposeBag = DisposeBag()
            //self.updateDeviceStateUI()
            
        } else {
            // Tìm thiết bị trong relay
            let peripherals = BluetoothDeviceCoordinator.shared.scannedDevices.value
            guard let matchedDevice = peripherals.first(where: { $0.advertisementData.localName == device.Identity }) else {
                PrintLog("Device not found in scannedDevices yet")
                showAlert(on: self, title: "Device not found!".localized, message: "Ensure that your Device is ON and Bluetooth is opened.".localized)
                return
            }
            
            searchType = .kSetting
            syncType = .kConnectOnly
            
            // Connect
            BluetoothDeviceCoordinator.shared
                .connect(to: matchedDevice, discover: true)
                .observe(on: MainScheduler.instance)
                .subscribe(onNext: { [weak self] session in
                    guard self != nil else { return }
                    
                    //ProgressHUD.dismiss()
                    
                    if case let .normalSession(manager) = session {
                        
                        //ProgressHUD.dismiss()
                        
                        // Set ModelID nếu cần
                        if let (bleName, _) = matchedDevice.splitDeviceName(),
                           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                            manager.ModelID = dcInfo[2].toInt()
                        }
                        
                        manager.readAllSettings()
                        
                        //self.updateDeviceStateUI()
                    }
                    
                }, onError: { error in
                    ProgressHUD.dismiss()
                    if case BluetoothError.peripheralDisconnected = error, BluetoothDeviceCoordinator.shared.isExpectedDisconnect {
                        PrintLog("ℹ️ Peripheral disconnected (expected)")
                        BluetoothDeviceCoordinator.shared.isExpectedDisconnect = false
                    } else {
                        PrintLog("❌ Connect error: \(error.localizedDescription)")
                        BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: error.localizedDescription)
                    }
                })
                .disposed(by: disposeBag)
        }
    }
    
    @IBAction func downloadTapped(_ sender: Any) {
        guard let device = currentDevice else {
            PrintLog("⚠️ No current device to downloadTapped.")
            return
        }
        
        searchType = .kAddDive
        syncType = .kDownloadDiveData
        
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
                    
                }, onError: { error in
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
    
    @IBAction func checkFirmwareTapped(_ sender: Any) {
        guard let device = currentDevice else {
            PrintLog("⚠️ No current device to checkFirmwareTapped.")
            return
        }
        
        connectToDevice { result in
            switch result {
            case .success(let dataManager):
                let currentFw = dataManager.firmwareRev
                let msg = "Looking new firmware\nCurrent".localized + ": v \(currentFw)"
                DialogViewController.showLoading(title: "Firmware Update".localized, message: msg, task:  {_ in
                    
                    let group = DispatchGroup()
                    var iniContent: String?
                    var readmeContent: String?
                    
                    // .ini
                    group.enter()
                    FirmwareAPI.fetchText(from: FirmwareURLBuilder.iniFile(modelId: Int(device.modelId ?? 0))) { text in
                        iniContent = text
                        //iniContent = "1.0.93|10.10.25|CRESSI|DAVINCI|"
                        group.leave()
                    }
                    
                    // .Readme
                    group.enter()
                    FirmwareAPI.fetchText(from: FirmwareURLBuilder.readmeFile(modelId: Int(device.modelId ?? 0))) { text in
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
                                        fwVC.onDisagree = {
                                            BluetoothDeviceCoordinator.shared.disconnect()
                                            //self.updateDeviceStateUI()
                                        }
                                        self.present(fwVC, animated: true)
                                    } else {
                                        DialogViewController.showMessage(title: "Firmware Update".localized, message: "Your dive computer firmware is up to date!".localized)
                                        
                                        BluetoothDeviceCoordinator.shared.disconnect()
                                        //self.updateDeviceStateUI()
                                    }
                                }
                            } else {
                                DialogViewController.showMessage(title: "Firmware Update".localized, message: "Firmware file not found on server.".localized)
                                
                                BluetoothDeviceCoordinator.shared.disconnect()
                            }
                        }
                    }
                })
            case .failure(let error):
                print("❌ Error: \(error.localizedDescription)")
                
                BluetoothDeviceCoordinator.shared.disconnect()
                //self.updateDeviceStateUI()
            }
        }
    }
    
    @IBAction func gotoDeviceSettings(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Device", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "DeviceSettingViewController") as! DeviceSettingViewController
        vc.device = currentDevice
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func removeTapped(_ sender: Any) {
        guard let device = currentDevice else {
            PrintLog("⚠️ No current device to removeTapped.")
            return
        }
        
        PrivacyAlert.showMessage(message: "Are you sure to want to delete this device?".localized, allowTitle: "OK".localized, denyTitle: "Cancel".localized.uppercased()) { action in
            switch action {
            case .allow:
                
                if let activeManager = BluetoothDeviceCoordinator.shared.activeDataManager,
                   activeManager.SerialNo == device.SerialNo?.toInt(),
                   activeManager.ModelID == device.modelId ?? 0,
                   activeManager.scannedPeripheral.peripheral.peripheral.state == .connected {
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
        guard let device = currentDevice else {
            PrintLog("⚠️ No current device to autoSyncSwitched.")
            return
        }
        
        guard let sw = sender as? UISwitch else { return }
        let isOn = sw.isOn
        if isOn {
            AppSettings.shared.set(device.Identity, forKey: AppSettings.Keys.autosyncDeviceIdentify)
        } else {
            AppSettings.shared.remove(forKey: AppSettings.Keys.autosyncDeviceIdentify)
        }
        /*
        if isOn {
            // Alert
            PrivacyAlert.showMessage(message: "Enabling this option allows the app to automatically connect and retrieve all dive logs each time it is launched.".localized, allowTitle: "ENABLED".localized, denyTitle: "CLOSE".localized) { action in
                if  action == .deny {
                    self.autosyncSwitch.isOn = false
                } else {
                    print("ENABLED")
                    AppSettings.shared.set(device.Identity, forKey: AppSettings.Keys.autosyncDeviceIdentify)
                }
            }
        } else {
            AppSettings.shared.remove(forKey: AppSettings.Keys.autosyncDeviceIdentify)
        }
        */
    }
}

extension DeviceViewController: BluetoothDeviceCoordinatorDelegate {
    func didConnectToDevice(message: String?) {
        guard currentDevice != nil else {
            PrintLog("⚠️ No current device to didConnectToDevice.")
            return
        }
        
        if let msg = message {
            if syncType != .kConnectOnly {
                if  syncType == .kRedownloadSetting {
                    showAlert(on: self, message: msg, okHandler: {
                        /*
                        guard let deviceIdentity = device.Identity else {return}
                        
                        guard let dv = DatabaseManager.shared.fetchDevices(nameKeys: [deviceIdentity])?.first else {return}
                        
                        self.currentDevice = dv
                        
                        self.setupUI()
                        */
                        
                        self.loadDevices()
                        
                    })
                } else {
                    showAlert(on: self, message: msg)
                    
                    guard let device = deviceList?[safe: currentIndex] else { return }
                    let modelId = Int(device.modelId ?? 0)

                    if syncType == .kDownloadDiveData {
                        switch modelId {
                        case C_LOG, C_LOGPLUS, C_GRA, C_CEN:
                            // Đảm bảo chạy trên Main Thread để cập nhật UI ngay lập tức
                            DispatchQueue.main.async {
                                self.loadDevices()
                                PrintLog("✅ Data refreshed for model: \(modelId)")
                            }
                        default:
                            // Các model khác có thể cũng cần refresh nếu chúng có Stats?
                            // Nếu tất cả các model đều cần cập nhật sau khi tải dive,
                            // bạn có thể bỏ switch và gọi loadDevices() luôn.
                            break
                        }
                    }
                    
                }
            } else {
                showAlert(on: self, message: msg)
            }
        }
        
        //updateDeviceStateUI()
    }
}

extension DeviceViewController {
    private func downloadFirmwareProcess(latestVersion: String) {
        guard let device = currentDevice else {
            PrintLog("⚠️ No current device to downloadFirmwareProcess.")
            return
        }
        
        DialogViewController.showProcess(
            title: "Firmware Update".localized,
            message: "Downloading firmware v".localized + " \(latestVersion)",
            task: { alertVC in
                
                let ver = latestVersion.replacingOccurrences(of: ".", with: "_")
                guard let url = URL(string: FirmwareURLBuilder.binFile(modelId: Int(device.modelId ?? 0), version: ver)) else {
                    DialogViewController.finish(success: false)
                    return
                }
                
                // 🧭 Bước 1: kiểm tra file tồn tại trước khi tải
                self.checkFileExists(at: url) { exists in
                    if exists {
                        // ✅ Chỉ chạy tiếp download nếu file tồn tại
                        DispatchQueue.main.async {
                            PrintLog("✅ Firmware file exists, start downloading: \(url)")
                            
                            // Toàn bộ đoạn tạo session + task ở đây
                            self.startFirmwareDownload(from: url, alertVC: alertVC)
                        }
                    } else {
                        // ❌ File không tồn tại
                        DispatchQueue.main.async {
                            DialogViewController.dismissAlert {
                                BluetoothDeviceCoordinator.shared.disconnect()
                                DialogViewController.showMessage(title: "Firmware Update".localized, message: "❌ Firmware file not found on server.".localized)
                            }
                        }
                        // Dừng hẳn ở đây, KHÔNG chạy tiếp
                        return
                    }
                }
            }
        )
    }
    
    private func startFirmwareDownload(from url: URL, alertVC: DialogViewController) {
        PrintLog("✅ URL firmware from server: \(url)")
        
        let delegate = DownloadDelegate()
        self.firmwareDownloadDelegate = delegate
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        self.firmwareDownloadSession = session
        
        let task = session.downloadTask(with: url)
        
        delegate.onProgress = { progress in
            DispatchQueue.main.async {
                DialogViewController.updateProgress(progress)
            }
        }
        
        delegate.onFinish = { [weak self] success, fileURL in
            DispatchQueue.main.async {
                DialogViewController.dismissAlert {
                    guard let self = self else { return }
                    if success {
                        PrintLog("✅ Saved firmware: \(fileURL?.path ?? "nil")")
                        if let fileUrl = fileURL {
                            self.doUpdateFirmware(fileUrl: fileUrl)
                        }
                    } else {
                        DialogViewController.showMessage(title: "Firmware Update".localized, message: "❌ Download failed".localized) {
                            BluetoothDeviceCoordinator.shared.disconnect()
                        }
                    }
                    // cleanup
                    self.firmwareDownloadDelegate = nil
                    self.firmwareDownloadSession?.invalidateAndCancel()
                    self.firmwareDownloadSession = nil
                }
            }
        }
        
        task.resume()
        
        alertVC.cancelTask = { [weak self] in
            BluetoothDeviceCoordinator.shared.disconnect()
            task.cancel()
            self?.firmwareDownloadDelegate = nil
            self?.firmwareDownloadSession?.invalidateAndCancel()
            self?.firmwareDownloadSession = nil
        }
    }
    
    private func checkFileExists(at url: URL, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10 // tránh treo lâu
        
        let task = URLSession.shared.dataTask(with: request) { (_, response, error) in
            if let error = error {
                print("❌ ERROR: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Không nhận được HTTP response hợp lệ")
                completion(false)
                return
            }
            
            print("🔍 HTTP Status: \(httpResponse.statusCode)")
            completion(httpResponse.statusCode == 200)
        }
        
        task.resume()
    }
    
    private func doUpdateFirmware(fileUrl: URL) {
        BluetoothDeviceCoordinator.shared.delegate = self
        if let deviceConnected = BluetoothDeviceCoordinator.shared.activeDataManager {
            
            syncType = .kUpdateFirmware
            
            deviceConnected.updateFirmware()
                .subscribe(onNext: { success in
                    print("✅ Reboot command sent: \(success)")
                    
                }, onError: { error in
                    print("❌ Failed: \(error)")
                })
                .disposed(by: disposeBag)
        }
    }
}

extension DeviceViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return deviceCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoItemCell", for: indexPath) as! PhotoItemCell
        let dv = deviceList?[indexPath.row]
        cell.imageView.image = UIImage(named: "\(dv?.modelId ?? 0)") ?? UIImage(named: "8682")
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        currentIndex = Int(scrollView.contentOffset.x / deviceCollectionView.frame.size.width)
        setupUI()
    }
}

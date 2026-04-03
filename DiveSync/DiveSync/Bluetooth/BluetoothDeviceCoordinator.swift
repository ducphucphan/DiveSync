//
//  BluetoothDeviceCoordinator.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 8/29/25.
//

import Foundation
import RxBluetoothKit
import RxSwift
import RxRelay
import CoreBluetooth
import ProgressHUD

// MARK: - Scan mode
enum ScanMode {
    case knownOnly       // chỉ hiển thị (và có thể auto-connect/sync) thiết bị đã có trong DB
    case unknownOnly     // chỉ hiển thị thiết bị chưa có trong DB
    case all             // hiển thị tất cả
}

enum ConnectedDeviceType {
    case normal
    case cr // CR-1, CR-4, CR-5 (3 device làm riêng từ app Dive Story)
    case cr5
}

enum ConnectedSession {
    case normalSession(BluetoothDataManager)
    case crSession(BluetoothDeviceCRManager)
    case cr5Session(BluetoothDeviceCR5Manager)
}

protocol BluetoothDeviceCoordinatorDelegate: AnyObject {
    func didConnectToDevice(message: String?)
}

final class BluetoothDeviceCoordinator {
    static let shared = BluetoothDeviceCoordinator()
    private init() {
        central = CentralManager(queue: .main)
        observeCentralState()
        startContinuousScan()
    }
    
    weak var delegate: BluetoothDeviceCoordinatorDelegate?
    
    // BLE core
    var central: CentralManager
    private var disposeBag = DisposeBag()
    private var scanningDisposable: Disposable?
    private var connectionDisposable: Disposable?
    
    // Public states
    private(set) var connectedPeripheral: Peripheral?
    private(set) var activeDataManager: BluetoothDataManager?
    
    private(set) var crDeviceManager: BluetoothDeviceCRManager?
    
    private(set) var cr5DeviceManager: BluetoothDeviceCR5Manager?
    
    private var didAutoSyncOnce = false
    private var isManualSyncing = false
    
    private var deviceOtaAddress: String? //00:80:E1:27:5B:6D
    
    let scannedDevices = BehaviorRelay<[ScannedPeripheral]>(value: [])
    
    var isExpectedDisconnect = false
        
    private func detectDeviceType(peripheral: Peripheral) -> ConnectedDeviceType {
        
        if let (bleName, _) = peripheral.peripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            let ModelID = dcInfo[2].toInt()
            switch ModelID {
            case C_LOG, C_LOGPLUS:
                return .cr
            case C_CEN, C_GRA:
                return .cr5
            default:
                return .normal
            }
        }
        
        return .normal
    }
    
    // MARK: - Observe BLE state
    private func observeCentralState() {
        central.observeState()
            .subscribe(onNext: { state in
                PrintLog("📡 BLE State: \(state.rawValue)")
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Continuous scan + auto-connect
    private func startContinuousScan() {
        central.observeState()
            .startWith(central.state)
            .filter { $0 == .poweredOn }
            .take(1)
            .subscribe(onNext: { [weak self] _ in
                self?.scanLoop()
            })
            .disposed(by: disposeBag)
    }
    
    private func scanLoop() {
        guard scanningDisposable == nil else { return } // scan only once
        
        scanningDisposable = central.scanForPeripherals(withServices: nil)
            .filter { scanned in
                //print("\(scanned.peripheral.name) - \(scanned.advertisementData.localName)")
                guard let name = scanned.advertisementData.localName else { return false }
                
                let matched = BLEConstants.BLEDeviceNames.list.contains { name.hasPrefix($0) }
                if matched { PrintLog("🔎 Scanned: \(name) - \(scanned.peripheral.name ?? "Unknown")") }
                return matched
            }
            .scan([ScannedPeripheral]()) { current, new in
                
                PrintLog("🟦 current: \(current.map { $0.advertisementData.localName ?? $0.peripheral.name ?? "Unknown" })")
                PrintLog("🟨 new: \(new.advertisementData.localName ?? new.peripheral.name ?? "Unknown")")
                
                var arr = current
                if !arr.contains(where: { $0.peripheral.identifier == new.peripheral.identifier }) {
                    arr.append(new)
                    PrintLog("✅ appended \(new.peripheral.identifier)")
                } else {
                    PrintLog("⏩ already exists \(new.peripheral.identifier)")
                }
                return arr
            }
            .distinctUntilChanged { lhs, rhs in
                let lhsIDs = lhs.map { $0.peripheral.identifier }
                let rhsIDs = rhs.map { $0.peripheral.identifier }
                
                PrintLog("🔄 distinctUntilChanged check:")
                PrintLog("lhs: \(lhsIDs)")
                PrintLog("rhs: \(rhsIDs)")
                
                return lhsIDs == rhsIDs
            }
            .do(onNext: { [weak self] list in
                self?.scannedDevices.accept(list)
            })
            .subscribe(onNext: { [weak self] devices in
                guard let self = self else { return }
                
                if syncType == .kUpdateFirmware {
                    let otaDevice = devices.first { $0.advertisementData.deviceType == .wbOtaBoard }
                    if let otaDevice = otaDevice {
                        otaDevice.peripheral.isOta = true
                        //self.updatingDeviceUUID = otaDevice.peripheral.identifier
                        self.connectToUpdateFirmware(from: otaDevice)
                    }
                }
                if syncType == .kRedownloadSetting {
                    self.tryReconnectAfterUpdatingDevice(from: devices)
                } else {
                    // Trường hợp app restart trong khi đang OTA
                    if let otaDevice = devices.first(where: { $0.advertisementData.deviceType == .wbOtaBoard }) {
                        if Utilities.firstBinFile() != nil {
                            otaDevice.peripheral.isOta = true
                            self.connectToUpdateFirmware(from: otaDevice)
                            return
                        }
                    }
                    
                    // Nếu không phải OTA thì auto connect bình thường
                    self.tryAutoConnectKnown(from: devices)
                }
            })
    }
    
    private func stopScan() {
        scanningDisposable?.dispose()
        scanningDisposable = nil
        PrintLog("🛑 Stop scan")
    }
    
    private func resetScan() {
        scanningDisposable?.dispose()
        scanningDisposable = nil
        scannedDevices.accept([]) // clear danh sách cũ nếu cần
        scanLoop()
        PrintLog("🔄 Reset scan loop")
    }
    
    private func resumeScanIfNeeded() {
        guard scanningDisposable == nil else { return }
        scanLoop()   // 🔄 tiếp tục scan mà không reset danh sách cũ
        PrintLog("▶️ Resume scan")
    }
    
    private func connectToUpdateFirmware(from device: ScannedPeripheral) {
        connect2OtaDevice(
            to: device,
            discover: true,
            characteristics: [BLEConstants.OTA.notification, BLEConstants.OTA.controlAddress, BLEConstants.OTA.rawData]
        )
        .observe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] manager in
            print("connectToUpdateFirmware DONE")
            
            manager.updateFirmware()
                .subscribe(onNext: { success in
                    print("updateFirmware DONE: \(success)")
                    if success {
                        //self?.disconnect()   // huỷ connection hiện tại
                        self?.resetScan()    // bắt đầu scan lại
                        
                        // Re-download setting
                        syncType = .kRedownloadSetting
                    }
                })
                .disposed(by: self?.disposeBag ?? DisposeBag()) // ✅ giữ subscription
        }, onError: { error in
            print("connectToUpdateFirmware ERROR: \(error)")
        })
        .disposed(by: disposeBag) // ✅ giữ subscription bên ngoài
    }
    
    private func tryAutoConnectKnown(from devices: [ScannedPeripheral]) {
        guard crDeviceManager == nil else {
            PrintLog("⛔ Skip autosync: CR device active")
            return
        }
        
        guard !didAutoSyncOnce,
              !isManualSyncing,
              connectedPeripheral == nil,
              let first = devices.first else { return }
        
        let knownDevices = DatabaseManager.shared.fetchDevices() ?? []
        guard
            let (_, serial) = first.peripheral.peripheral.splitDeviceName(),
            let deviceRow = knownDevices.first(where: { $0.SerialNo == serial })
        else { return }
        
        // Chỉ auto-connect nếu là autosync device
        guard let targetIdentity:String = AppSettings.shared.get(forKey: AppSettings.Keys.autosyncDeviceIdentify),
              targetIdentity == deviceRow.Identity else {
            PrintLog("⚠️ Skip auto-sync: \(deviceRow.Identity ?? "nil") không phải autosyncDeviceIdentify")
            return
        }
        
        if syncType == .kUpdateFirmware || syncType == .kRedownloadSetting { return }
        
        PrintLog("🤖 Auto-connect to known: \(deviceRow.Identity ?? "")")
        
        _ = connect(to: first.peripheral, discover: true)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] session in
                // Auto-sync settings sau khi connect
                
                guard case let .normalSession(manager) = session else {
                    PrintLog("⛔ Skip autosync: CR device")
                    return
                }
                
                searchType = .kAddDive
                syncType = .kDownloadDiveData
                
                manager.readAllSettings()
                
                self?.didAutoSyncOnce = true
            }, onError: { _ in
                ProgressHUD.dismiss()
            })
    }
    
    private func tryReconnectAfterUpdatingDevice(from devices: [ScannedPeripheral]) {
        
        guard crDeviceManager == nil else {
            PrintLog("⛔ Skip autosync: CR device active")
            return
        }
        
        guard syncType == .kRedownloadSetting else { return }
        guard let deviceOtaAddress = deviceOtaAddress else { return }
        
        guard let target = devices.first(where: { device in
            if let currentAddress = device.advertisementData.deviceAddress {
                print("currentAddress = \(currentAddress)")
                print("deviceOtaAddress = \(deviceOtaAddress)")
                return isOtaAddress(normal: currentAddress, ota: deviceOtaAddress)
            }
            return false
        }) else { return }
        
        PrintLog("📥 Re-download setting for: \(target.peripheral.name ?? "")")
        
        // Cai dialog con treo de cho scan lai va reconnect, net khi scan thay se dismiss đi truoc khi connect lai.
        DialogViewController.finish(success: true)
        
        _ = connect(to: target.peripheral, discover: true)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] session in
                
                guard case let .normalSession(manager) = session else {
                    PrintLog("⛔ Skip autosync: CR device")
                    return
                }
                
                manager.readAllSettings()
                self?.deviceOtaAddress = nil
            })
    }
    
    // MARK: - Connect/Disconnect
    func connect(to peripheral: Peripheral,
                 discover: Bool = true,
                 services: [CBUUID] = BLEConstants.SERVICES.list,
                 writeChar: CBUUID = BLEConstants.RWChar.write,
                 readChar: CBUUID = BLEConstants.RWChar.read) -> Observable<ConnectedSession> {
        
        stopScan()   // ⛔ stop scan ngay khi bắt đầu connect
        
        ProgressHUD.animate("Connecting to".localized + " \(peripheral.peripheral.name?.formattedDeviceName() ?? "")...")
        
        connectionDisposable?.dispose()
        connectionDisposable = nil
        
        let connectObs = central.establishConnection(peripheral)
            .do(onNext: { p in PrintLog("✅ Connected: \(p)") },
                onDispose: {
                PrintLog("🔌 Disconnected")
                self.resumeScanIfNeeded()   // 👈 resume scan ngay khi disconnect
            })
            .flatMap { [weak self] connected -> Observable<ConnectedSession> in
                guard let self = self else { return .error(NSError(domain: "BLE", code: -99)) }
                
                self.connectedPeripheral = connected
                
                let deviceType = self.detectDeviceType(peripheral: connected)
                switch deviceType {
                case .normal:
                    let manager = BluetoothDataManager(peripheral: connected)
                    self.activeDataManager = manager
                    
                    guard discover else {
                        ProgressHUD.dismiss()
                        return .just(.normalSession(manager))
                    }
                    
                    return manager
                        .discoverServicesAndCharacteristics(
                            servicesUUID: services,
                            writeCharUUID: writeChar,
                            readCharUUID: readChar
                        )
                        .map {
                            return .normalSession(manager)
                        }
                case .cr:
                    let crManager = BluetoothDeviceCRManager(peripheral: connected)
                    self.crDeviceManager = crManager
                    
                    guard discover else {
                        ProgressHUD.dismiss()
                        return .just(.crSession(crManager))
                    }
                    
                    return crManager
                        .discoverServicesAndCharacteristics(
                            servicesUUID: BLEConstants.SERVICES.logic,
                            writeCharUUID: BLEConstants.RWCharLogic.write,
                            readCharUUID: BLEConstants.RWCharLogic.read
                        )
                        .map {
                            return .crSession(crManager)
                        }
                case .cr5:
                    let cr5Manager = BluetoothDeviceCR5Manager(peripheral: connected)
                    self.cr5DeviceManager = cr5Manager
                    
                    guard discover else {
                        ProgressHUD.dismiss()
                        return .just(.cr5Session(cr5Manager))
                    }
                    
                    return cr5Manager
                        .discoverServicesAndCharacteristics(
                            servicesUUID: BLEConstants.SERVICES.cr5,
                            indicateCharUUID: BLEConstants.RWCharCR5.indicate,
                            notifyCharUUIDs: [BLEConstants.RWCharCR5.notify1, BLEConstants.RWCharCR5.notify2]
                        )
                        .map {
                            return .cr5Session(cr5Manager)
                        }
                }
            }
            .share(replay: 1, scope: .forever)
        
        connectionDisposable = connectObs.subscribe(onNext: { _ in }, onError: { err in
            ProgressHUD.dismiss()
            PrintLog("❌ Connect error: \(err.localizedDescription)")
        })
        
        return connectObs
    }
    
    func connect2OtaDevice(to device: ScannedPeripheral,
                           discover: Bool = true,
                           services: [CBUUID] = BLEConstants.SERVICES.otaServices,
                           characteristics:[CBUUID]) -> Observable<BluetoothDataManager> {
        
        stopScan()   // ⛔ stop scan ngay khi bắt đầu connect
        
        //ProgressHUD.animate("Connecting to \(peripheral.peripheral.name?.formattedDeviceName() ?? "")...")
        
        connectionDisposable?.dispose()
        connectionDisposable = nil
        
        let connectObs = central.establishConnection(device.peripheral)
            .do(onNext: { p in PrintLog("✅ Connected: \(p)") },
                onDispose: {
                PrintLog("🔌 Disconnected")
                self.resumeScanIfNeeded()   // 👈 resume scan ngay khi disconnect
            })
            .flatMap { [weak self] connected -> Observable<BluetoothDataManager> in
                guard let self = self else { return .error(NSError(domain: "BLE", code: -99)) }
                
                self.connectedPeripheral = connected
                let manager = BluetoothDataManager(peripheral: connected)
                self.activeDataManager = manager
                
                self.deviceOtaAddress = device.advertisementData.deviceAddress
                
                guard discover else {
                    //ProgressHUD.dismiss()
                    return .just(manager)
                }
                return manager
                    .discoverServicesAndCharacteristicsForOTA(servicesUUID: services, characteristics: characteristics)
                    .map { manager }
            }
            .share(replay: 1, scope: .forever)
        
        connectionDisposable = connectObs.subscribe(onNext: { _ in }, onError: { err in
            //ProgressHUD.dismiss()
            PrintLog("❌ Connect error: \(err.localizedDescription)")
        })
        
        return connectObs
    }
    
    
    func disconnect() {
        isExpectedDisconnect = true
        
        connectionDisposable?.dispose()
        connectionDisposable = nil
        
        if let p = connectedPeripheral?.peripheral {
            central.manager.cancelPeripheralConnection(p)
        }
        
        connectedPeripheral = nil
        activeDataManager?.disposeBag = DisposeBag()   // Hủy tất cả subscriptions bên trong manager
        activeDataManager = nil
        PrintLog("♻️ Disposed connection & reset state")
        // Scan vẫn tiếp tục ngầm
    }
    
    // MARK: - UTILITIES
    func isOtaAddress(normal: String, ota: String) -> Bool {
        let normalParts = normal.split(separator: ":")
        let otaParts = ota.split(separator: ":")
        guard normalParts.count == 6, otaParts.count == 6 else { return false }
        
        // So sánh 5 byte đầu
        let prefixNormal = normalParts.prefix(5).joined(separator: ":")
        let prefixOta = otaParts.prefix(5).joined(separator: ":")
        guard prefixNormal == prefixOta else { return false }
        
        // So sánh byte cuối
        if let lastNormal = UInt8(normalParts[5], radix: 16),
           let lastOta = UInt8(otaParts[5], radix: 16) {
            return lastOta == lastNormal &+ 1
        }
        return false
    }
}

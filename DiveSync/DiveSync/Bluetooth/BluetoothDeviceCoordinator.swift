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
    
    private var didAutoSyncOnce = false
    private var isManualSyncing = false
    
    let scannedDevices = BehaviorRelay<[ScannedPeripheral]>(value: [])
    
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
                guard let name = scanned.peripheral.name else { return false }
                let matched = BLEConstants.BLEDeviceNames.list.contains { name.hasPrefix($0) }
                if matched { PrintLog("🔎 Scanned: \(name)") }
                return matched
            }
            .scan([ScannedPeripheral]()) { current, new in
                var arr = current
                if !arr.contains(where: { $0.peripheral.identifier == new.peripheral.identifier }) {
                    arr.append(new)
                }
                return arr
            }
            .distinctUntilChanged { lhs, rhs in
                lhs.map { $0.peripheral.identifier } == rhs.map { $0.peripheral.identifier }
            }
            .do(onNext: { [weak self] list in
                self?.scannedDevices.accept(list)
            })
            .subscribe(onNext: { [weak self] devices in
                guard let self = self else { return }
                self.tryAutoConnectKnown(from: devices)
            })
    }
    
    private func tryAutoConnectKnown(from devices: [ScannedPeripheral]) {
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
        
        PrintLog("🤖 Auto-connect to known: \(deviceRow.Identity ?? "")")
        
        _ = connect(to: first.peripheral, discover: true)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] manager in
                // Auto-sync settings sau khi connect
                
                searchType = .kAddDive
                syncType = .kDownloadDiveData
                
                manager.readAllSettings2()
                
                self?.didAutoSyncOnce = true
            }, onError: { _ in ProgressHUD.dismiss() })
    }
    
    // MARK: - Connect/Disconnect
    func connect(to peripheral: Peripheral,
                 discover: Bool = true,
                 services: [CBUUID] = BLEConstants.SERVICES.list,
                 writeChar: CBUUID = BLEConstants.RWChar.write,
                 readChar: CBUUID = BLEConstants.RWChar.read) -> Observable<BluetoothDataManager> {
        
        ProgressHUD.animate("Connecting to \(peripheral.peripheral.name?.formattedDeviceName() ?? "")...")
        
        connectionDisposable?.dispose()
        connectionDisposable = nil
        
        let connectObs = central.establishConnection(peripheral)
            .do(onNext: { p in PrintLog("✅ Connected: \(p)") },
                onDispose: { PrintLog("🔌 Disconnected") })
            .flatMap { [weak self] connected -> Observable<BluetoothDataManager> in
                guard let self = self else { return .error(NSError(domain: "BLE", code: -99)) }
                
                self.connectedPeripheral = connected
                let manager = BluetoothDataManager(peripheral: connected)
                self.activeDataManager = manager
                
                guard discover else {
                    ProgressHUD.dismiss()
                    return .just(manager)
                }
                return manager
                    .discoverServicesAndCharacteristics(servicesUUID: services, writeCharUUID: writeChar, readCharUUID: readChar)
                    .map { manager }
            }
            .share(replay: 1, scope: .forever)
        
        connectionDisposable = connectObs.subscribe(onNext: { _ in }, onError: { err in
            ProgressHUD.dismiss()
            PrintLog("❌ Connect error: \(err.localizedDescription)")
        })
        
        return connectObs
    }
    
    func disconnect() {
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
}

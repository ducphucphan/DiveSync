//
//  BluetoothManager.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 02/18/25.
//

import Foundation
import RxBluetoothKit
import RxSwift
import CoreBluetooth

class BluetoothManager {
    private let centralManager: CentralManager
    
    private let disposeBag = DisposeBag()
    
    private var scanningDisposable: Disposable?
    
    var activeBluetoothDataManager: BluetoothDataManager!
    
    private var connectionDisposable: Disposable?
    
    init() {
        self.centralManager = CentralManager(queue: .main)
    }
    
    /// Scan bluetooth devices by UUIDs service
    ///
    ///
    func scanForDevices(serviceUUIDs: [CBUUID]? = nil) -> Observable<[ScannedPeripheral]> {
        return Observable.create { observer in
            func startScan() -> Disposable {
                let scanDisposable = self.centralManager
                    .scanForPeripherals(withServices: nil)
                    .filter { scanned in
                        // Lọc theo device name
                        if let name = scanned.peripheral.name {
                            let matched = BLEConstants.BLEDeviceNames.list.contains { name.hasPrefix($0) }
                            if matched {
                                PrintLog("🔎 Scanned: \(name)")
                            }
                            return matched
                        }
                        return false
                    }
                    .scan([]) { (peripherals, newPeripheral) in
                        var uniquePeripherals = peripherals
                        if !uniquePeripherals.contains(where: { $0.peripheral.identifier == newPeripheral.peripheral.identifier }) {
                            let name = newPeripheral.peripheral.name ?? "Unknown"
                            let advertisedServices = newPeripheral.advertisementData.serviceUUIDs ?? []
                            PrintLog("🛰️ Found: \(name), UUIDs: \(advertisedServices)")
                            uniquePeripherals.append(newPeripheral)
                        }
                        return uniquePeripherals
                    }
                    .take(until: Observable<Int>.timer(.seconds(30), scheduler: MainScheduler.instance)) // ⏱ timeout
                    .startWith([])
                    .subscribe(
                        onNext: { peripherals in
                            observer.onNext(peripherals)
                        },
                        onCompleted: {
                            observer.onCompleted()
                        }
                    )
                
                self.scanningDisposable = scanDisposable
                return scanDisposable
            }
            
            // Nếu centralManager đã poweredOn thì scan luôn
            if self.centralManager.state == .poweredOn {
                return startScan()
            } else {
                // Nếu chưa poweredOn thì chờ poweredOn rồi scan
                let stateDisposable = self.centralManager.observeState()
                    .filter { $0 == .poweredOn }
                    .take(1)
                    .flatMapLatest { _ in
                        return self.scanForDevices(serviceUUIDs: serviceUUIDs)
                    }
                    .subscribe(observer)
                
                return stateDisposable
            }
        }
    }
    
    /// Stop scan Bluetooth devices.
    func stopScanning() {
        scanningDisposable?.dispose()
        PrintLog("Stop Scan...")
    }
    
    /// Connect to selected device.
    func connect(to peripheral: Peripheral) -> Observable<BluetoothDataManager> {
        stopScanning() // Stop scan bluetooth devices when device connected.
        
        // Ngắt kết nối cũ nếu có
            connectionDisposable?.dispose()
            connectionDisposable = nil
        
        let connectionObservable = self.centralManager.establishConnection(peripheral)
                .do(onNext: { connectedPeripheral in
                    PrintLog("✅ Connected to: \(connectedPeripheral)")
                }, onDispose: {
                    PrintLog("🔌 Disconnected from device")
                })
                .map { connectedPeripheral in
                    let dataManager = BluetoothDataManager(peripheral: connectedPeripheral)
                    self.activeBluetoothDataManager = dataManager // Giữ tham chiếu
                    return dataManager
                }
            
        return Observable.create { observer in
                let disposable = connectionObservable
                    .subscribe(onNext: { manager in
                        observer.onNext(manager)
                    }, onError: { error in
                        observer.onError(error)
                    }, onCompleted: {
                        observer.onCompleted()
                    })

                self.connectionDisposable = disposable
                return Disposables.create {
                    disposable.dispose()
                }
            }
    }
    
    func disconnect() {
        self.connectionDisposable?.dispose()
        self.connectionDisposable = nil
        self.activeBluetoothDataManager = nil
    }
}

//
//  FirmwareRecoveryManager.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/3/26.
//

import UIKit
import Foundation
import RxSwift
import RxCocoa
import RxBluetoothKit
import CoreBluetooth

final class FirmwareRecoveryManager {
    
    static let shared = FirmwareRecoveryManager()
    
    private init() {}
    
    private let firmwareUpdateManager = FirmwareUpdateManager.shared
    
    private var disposeBag = DisposeBag()
    
    private var hasCheckedRecovery = false
    
    // MARK: - Public
    
    func checkAndHandleRecovery() {
        
        guard !hasCheckedRecovery else {
            return
        }
        
        hasCheckedRecovery = true
        
        BluetoothDeviceCoordinator.shared.scannedDevices
            .map { scannedList in
                scannedList.filter {
                    $0.advertisementData.deviceType == .wbOtaBoard
                }
            }
            .filter { !$0.isEmpty }
            .take(1)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onNext: { [weak self] otaDevices in
                    
                    guard let self = self,
                          let otaDevice = otaDevices.first
                    else {
                        return
                    }
                    
                    self.handleFirmwareRecovery(
                        otaDevice: otaDevice
                    )
                }
            )
            .disposed(by: disposeBag)
    }
    
    // MARK: - Recovery
    
    private func handleFirmwareRecovery(
        otaDevice: ScannedPeripheral
    ) {
        
        DialogViewController.showRetryMessage(
            title: firmwareUpdateManager.getDeviceName(from: otaDevice) ?? "",
            message: "Firmware update was previously failed. Do you want to recover it?".localized,
            cancelButtonTitle: "NO".localized,
            okButtonTitle: "YES".localized,
            onCancel: {
                // User chọn No
            },
            onOK: { [weak self] in
                
                self?.startFirmwareRecovery(
                    device: otaDevice
                )
            }
        )
    }
    
    // MARK: - Start Recovery
    
    func startFirmwareRecovery(
        device: ScannedPeripheral
    ) {
        
        let dcrid = Utilities.getConnectedDeviceDCRID(
            scannedPeripheral: device
        )
        
        device.peripheral.isOta = true
        
        // Không thể xác định được device có serial number nào đang TRY_AGAIN ở OTA mode.
        Utilities.sendFirmwareStatus(device: device, "TRY_AGAIN", serialNo: 0)
        
        if let _ = Utilities.firstBinFile(dcrid: dcrid) {
            
            BluetoothDeviceCoordinator.shared
                .connectToUpdateFirmware(
                    from: device
                )
            
            return
        }
        
        
        PrintLog(
            "⚠️ No local firmware. Download firmware from server."
        )
        
        fetchAndDownloadFirmware(
            device: device
        )
    }
    
    // MARK: - Fetch Firmware
    
    private func fetchAndDownloadFirmware(
        device: ScannedPeripheral
    ) {
        
        let modelId = firmwareUpdateManager.getModelId(
            from: device
        )
        
        DialogViewController.showLoading(
            title: "Firmware Update".localized,
            message: "Looking new firmware".localized,
            task: { [weak self] _ in
                
                guard let self = self else {
                    return
                }
                
                self.firmwareUpdateManager
                    .fetchFirmwareInfo(
                        modelId: modelId
                    ) { result in
                        
                        DispatchQueue.main.async {
                            
                            switch result {
                                
                            case .success(let firmwareInfo):
                                
                                PrintLog(
                                    "✅ Latest firmware: \(firmwareInfo.latestVersion)"
                                )
                                
                                self.downloadFirmware(
                                    device: device,
                                    modelId: firmwareInfo.modelId,
                                    version: firmwareInfo.latestVersion
                                )
                                
                            case .failure(let error):
                                DialogViewController.dismissAlert {
                                    BluetoothDeviceCoordinator.shared
                                        .disconnect()
                                    
                                    DialogViewController.showMessage(
                                        title: "Firmware Update".localized,
                                        message: error.localizedDescription
                                    )
                                }
                            }
                        }
                    }
            }
        )
    }
    
    // MARK: - Download
    
    private func downloadFirmware(
        device: ScannedPeripheral,
        modelId: Int,
        version: String
    ) {
        
        DialogViewController.showProcess(
            title: "Firmware Update".localized,
            message: "Downloading firmware v".localized
                + " \(version)",
            task: { [weak self] alertVC in
                
                guard let self = self else {
                    return
                }
                
                self.firmwareUpdateManager
                    .downloadFirmware(
                        modelId: modelId,
                        version: version,
                        progress: { progress in
                            
                            DialogViewController.updateProgress(
                                Float(progress)
                            )
                        },
                        completion: { [weak self] result in
                            
                            guard let self = self else {
                                return
                            }
                            
                            DispatchQueue.main.async {
                                
                                switch result {
                                    
                                case .success(let fileURL):
                                    
                                    PrintLog(
                                        "✅ Download completed: \(fileURL.path)"
                                    )
                                    
                                    self.connectToFirmwareUpdate(
                                        device: device
                                    )
                                    
                                case .failure(let error):
                                    
                                    DialogViewController.dismissAlert {
                                        
                                        BluetoothDeviceCoordinator.shared
                                            .disconnect()
                                        
                                        DialogViewController.showMessage(
                                            title: "Firmware Update".localized,
                                            message: error.localizedDescription
                                        )
                                    }
                                }
                            }
                        }
                    )
                
                // Cancel thực sự download
                alertVC.cancelTask = { [weak self] in
                    
                    self?.firmwareUpdateManager
                        .cancelDownload()
                    
                    BluetoothDeviceCoordinator.shared
                        .disconnect()
                }
            }
        )
    }
    
    // MARK: - Connect OTA
    
    private func connectToFirmwareUpdate(
        device: ScannedPeripheral
    ) {
        
        PrintLog(
            "🔌 Firmware downloaded. Connecting to OTA..."
        )
        
        BluetoothDeviceCoordinator.shared
            .connectToUpdateFirmware(
                from: device
            )
    }
}

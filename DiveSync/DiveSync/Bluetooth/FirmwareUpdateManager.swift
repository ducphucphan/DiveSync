//
//  FirmwareUpdateManager.swift
//  DiveSync
//

import Foundation
import RxSwift
import RxCocoa
import RxBluetoothKit
import CoreBluetooth

final class FirmwareUpdateManager {

    static let shared = FirmwareUpdateManager()

    private init() {}

    // MARK: - Download

    private var firmwareDownloadSession: URLSession?
    private var firmwareDownloadDelegate: DownloadDelegate?

    private var disposeBag = DisposeBag()

    // MARK: - OTA Connection

    /// Connect tới OTA device và discover các OTA characteristics.
    func connectToOTA(
        device: ScannedPeripheral
    ) -> Observable<Void> {

        device.peripheral.isOta = true

        return BluetoothDeviceCoordinator.shared
            .connect2OtaDevice(
                to: device,
                discover: true,
                characteristics: [
                    BLEConstants.OTA.notification,
                    BLEConstants.OTA.controlAddress,
                    BLEConstants.OTA.rawData
                ]
            )
            .map { _ in () }
    }

    // MARK: - Firmware Information

    /// Lấy modelId từ device.
    func getModelId(
        from device: ScannedPeripheral
    ) -> Int {

        var modelId = 123

        if let (bleName, _) = device.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {

            modelId = dcInfo[2].toInt()
        }

        return modelId
    }

    /// Láy device name từ device
    func getDeviceName(
        from device: ScannedPeripheral?
    ) -> String? {

        var deviceName: String? = nil

        if let device = device, let (bleName, _) = device.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {

            deviceName = dcInfo[1]
        }

        return deviceName
    }
    
    /// Download .ini và .readme từ server.
    ///
    /// Không hiển thị UI ở đây.
    func fetchFirmwareInfo(
        modelId: Int,
        completion: @escaping (
            Result<FirmwareInfo, Error>
        ) -> Void
    ) {

        let group = DispatchGroup()

        var iniContent: String?
        var readmeContent: String?

        group.enter()

        FirmwareAPI.fetchText(
            from: FirmwareURLBuilder.iniFile(modelId: modelId)
        ) { text in

            iniContent = text
            group.leave()
        }

        group.enter()

        FirmwareAPI.fetchText(
            from: FirmwareURLBuilder.readmeFile(modelId: modelId)
        ) { text in

            readmeContent = text
            group.leave()
        }

        group.notify(queue: .main) {

            guard
                let ini = iniContent,
                let readme = readmeContent
            else {

                completion(
                    .failure(
                        FirmwareUpdateError.firmwareInfoNotFound
                    )
                )

                return
            }

            let parts = ini.components(separatedBy: "|")

            guard
                let latestVersion = parts.first,
                !latestVersion.isEmpty
            else {

                completion(
                    .failure(
                        FirmwareUpdateError.versionNotFound
                    )
                )

                return
            }

            completion(
                .success(
                    FirmwareInfo(
                        modelId: modelId,
                        iniContent: ini,
                        readmeContent: readme,
                        latestVersion: latestVersion
                    )
                )
            )
        }
    }

    // MARK: - Download Firmware

    func downloadFirmware(
        modelId: Int,
        version: String,
        progress: @escaping (Double) -> Void,
        completion: @escaping (
            Result<URL, Error>
        ) -> Void
    ) {

        AppSettings.shared.set(
            version,
            forKey: AppSettings.Keys.currentFrwUpdateVersion
        )

        let ver = version.replacingOccurrences(
            of: ".",
            with: "_"
        )

        guard let url = URL(
            string: FirmwareURLBuilder.binFile(
                modelId: modelId,
                version: ver
            )
        ) else {

            completion(
                .failure(
                    FirmwareUpdateError.invalidFirmwareURL
                )
            )

            return
        }

        checkFileExists(at: url) { [weak self] exists in

            guard let self = self else { return }

            guard exists else {

                DispatchQueue.main.async {

                    completion(
                        .failure(
                            FirmwareUpdateError.firmwareFileNotFound
                        )
                    )
                }

                return
            }

            self.startFirmwareDownload(
                from: url,
                progress: progress,
                completion: completion
            )
        }
    }

    // MARK: - Check Server File

    private func checkFileExists(
        at url: URL,
        completion: @escaping (Bool) -> Void
    ) {

        var request = URLRequest(url: url)

        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(
            with: request
        ) { _, response, error in

            if let error = error {

                PrintLog(
                    "❌ Firmware HEAD error: \(error.localizedDescription)"
                )

                completion(false)
                return
            }

            guard let httpResponse =
                    response as? HTTPURLResponse
            else {

                PrintLog("❌ Invalid HTTP response")

                completion(false)
                return
            }

            PrintLog(
                "🔍 Firmware HTTP Status: \(httpResponse.statusCode)"
            )

            completion(
                httpResponse.statusCode == 200
            )
        }

        task.resume()
    }

    // MARK: - Download Task

    private func startFirmwareDownload(
        from url: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (
            Result<URL, Error>
        ) -> Void
    ) {

        PrintLog(
            "📦 Download firmware: \(url)"
        )

        let delegate = DownloadDelegate()

        self.firmwareDownloadDelegate = delegate

        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )

        self.firmwareDownloadSession = session

        let task = session.downloadTask(
            with: url
        )

        delegate.onProgress = { value in

            DispatchQueue.main.async {
                progress(Double(value))
            }
        }

        delegate.onFinish = { [weak self] success, fileURL in

            guard let self = self else { return }

            DispatchQueue.main.async {

                self.firmwareDownloadDelegate = nil

                self.firmwareDownloadSession?
                    .invalidateAndCancel()

                self.firmwareDownloadSession = nil

                if success, let fileURL = fileURL {

                    PrintLog(
                        "✅ Firmware downloaded: \(fileURL.path)"
                    )

                    completion(
                        .success(fileURL)
                    )

                } else {

                    completion(
                        .failure(
                            FirmwareUpdateError.downloadFailed
                        )
                    )
                }
            }
        }

        task.resume()
    }

    // MARK: - Update Firmware

    func updateFirmware(
        completion: @escaping (
            Result<Bool, Error>
        ) -> Void
    ) {

        guard let device =
                BluetoothDeviceCoordinator.shared.activeDataManager
        else {

            completion(
                .failure(
                    FirmwareUpdateError.deviceNotConnected
                )
            )

            return
        }

        syncType = .kUpdateFirmware

        Utilities.sendFirmwareStatus(device: device.scannedPeripheral, "TRY_AGAIN", serialNo: device.SerialNo)
        
        device.updateFirmware()
            .observe(on: MainScheduler.instance)
            .subscribe(
                onNext: { success in

                    PrintLog(
                        "✅ Reboot command sent: \(success)"
                    )

                    Utilities.sendFirmwareStatus(device: device.scannedPeripheral, "COMPLETED", serialNo: device.SerialNo)

                    BluetoothDeviceCoordinator.shared
                        .isExpectedDisconnect = true

                    completion(
                        .success(success)
                    )
                },
                onError: { error in

                    PrintLog(
                        "❌ Firmware update failed: \(error)"
                    )
                    
                    Utilities.sendFirmwareStatus(device: device.scannedPeripheral, "ERROR", serialNo: device.SerialNo)

                    completion(
                        .failure(error)
                    )
                }
            )
            .disposed(by: disposeBag)
    }

    // MARK: - Cancel

    func cancelDownload() {

        firmwareDownloadDelegate = nil

        firmwareDownloadSession?
            .invalidateAndCancel()

        firmwareDownloadSession = nil
    }
}

// MARK: - Models

struct FirmwareInfo {

    let modelId: Int
    let iniContent: String
    let readmeContent: String
    let latestVersion: String
}

// MARK: - Errors

enum FirmwareUpdateError: LocalizedError {

    case firmwareInfoNotFound
    case versionNotFound
    case invalidFirmwareURL
    case firmwareFileNotFound
    case downloadFailed
    case deviceNotConnected

    var errorDescription: String? {

        switch self {

        case .firmwareInfoNotFound:
            return "Firmware information not found on server."

        case .versionNotFound:
            return "Firmware version not found."

        case .invalidFirmwareURL:
            return "Invalid firmware URL."

        case .firmwareFileNotFound:
            return "Firmware file not found on server."

        case .downloadFailed:
            return "Firmware download failed."

        case .deviceNotConnected:
            return "Device is not connected."
        }
    }
}

//
//  BluetoothDataManager.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 2/27/25.
//

import Foundation
import RxBluetoothKit
import RxSwift
import CoreBluetooth
import ProgressHUD

struct Constants {
    static let PKT_SIZE     = 135
    static let PKT_SIZE_250 = 250
    static let BLOCK_SIZE   = 256
    
    static let HEADER_PAKET_LEN = 5
    
    static let HEX_DATA = 0
    static let HEX_EOF  = 1
}

struct cmd {
    static let GetDeviceModel: UInt16       = 0x0010
    static let GetDeviceSerial: UInt16      = 0x0012
    static let GetDeviceFw: UInt16          = 0x0014
    static let GetDeviceBleName: UInt16     = 0x0016
    
    static let GetFirmwareLCD: UInt16       = 0x0018
    
    static let GetUserName: UInt16          = 0x0300
    static let GetUserSurName: UInt16       = 0x0302
    static let GetUserPhone: UInt16         = 0x0304
    static let GetUser: UInt16              = 0x0300
    static let GetUserEmail: UInt16         = 0x0306
    static let GetUserBlood: UInt16         = 0x0308
    static let GetUserEmName: UInt16        = 0x030A
    static let GetUserEmSurName: UInt16     = 0x030C
    static let GetUserEmPhone: UInt16       = 0x030E
    
    static let GetSystemSettings: UInt16    = 0x0100
    
    static let GetScubaSettings: UInt16     = 0x0400
    
    static let GetLastLogID: UInt16         = 0x0600
    static let GetLog: UInt16               = 0x0601
    static let GetLogStatistics: UInt16     = 0x0602
    static let StartProfileDownload: UInt16 = 0x0610
    static let GetProfileSample: UInt16     = 0x0611
    static let GetProfileSamples: UInt16    = 0x0612
    
    static let SetSystemSettings: UInt16    = 0x0101
    static let SetScubaSettings: UInt16     = 0x0401
    static let SetUserName: UInt16          = 0x0301
    static let SetUserSurName: UInt16       = 0x0303
    static let SetUserPhone: UInt16         = 0x0305
    static let SetUserEmail: UInt16         = 0x0307
    static let SetUserBlood: UInt16         = 0x0309
    static let SetUserEmName: UInt16        = 0x030B
    static let SetUserEmSurName: UInt16     = 0x030D
    static let SetUserEmPhone: UInt16       = 0x030F
    
    static let SetGMTTime: UInt16           = 0x0050
    
}

struct DeviceDataSettings {
    var serialNo: Int?
    var firmwareRev: String?
    var firmwareRevLCD: String?
    var bleName: String?
    var userInfo: String?
    var systemSettings: SystemSettings?
    var scubaSettings: ScubaSettings?
    var statisticsData: Data?
}

struct DiveRecord {
    let diveNo: Int
    let logData: Data       // raw log data (if needed for parsing later)
    let profiles: [Data]     // list of 32-byte raw sample blocks
}

class BluetoothDataManager {
    let peripheral: Peripheral
    
    var disposeBag = DisposeBag()
    
    var notifyDisposable: Disposable?
    
    private var writeCharacteristic: Characteristic?
    private var readCharacteristic: Characteristic?
    private var otaCharacteristic: Characteristic?
    
    private var otaControlCharacteristic: Characteristic?
    private var otaRawDataCharacteristic: Characteristic?
    private var otaNotificationCharacteristic: Characteristic?
    
    var firmwareRev = ""
    
    var SerialNo = 0
    var ModelID = 0
    
    var lastLogID: UInt8 = 0x00
    
    var totalSampleCount = 0
    var completedSampleCount = 0
        
    init(peripheral: Peripheral) {
        self.peripheral = peripheral
    }
    
    /// Discover services and characteristics needed for communication
    func discoverServicesAndCharacteristics(servicesUUID: [CBUUID], writeCharUUID: CBUUID, readCharUUID: CBUUID) -> Observable<Void> {
        return peripheral.discoverServices(servicesUUID)
            .asObservable() // Chuyển đổi Single thành Observable
            .flatMap { services -> Observable<[Characteristic]> in
                PrintLog("🔍 Discovered services:")
                services.forEach { PrintLog("→ \($0.uuid.uuidString)") }
                
                guard let service = services.first else {
                    return Observable.error(NSError(domain: "Bluetooth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service not found"]))
                }
                return service.discoverCharacteristics([
                    writeCharUUID,
                    readCharUUID,
                    BLEConstants.OTA.reboot
                ]).asObservable()
            }
            .do(onNext: { [weak self] characteristics in
                PrintLog("✅ Discovered characteristics:")
                characteristics.forEach { PrintLog("→ \($0.uuid.uuidString)") }
                
                self?.writeCharacteristic = characteristics.first { $0.uuid == writeCharUUID }
                self?.readCharacteristic = characteristics.first { $0.uuid == readCharUUID }
                self?.otaCharacteristic = characteristics.first { $0.uuid == BLEConstants.OTA.reboot}
                
            })
            .map { _ in ()} // Đảm bảo trả về Observable<Void>
    }
    
    func discoverServicesAndCharacteristicsForOTA(servicesUUID: [CBUUID], characteristics:[CBUUID]) -> Observable<Void> {
        return peripheral.discoverServices(servicesUUID)
            .asObservable() // Chuyển đổi Single thành Observable
            .flatMap { services -> Observable<[Characteristic]> in
                PrintLog("🔍 Discovered services:")
                services.forEach { PrintLog("→ \($0.uuid.uuidString)") }
                
                guard let service = services.first else {
                    return Observable.error(NSError(domain: "Bluetooth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service not found"]))
                }
                return service.discoverCharacteristics(characteristics).asObservable()
            }
            .do(onNext: { [weak self] characteristics in
                PrintLog("✅ Discovered characteristics:")
                characteristics.forEach { PrintLog("→ \($0.uuid.uuidString)") }
                
                self?.otaControlCharacteristic = characteristics.first { $0.uuid == BLEConstants.OTA.controlAddress }
                self?.otaRawDataCharacteristic = characteristics.first { $0.uuid == BLEConstants.OTA.rawData }
                self?.otaNotificationCharacteristic = characteristics.first { $0.uuid == BLEConstants.OTA.notification}
                
                if let notificationChar = self?.otaNotificationCharacteristic {
                    notificationChar.observeValueUpdateAndSetNotification()
                        .subscribe(onNext: { characteristic in
                            if let value = characteristic.value {
                                PrintLog("🔔 OTA Notify value: \(value.hexString)")
                            }
                        }, onError: { error in
                            PrintLog("❌ Enable OTA notification failed: \(error)")
                        })
                        .disposed(by: self?.disposeBag ?? DisposeBag())
                }
                
            })
            .map { _ in ()} // Đảm bảo trả về Observable<Void>
    }
    
    func waitForResponse() -> Observable<Data?> {
        guard let readChar = readCharacteristic else {
            return Observable.error(NSError(domain: "Bluetooth", code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "Read characteristic not found"]))
        }
        
        return readChar.readValue() // <- không phải observeValueUpdate
            .asObservable()
            .compactMap { $0.value }
    }
    
    private func writeDataDone(_ data: Data) throws -> Bool {
        let bytes = [UInt8](data)
        
        if bytes.count == 3 && bytes[0] == 0xFF && bytes[1] == 0xEE && bytes[2] == 0xDD {
            throw NSError(domain: "Bluetooth", code: -9999, userInfo: [NSLocalizedDescriptionKey: "System not ready (FF EE DD)"])
        }
        
        guard bytes.count >= 6 else {
            throw NSError(domain: "Bluetooth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Response too short"])
        }
        
        let statusByte = bytes[4]
        
        if statusByte == 0x06 {
            return true
        } else {
            // Lấy mã lỗi từ byte tiếp theo (bytes[5])
            if bytes.count > 5 {
                let errorCode = bytes[5]
                let error = DCResponseError.from(code: errorCode)
                throw NSError(
                    domain: "Bluetooth",
                    code: Int(errorCode),
                    userInfo: [NSLocalizedDescriptionKey: error.description]
                )
            } else {
                throw NSError(
                    domain: "Bluetooth",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Missing error code byte after status"]
                )
            }
        }
    }
    
    private func parseResponse(_ data: Data) throws -> Data? {
        let bytes = [UInt8](data)
        
        if bytes.count == 3 && bytes[0] == 0xFF && bytes[1] == 0xEE && bytes[2] == 0xDD {
            throw NSError(domain: "Bluetooth", code: -9999, userInfo: [NSLocalizedDescriptionKey: "System not ready (FF EE DD)"])
        }
        
        guard bytes.count >= 6 else {
            throw NSError(domain: "Bluetooth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Response too short"])
        }
        
        let statusByte = bytes[4]
        
        if statusByte == 0x06 {
            // ✅ OK → lấy frame length từ byte 2 và 3
            let frameLen = (Int(bytes[2]) << 8) | Int(bytes[3])
            let headerLen = 5 // 5 bytes header
            let crcLen = 2 // 2 bytes crc
            let payloadEnd = frameLen - crcLen
            
            // Đảm bảo có đủ bytes cho payload + CRC (2 bytes cuối)
            guard bytes.count >= payloadEnd + 2 else {
                throw NSError(domain: "Bluetooth", code: -5, userInfo: [NSLocalizedDescriptionKey: "Payload too short or missing CRC"])
            }
            
            return Data(bytes[headerLen..<payloadEnd])
        } else {
            // Lấy mã lỗi từ byte tiếp theo (bytes[5])
            
            let errorCode = bytes[5]
            
            if errorCode == 0x06 {
                // ✅ Trường hợp bạn muốn coi như "không có payload"
                return nil
            }
            
            if bytes.count > 5 {
                
                // Lấy 2 byte đầu
                let cmdValue: UInt16 = data.prefix(2).withUnsafeBytes { ptr in
                    // Giả sử little-endian
                    return ptr.load(as: UInt16.self).bigEndian
                }
                
                // Kiểm tra
                var cmdString = ""
                
                switch cmdValue {
                case cmd.GetDeviceModel:
                    cmdString = "GetDeviceModel \(String(format: "0x%04X", cmdValue))"
                case cmd.GetDeviceSerial:
                    cmdString = "GetDeviceSerial \(String(format: "0x%04X", cmdValue))"
                case cmd.GetDeviceFw:
                    cmdString = "GetDeviceFw \(String(format: "0x%04X", cmdValue))"
                case cmd.GetDeviceBleName:
                    cmdString = "GetDeviceBleName \(String(format: "0x%04X", cmdValue))"
                case cmd.GetFirmwareLCD:
                    cmdString = "GetFirmwareLCD \(String(format: "0x%04X", cmdValue))"
                case cmd.GetUserName:
                    cmdString = "GetUserName \(String(format: "0x%04X", cmdValue))"
                case cmd.GetSystemSettings:
                    cmdString = "GetSystemSettings \(String(format: "0x%04X", cmdValue))"
                case cmd.GetScubaSettings:
                    cmdString = "GetScubaSettings \(String(format: "0x%04X", cmdValue))"
                case cmd.GetLastLogID:
                    cmdString = "GetLastLogID \(String(format: "0x%04X", cmdValue))"
                case cmd.GetLog:
                    cmdString = "GetLog \(data.hexString), LastLogID: \(lastLogID)"
                case cmd.GetLogStatistics:
                    cmdString = "GetLogStatistics \(String(format: "0x%04X", cmdValue))"
                case cmd.StartProfileDownload:
                    cmdString = "StartProfileDownload \(String(format: "0x%04X", cmdValue))"
                case cmd.GetProfileSample:
                    cmdString = "GetProfileSample \(String(format: "0x%04X", cmdValue))"
                case cmd.GetProfileSamples:
                    cmdString = "GetProfileSamples \(String(format: "0x%04X", cmdValue))"
                default:
                    cmdString = "Unknown command: \(String(format: "0x%04X", cmdValue))"
                }
                
                let error = DCResponseError.from(code: errorCode)
                throw NSError(
                    domain: "Bluetooth",
                    code: Int(errorCode),
                    userInfo: [NSLocalizedDescriptionKey: error.description + "\n\(cmdString)"]
                )
            } else {
                throw NSError(
                    domain: "Bluetooth",
                    code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Missing error code byte after status"]
                )
            }
        }
    }
    
    private func cmdData(for command: UInt16) -> Data {
        var pkbuf: [UInt8] = [0, 0, 0x00, 0x06, 0, 0]
        pkbuf[0] = UInt8((command >> 8) & 0xFF)
        pkbuf[1] = UInt8(command & 0xFF)
        return Data(pkbuf)
    }
    
    private func cmdData(for command: UInt16, payload: Data) -> Data {
        var packet = Data()
        
        // Add command (big endian)
        packet.append(UInt8((command >> 8) & 0xFF))
        packet.append(UInt8(command & 0xFF))
        
        // Calculate total length: 2 bytes command + 2 bytes length + payload + 2 bytes CRC
        let totalLength = 2 + 2 + payload.count + 2
        packet.append(UInt8((totalLength >> 8) & 0xFF)) // Length MSB
        packet.append(UInt8(totalLength & 0xFF))        // Length LSB
        
        // Add payload
        packet.append(payload)
        
        // 2 byte checksum, được tính lại khi send command.
        packet.append(UInt8(0))
        packet.append(UInt8(0))
        
        return packet
    }
    
    /// Send data to the device
    func sendCommand(_ data: Data) -> Observable<Void> {
        guard let characteristic = writeCharacteristic else {
            return Observable.error(NSError(domain: "Bluetooth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Write characteristic not found"]))
        }
        
        // Chuyển Data thành mảng UInt8
        var pkbuf = [UInt8](data)
        
        if pkbuf.count > 2 {
            let CRC16Val = CRC16(buf: data, len: data.count - 2)
            pkbuf[data.count - 2] = UInt8(CRC16Val / 256)
            pkbuf[data.count - 1] = UInt8(CRC16Val % 256)
        }
        
        // Chuyển lại thành Data
        let cmdData = Data(pkbuf)
        
        PrintLog("SEND COMMAND: \(cmdData.hexString)")
        
        return peripheral.writeValue(cmdData, for: characteristic, type: .withoutResponse)
            .asObservable()
            .map { _ in return () } // Chuyển đổi Observable<Characteristic> thành Observable<Void>
    }
    
    /// Send a command and wait for a response
    func sendCommandWithResponse(_ data: Data) -> Observable<Data?> {
        return sendCommand(data)
        //.delay(.milliseconds(50), scheduler: MainScheduler.instance)
            .flatMapLatest { _ in
                self.waitForResponse()
            }
            .map { response in
                guard let response = response else {
                    throw NSError(domain: "Bluetooth", code: -999, userInfo: [NSLocalizedDescriptionKey: "No response data"])
                }
                
                PrintLog("ResponseCount: \(response.count) - \(response.hexString)")
                
                return try self.parseResponse(response)
            }
            .retry { errors in
                errors.enumerated().flatMap { attempt, error -> Observable<Void> in
                    if let nsError = error as NSError?, nsError.code == -9999, attempt < 3 {
                        PrintLog("🔁 Retry due to FF EE DD (attempt \(attempt + 1))")
                        return Observable.just(())
                            .delay(.milliseconds(100), scheduler: MainScheduler.instance)
                    } else {
                        return Observable.error(error)
                    }
                }
            }
    }
    
    func sendCommandWithBoolResponse(_ data: Data) -> Observable<Bool> {
        return sendCommand(data)
            .delay(.milliseconds(50), scheduler: MainScheduler.instance)
            .flatMapLatest { _ in
                self.waitForResponse()
            }
            .map { response in
                guard let response = response else {
                    throw NSError(domain: "Bluetooth", code: -999, userInfo: [NSLocalizedDescriptionKey: "No response data"])
                }
                
                PrintLog("ResponseCount: \(response.count) - \(response.hexString)")
                
                return try self.writeDataDone(response)
            }
            .retry { errors in
                errors.enumerated().flatMap { attempt, error -> Observable<Void> in
                    if let nsError = error as NSError?, nsError.code == -9999, attempt < 3 {
                        PrintLog("🔁 Retry due to FF EE DD (attempt \(attempt + 1))")
                        return Observable.just(())
                            .delay(.milliseconds(100), scheduler: MainScheduler.instance)
                    } else {
                        return Observable.error(error)
                    }
                }
            }
    }
    
    // MARK: - UPDATE FIRMWARE
    func sendRebootOta(fileURL: URL) -> Observable<Bool> {
        let sector = getSectorToDelete()
        let nSector = getNSectorToDelete(fileURL: fileURL)
        let data = [REBOOT_OTA_MODE, UInt8(sector & 0xFF), UInt8(nSector & 0xFF)]
        
        guard let characteristic = otaCharacteristic else {
            return Observable.error(NSError(domain: "Bluetooth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Write OTA characteristic not found"]))
        }
        
        print("\(Data(data).hexString) - \(characteristic.uuid)")
        
        return peripheral.writeValue(Data(data),
                                     for: characteristic,
                                     type: .withoutResponse)
        .asObservable()
        .map { _ in true } // Chuyển đổi Observable<Characteristic> thành Observable<Void>
    }
    
    func sendFirmware(fileURL: URL, progress: @escaping (Double) -> Void) -> Observable<Bool> {
        // 0. Kiểm tra characteristic
        guard let controlChar = otaControlCharacteristic,
              let dataChar = otaRawDataCharacteristic else {
            return Observable.error(
                NSError(domain: "Bluetooth",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "OTA characteristic not found"])
            )
        }
        
        // 1. Đọc file
        guard let fileData = try? Data(contentsOf: fileURL) else {
            return Observable.error(
                NSError(domain: "Bluetooth",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot read firmware file"])
            )
        }
        
        // bạn có thể set theo MTU: peripheral.maximumWriteValueLength(for: .withoutResponse)
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
        print("MTU Size: %i", mtu)
        let fileSize = fileData.count
        let chunkSize = mtu
        let chunks: [Data] = stride(from: 0, to: fileSize, by: chunkSize).map {
            fileData.subdata(in: $0 ..< min($0 + chunkSize, fileSize))
        }
        let totalChunks = chunks.count
        
        // nếu không có chunk (file rỗng) -> trả true luôn
        if totalChunks == 0 {
            return Observable.just(false)
        }
        
        // 2. Tạo startCommand (theo code bạn có)
        guard let startCommand = Data.startUpload(type: .application(board: .wb55),
                                                  fileLength: fileSize) else {
            return Observable.error(
                NSError(domain: "Bluetooth",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot create start command"])
            )
        }
        
        // 3. Tạo Observable thủ công, thực hiện start rồi gửi chunk tuần tự
        return Observable.create { [weak self] observer in
            guard let self = self else {
                observer.onError(NSError(domain: "Bluetooth", code: -999, userInfo: nil))
                return Disposables.create()
            }
            
            let composite = CompositeDisposable()
            
            // 3.1 Gửi startCommand (Single)
            let startDisp = self.peripheral
                .writeValue(startCommand, for: controlChar, type: .withoutResponse)
                .subscribe(onSuccess: { _ in
                    // khi start thành công -> bắt đầu gửi chunk tuần tự
                    func sendChunk(at index: Int) {
                        // nếu đã dispose thì dừng
                        if composite.isDisposed { return }
                        
                        if index >= totalChunks {
                            // 🔚 Hết chunks -> gửi finishCommand
                            let finishCommand = Data.uploadFinished()
                            let d = self.peripheral
                                .writeValue(finishCommand, for: controlChar, type: .withoutResponse)
                                .subscribe(onSuccess: { _ in
                                    observer.onNext(true)
                                    observer.onCompleted()
                                }, onFailure: { error in
                                    observer.onError(error)
                                    composite.dispose()
                                })
                            _ = composite.insert(d)
                            return
                        }
                        
                        // gửi chunk[index]
                        let chunk = chunks[index]
                        let d = self.peripheral
                            .writeValue(chunk, for: dataChar, type: .withoutResponse)
                            .subscribe(onSuccess: { _ in
                                // update progress trên main thread
                                let p = Double(index + 1) / Double(totalChunks)
                                DispatchQueue.main.async {
                                    progress(p)
                                }
                                // gửi tiếp
                                sendChunk(at: index + 1)
                            }, onFailure: { error in
                                // nếu lỗi khi gửi chunk -> gửi lỗi ra observer và huỷ luôn
                                observer.onError(error)
                                composite.dispose()
                            })
                        
                        // thêm disposable của writeValue vào composite để quản lý hủy
                        _ = composite.insert(d)
                    }
                    
                    // start gửi chunk từ 0
                    sendChunk(at: 0)
                    
                }, onFailure: { error in
                    // lỗi khi gửi start command
                    observer.onError(error)
                })
            
            // thêm start disposable vào composite
            _ = composite.insert(startDisp)
            
            // khi outer subscriber dispose -> dispose composite (hủy mọi write)
            return Disposables.create {
                composite.dispose()
            }
        }
    }
    
    func updateFirmware() -> Observable<Bool> {
        guard let fwrUrl = Utilities.firstBinFile() else {
            return Observable.just(false)
        }
        
        let subject = PublishSubject<Bool>()
        
        if self.peripheral.isOta {
            DialogViewController.showProcess(title: "Firmware Update", message: "Uploading firmware", hideCancel: true, task: {_ in
                    self.sendFirmware(fileURL: fwrUrl) { progress in
                        DialogViewController.updateProgress(Float(progress))
                    }
                    .subscribe(onNext: { success in
                        subject.onNext(success)
                        subject.onCompleted()
                        //DialogViewController.finish(success: success)
                    }, onError: { error in
                        subject.onNext(false)
                        subject.onCompleted()
                        DialogViewController.finish(success: false)
                    })
                    .disposed(by: self.disposeBag)
                }
            );
        } else {
            DialogViewController.showLoading(title: "Firmware Update", message: "Uploading firmware", hideCancel: true, task:  {_ in
                self.sendRebootOta(fileURL: fwrUrl)
                    .subscribe(onNext: { success in
                        subject.onNext(success)
                        subject.onCompleted()
                        //DialogViewController.finish(success: success)
                    }, onError: { error in
                        subject.onNext(false)
                        subject.onCompleted()
                        DialogViewController.finish(success: false)
                    })
                    .disposed(by: self.disposeBag)
            });
        }
        
        return subject.asObservable()
    }
    
    // MARK: - GET COMMANDS
    
    func sendGetDeviceSerial() -> Observable<Data?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0x6, 0, 0]
        pkbuf[0] = UInt8((cmd.GetDeviceSerial >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetDeviceSerial & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
    }
    
    func sendGetDeviceFwVersion() -> Observable<Data?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0x6, 0, 0]
        pkbuf[0] = UInt8((cmd.GetDeviceFw >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetDeviceFw & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
    }
    
    func sendGetDeviceBleName() -> Observable<Data?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0x6, 0, 0]
        pkbuf[0] = UInt8((cmd.GetDeviceBleName >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetDeviceBleName & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
    }
    
    func sendGetFirmwareLCD() -> Observable<Data?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0x6, 0, 0]
        pkbuf[0] = UInt8((cmd.GetFirmwareLCD >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetFirmwareLCD & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
    }
    
    func sendGetUserInfo() -> Observable<String> {
        let commands: [UInt16] = [
            cmd.GetUserName,
            cmd.GetUserSurName,
            cmd.GetUserPhone,
            cmd.GetUserEmail,
            cmd.GetUserBlood,
            cmd.GetUserEmName,
            cmd.GetUserEmSurName,
            cmd.GetUserEmPhone
        ]
        
        // Hàm hỗ trợ tạo từng observable một
        let observables = commands.map { command -> Observable<String> in
            let data = self.cmdData(for: command)
            return self.sendCommandWithResponse(data)
                .flatMapLatest { res in
                    return Observable.just(self.extractPayloadString(from: res) ?? "")
                }
        }
        
        // Chuỗi tuần tự
        return observables
            .reduce(Observable.just([String]())) { acc, next in
                acc.flatMapLatest { results in
                    next.map { results + [$0] }
                }
            }
            .map { $0.joined(separator: "|") }
    }
    
    func sendGetSystemSettings() -> Observable<SystemSettings?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0x6, 0, 0]
        pkbuf[0] = UInt8((cmd.GetSystemSettings >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetSystemSettings & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
            .map { payload -> SystemSettings in
                guard let payload = payload else {
                    throw NSError(domain: "Bluetooth", code: -999, userInfo: [NSLocalizedDescriptionKey: "No payload returned"])
                }
                return SystemSettings.from(data: payload)
            }
    }
    
    func sendGetScubaSettings() -> Observable<ScubaSettings?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0x6, 0, 0]
        pkbuf[0] = UInt8((cmd.GetScubaSettings >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetScubaSettings & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
            .map { payload -> ScubaSettings in
                guard let payload = payload else {
                    throw NSError(domain: "Bluetooth", code: -999, userInfo: [NSLocalizedDescriptionKey: "No payload returned"])
                }
                return try ScubaSettings.from(data: payload)
            }
    }
    
    func readAllSettings(completion: (() -> Void)? = nil) {
        
        if syncType == .kDownloadSetting {
            ProgressHUD.animate("Reading device settings...")
        } else if syncType == .kUploadSetting {
            ProgressHUD.animate("Writing device settings...")
        } else if syncType == .kDownloadDiveData {
            ProgressHUD.animate("Downloading dives...")
        }
        
        var settingsResult = DeviceDataSettings()
        
        sendGetDeviceSerial()
            .flatMap { serialData -> Observable<Data?> in
                if let str = self.extractPayloadString(from: serialData) {
                    PrintLog("SerialNo: \(str)")
                    self.SerialNo = str.toInt()
                    settingsResult.serialNo = self.SerialNo
                }
                return self.sendGetDeviceFwVersion()
            }
            .flatMap { fwData -> Observable<Data?> in
                if let str = self.extractFirmwarePayloadString(from: fwData) {
                    PrintLog("Fw Revision: \(str)")
                    self.firmwareRev = str
                    settingsResult.firmwareRev = self.firmwareRev
                }
                return self.sendGetDeviceBleName()
            }
            .flatMap { bleNameData -> Observable<String> in
                if let str = self.extractPayloadString(from: bleNameData) {
                    PrintLog("Device Name: \(str)")
                    settingsResult.bleName = str
                }
                
                if self.ModelID == 0 {
                    if let (bleName, _) = self.peripheral.peripheral.splitDeviceName(),
                       let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                        self.ModelID = dcInfo[2].toInt()
                    }
                }
                if self.ModelID == C_SPI || self.ModelID == C_SKI {
                    PrintLog("Reading LCD firmware info...")
                    // Gọi thêm hàm sendGetFirmwareLCD, sau đó nối kết quả về sendGetUserInfo()
                    return self.sendGetFirmwareLCD()
                        .flatMap { lcdData -> Observable<String> in
                            if let lcdStr = self.extractPayloadString(from: lcdData) {
                                PrintLog("LCD Firmware: \(lcdStr)")
                                settingsResult.firmwareRevLCD = lcdStr
                            }
                            // Sau khi đọc LCD xong, tiếp tục chuỗi bình thường
                            return self.sendGetUserInfo()
                        }
                } else {
                    return self.sendGetUserInfo()
                }
            }
            .flatMap { userInfo -> Observable<Data?> in
                PrintLog("UserInfo: \(userInfo)")
                settingsResult.userInfo = userInfo
                return self.sendGetLogStatistics()
            }
            .flatMap { logStatistics -> Observable<SystemSettings?> in
                PrintLog("Log Statistics: \(String(describing: logStatistics?.hexString))")
                settingsResult.statisticsData = logStatistics
                return self.sendGetSystemSettings()
            }
            .flatMap { systemSetting -> Observable<ScubaSettings?> in
                PrintLog("System Settings: \(String(describing: systemSetting))")
                settingsResult.systemSettings = systemSetting
                return self.sendGetScubaSettings()
            }
            .flatMap { scubaSetting -> Observable<DeviceReadResult> in
                PrintLog("Scuba Settings: \(String(describing: scubaSetting))")
                settingsResult.scubaSettings = scubaSetting
                
                switch syncType {
                case .kUploadSetting:
                    return self.U_WriteSetting(settings: settingsResult)
                        .catch { error in
                            PrintLog("⚠️ Failed to upload settings: \(error.localizedDescription)")
                            return .just(.failure(error: error.localizedDescription))
                        }
                        .flatMap { writeResult in
                            // đọc lại settings sau khi ghi xong
                            return self.readAllSettingsAndSave()
                                .map { _ in writeResult }
                        }
                case .kUploadDateTime:
                    return self.U_SetDateTime(settings: settingsResult)
                default:
                    return self.U_SaveSetting(settings: settingsResult)
                        .flatMap { saveSuccess -> Observable<DeviceReadResult> in
                            if syncType == .kDownloadDiveData && saveSuccess == .success {
                                return self.U_DownloadDives(settings: settingsResult)
                            } else {
                                return .just(saveSuccess)
                            }
                        }
                }
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { result in
                ProgressHUD.dismiss()
                
                guard let m = BluetoothDeviceCoordinator.shared.activeDataManager else { return }
                
                var props: [String: Any] = [:]
                props["ModelID"]   = m.ModelID
                props["SerialNo"]  = m.SerialNo
                props["Identity"]  = m.peripheral.name ?? ""
                props["LastSync"]  = Utilities.getLastSyncText(date: Date())
                props["Firmware"]  = m.firmwareRev
                
                if let lcdFirmwareRev = settingsResult.firmwareRevLCD {
                    props["LCDFirmware"]  = lcdFirmwareRev
                } else {
                    props["LCDFirmware"]  = ""
                }
                
                if let (bleName, _) = self.peripheral.peripheral.splitDeviceName(),
                   let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                    props["Manufacture"] = dcInfo[0]
                    props["ModelName"]   = dcInfo[1]
                }
                
                if let logStatistics = settingsResult.statisticsData, let sysSettings = settingsResult.systemSettings {
                    // Last saved Log Id
                    let LastLogId = self.dataDecrypt(data: logStatistics, startIndex: 0, len: 4)
                    props["StatsLastLogId"] = LastLogId
                    
                    // Total number of dives in Scuba/Gauge.
                    let StatsLogTotalDives = self.dataDecrypt(data: logStatistics, startIndex: 4, len: 4)
                    props["StatsLogTotalDives"] = StatsLogTotalDives
                    
                    // Total seconds of all dives
                    let StatsTotalDiveSecond = self.dataDecrypt(data: logStatistics, startIndex: 8, len: 4)
                    props["StatsTotalDiveSecond"] = StatsTotalDiveSecond
                    
                    // Max Depth of all dives in feets
                    let StatsMaxDepthFT = self.dataDecryptFloat(data: logStatistics, startIndex: 12)
                    props["StatsMaxDepthFT"] = StatsMaxDepthFT
                    
                    // Avg Depth of all dives in feets
                    let StatsAvgDepthFT = self.dataDecryptFloat(data: logStatistics, startIndex: 16)
                    props["StatsAvgDepthFT"] = StatsAvgDepthFT
                    
                    // Minimum temperature of all dives in Fahrenheit
                    let StatsMinTemperatureF = self.dataDecryptFloat(data: logStatistics, startIndex: 20)
                    props["StatsMinTemperatureF"] = StatsMinTemperatureF
                    
                    // Maximum Altitude level of all dives
                    let StatsMaxAltitudeLevel = logStatistics[24]
                    props["StatsMaxAltitudeLevel"] = StatsMaxAltitudeLevel
                    
                    props["Units"] = sysSettings.units.decimalString
                }
                
                var msg = "Your device’s setting are downloaded"
                if result == .noDiveData { msg = "NO NEW LOG TO DOWNLOAD" }
                else {
                    if searchType == .kAddDevice && syncType == .kDownloadSetting {
                        msg = "Your device has been added"
                    } else if syncType == .kUploadSetting {
                        msg = "You device’s setting are updated"
                    } else if syncType == .kDownloadDiveData {
                        msg = "Logs from Dive Computer are downloaded"
                    } else if syncType == .kUploadDateTime {
                        msg = "You device’s Date/Time are updated"
                    } else if syncType == .kRedownloadSetting {
                        msg = "Firmware upgrade success"
                    }
                }
                
                // Lưu DB
                if DatabaseManager.shared.isExistDevice(modelId: m.ModelID, serialNo: m.SerialNo) {
                    let cond = "where ModelID=\(m.ModelID) and SerialNo=\(m.SerialNo)"
                    DatabaseManager.shared.updateTable(tableName: "devices", params: props, conditions: cond)
                } else {
                    _ = DatabaseManager.shared.insertIntoTable(tableName: "devices", params: props)
                }
                
                if syncType == .kConnectOnly {
                    completion?()
                } else {
                    BluetoothDeviceCoordinator.shared.disconnect()
                    BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: msg)
                }
            }, onError: { error in
                ProgressHUD.dismiss()
                
                let msg = error.localizedDescription
                BluetoothDeviceCoordinator.shared.disconnect()
                BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: "❗️\(msg)")
            })
            .disposed(by: disposeBag)
    }
    
    private func readAllSettingsAndSave() -> Observable<DeviceReadResult> {
        PrintLog("#########READ BACK##############")
        
        var newResult = DeviceDataSettings()
         return sendGetDeviceSerial()
             .flatMap { serialData -> Observable<Data?> in
                 if let str = self.extractPayloadString(from: serialData) {
                     PrintLog("SerialNo: \(str)\n")
                     self.SerialNo = str.toInt()
                     newResult.serialNo = self.SerialNo
                 }
                 return self.sendGetDeviceFwVersion()
             }
             .flatMap { fwData -> Observable<Data?> in
                 if let str = self.extractPayloadString(from: fwData) {
                     PrintLog("Fwr Revision: \(str)\n")
                     self.firmwareRev = str
                     newResult.firmwareRev = self.firmwareRev
                 }
                 return self.sendGetDeviceBleName()
             }
             .flatMap { bleNameData -> Observable<String> in
                 if let str = self.extractPayloadString(from: bleNameData) {
                     PrintLog("Device Name: \(str)\n")
                     newResult.bleName = str
                 }
                 
                 if self.ModelID == 0 {
                     if let (bleName, _) = self.peripheral.peripheral.splitDeviceName(),
                        let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                         self.ModelID = dcInfo[2].toInt()
                     }
                 }
                 if self.ModelID == C_SPI || self.ModelID == C_SKI {
                     PrintLog("Reading LCD firmware info...")
                     // Gọi thêm hàm sendGetFirmwareLCD, sau đó nối kết quả về sendGetUserInfo()
                     return self.sendGetFirmwareLCD()
                         .flatMap { lcdData -> Observable<String> in
                             if let lcdStr = self.extractPayloadString(from: lcdData) {
                                 PrintLog("LCD Firmware: \(lcdStr)")
                                 newResult.firmwareRevLCD = lcdStr
                             }
                             // Sau khi đọc LCD xong, tiếp tục chuỗi bình thường
                             return self.sendGetUserInfo()
                         }
                 } else {
                     return self.sendGetUserInfo()
                 }
             }
             .flatMap{ userInfo -> Observable<SystemSettings?> in
                 PrintLog("")
                 PrintLog("UserInfo: \(userInfo)")
                 newResult.userInfo = userInfo
                 return self.sendGetSystemSettings()
             }
             .flatMap{ systemSetting -> Observable<ScubaSettings?> in
                 PrintLog("")
                 PrintLog("System Settings: \(String(describing: systemSetting))")
                 newResult.systemSettings = systemSetting
                 return self.sendGetScubaSettings()
             }
             .flatMap { scubaSettings -> Observable<DeviceReadResult> in
                 newResult.scubaSettings = scubaSettings
                 return self.U_SaveSetting(settings: newResult)
             }
             .catch { error in
                 PrintLog("❌ Error while re-reading settings after upload: \(error.localizedDescription)")
                 return Observable.just(.failure(error: error.localizedDescription))
             }
        /*
        return self.sendGetUserInfo()
            .flatMap { userInfo -> Observable<SystemSettings?> in
                newResult.userInfo = userInfo
                return self.sendGetSystemSettings()
            }
            .flatMap { systemSettings -> Observable<ScubaSettings?> in
                newResult.systemSettings = systemSettings
                return self.sendGetScubaSettings()
            }
            .flatMap { scubaSettings -> Observable<DeviceReadResult> in
                newResult.scubaSettings = scubaSettings
                return self.U_SaveSetting(settings: newResult)
            }
            .catch { error in
                PrintLog("❌ Error while re-reading settings after upload: \(error.localizedDescription)")
                return Observable.just(.failure(error: error.localizedDescription))
            }
        */
    }
    
    func sendGetLastLogID() -> Observable<Data?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0x6, 0, 0]
        pkbuf[0] = UInt8((cmd.GetLastLogID >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetLastLogID & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
    }
    
    func sendGetLog(logId: Int, onSampleDownloaded: (() -> Void)? = nil) -> Observable<DiveRecord?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0xA, 0, 0, 0, 0, 0, 0]
        pkbuf[0] = UInt8((cmd.GetLog >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetLog & 0xFF)
        
        pkbuf[4] = UInt8((logId >> 24) & 0xFF)
        pkbuf[5] = UInt8((logId >> 16) & 0xFF)
        pkbuf[6] = UInt8((logId >> 8) & 0xFF)
        pkbuf[7] = UInt8(logId & 0xFF)
        
        let data = Data(pkbuf)
        PrintLog(data.hexString)
        
        return sendCommandWithResponse(data)
            .flatMap { resData in
                guard let logData = resData else {
                    return Observable<DiveRecord?>.just(nil)
                }
                
                // Kiểm tra xem diveNo đã tồn tại trong database chưa, nếu rồi thì không cần download.
                let diveNo = self.dataDecrypt(data: logData, startIndex: 0, len: 4)
                if DatabaseManager.shared.isExistDiveLog(diveNo: diveNo, modelId: self.ModelID, serialNo: self.SerialNo) {
                    return Observable<DiveRecord?>.just(nil)
                }
                
                return self.sendGetStartProfileDownload(profileId: diveNo)
                    .flatMap { numSampleData in
                        guard let numSampleData = numSampleData, numSampleData.count >= 4 else {
                            PrintLog("⚠️ Không nhận được số sample cho DiveNo: \(diveNo)")
                            return Observable<DiveRecord?>.just(nil)
                        }
                        
                        let numSamples = self.dataDecrypt(data: numSampleData, startIndex: 0, len: 4, dataType: .MBS)
                        PrintLog("🔢 NumOfSamples for DiveNo \(diveNo): \(numSamples)")
                        
                        let sampleRequests = stride(from: 0, to: numSamples, by: 5).map { sampleIndex in
                            PrintLog("Sample Index: \(sampleIndex)")
                            return self.sendGetProfileSamples(profileId: diveNo, sampleNumber: sampleIndex)
                        }
                        
                        // Cộng tổng số sample vào biến toàn cục
                        self.totalSampleCount += sampleRequests.count
                        
                        return Observable
                            .from(sampleRequests)
                            .concatMap { request in
                                request.do(onNext: { _ in
                                    self.completedSampleCount += 1
                                    onSampleDownloaded?()
                                })
                            }
                            .compactMap { $0 }
                            .map { self.splitSamples(from: $0, diveNo: diveNo) } // lọc đúng DiveNo
                            .reduce([], accumulator: +) // gộp tất cả các sample hợp lệ lại
                            .map { validSamples in
                                PrintLog("✅ Nhận được \(validSamples.count) sample hợp lệ cho DiveNo \(diveNo)")
                                return DiveRecord(diveNo: diveNo, logData: logData, profiles: validSamples)
                            }
                            .asObservable()
                    }
            }
    }
    
    
    func sendGetLogStatistics() -> Observable<Data?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0x6, 0, 0]
        pkbuf[0] = UInt8((cmd.GetLogStatistics >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetLogStatistics & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
    }
    
    func sendGetStartProfileDownload(profileId: Int) -> Observable<Data?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0xA, 0, 0, 0, 0, 0, 0]
        pkbuf[0] = UInt8((cmd.StartProfileDownload >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.StartProfileDownload & 0xFF)
        
        pkbuf[4] = UInt8((profileId >> 24) & 0xFF)
        pkbuf[5] = UInt8((profileId >> 16) & 0xFF)
        pkbuf[6] = UInt8((profileId >> 8) & 0xFF)
        pkbuf[7] = UInt8(profileId & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
    }
    
    func sendGetProfileSample(profileId: Int, sampleNumber: Int) -> Observable<Data?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0xE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        pkbuf[0] = UInt8((cmd.GetProfileSample >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetProfileSample & 0xFF)
        
        pkbuf[7] = UInt8(profileId & 0xFF)
        pkbuf[6] = UInt8((profileId >> 8) & 0xFF)
        pkbuf[5] = UInt8((profileId >> 16) & 0xFF)
        pkbuf[4] = UInt8((profileId >> 24) & 0xFF)
        
        pkbuf[11] = UInt8(sampleNumber & 0xFF)
        pkbuf[10] = UInt8((sampleNumber >> 8) & 0xFF)
        pkbuf[9] = UInt8((sampleNumber >> 16) & 0xFF)
        pkbuf[8] = UInt8((sampleNumber >> 24) & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
    }
    
    func sendGetProfileSamples(profileId: Int, sampleNumber: Int) -> Observable<Data?> {
        var pkbuf: [UInt8] = [0, 0, 0x0, 0xE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        pkbuf[0] = UInt8((cmd.GetProfileSamples >> 8) & 0xFF)
        pkbuf[1] = UInt8(cmd.GetProfileSamples & 0xFF)
        
        pkbuf[7] = UInt8(profileId & 0xFF)
        pkbuf[6] = UInt8((profileId >> 8) & 0xFF)
        pkbuf[5] = UInt8((profileId >> 16) & 0xFF)
        pkbuf[4] = UInt8((profileId >> 24) & 0xFF)
        
        pkbuf[11] = UInt8(sampleNumber & 0xFF)
        pkbuf[10] = UInt8((sampleNumber >> 8) & 0xFF)
        pkbuf[9] = UInt8((sampleNumber >> 16) & 0xFF)
        pkbuf[8] = UInt8((sampleNumber >> 24) & 0xFF)
        
        let data = Data(pkbuf)
        return sendCommandWithResponse(data)
    }
    
    // MARK: - SET COMMANDS
    
    func sendSetGMTTime(newDate: String, newTime: String, dateFormat: UInt8, timeFormat: UInt8) -> Observable<Bool> {
        var payload: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
        
        let dateSelected = "\(newDate) \(newTime)"  // giống String.format("%s %s:30")
        
        var dFormat = "dd.MM.yyyy"
        if dateFormat == 1 {
            dFormat = "MM.dd.yyyy"
        }
        
        var tFormat = "HH:mm"
        if timeFormat == 1 {
            tFormat = "hh:mm a"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = String(format: "%@ %@", dFormat, tFormat)
        formatter.locale = Locale.current
        
        guard let date = formatter.date(from: dateSelected) else {
            PrintLog("Lỗi: Không thể parse date")
            return .just(false)
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .second, .minute, .hour, .weekday, .day, .month], from: date)
        
        payload[0] = UInt8(0)
        payload[1] = UInt8(components.minute ?? 0)
        payload[2] = UInt8((components.hour ?? 1)-1)
        payload[3] = UInt8((components.weekday ?? 1) - 1) // 0: Sunday, 6: Saturday
        payload[4] = UInt8(components.day ?? 0)
        payload[5] = UInt8((components.month ?? 0))
        payload[6] = UInt8((components.year ?? 0) & 0xFF)
        payload[7] = UInt8((components.year ?? 0) >> 8 & 0xFF)
        
        // Tạo gói lệnh
        let data = self.cmdData(for: cmd.SetGMTTime, payload: Data(payload))
        return self.sendCommandWithBoolResponse(data)
            .flatMapLatest { ack in
                return Observable.just(ack)
            }
    }
    
    // userInfos dạng: Name|SurName|Phone|Email|Blood|EmName|EmSurName|EmPhone
    func sendSetUserInfo(_ userInfos: String) -> Observable<Bool> {
        
        let userInfoArray = userInfos.uppercased().components(separatedBy: "|")
        let maxByteLimits = [32, 32, 32, 32, 8, 32, 32, 32]
        let payloads: [Data] = zip(userInfoArray, maxByteLimits).map { (string, limit) in
            return trimmedData(from: string, maxBytes: limit)
        }
        
        let commands: [UInt16] = [
            cmd.SetUserName,
            cmd.SetUserSurName,
            cmd.SetUserPhone,
            cmd.SetUserEmail,
            cmd.SetUserBlood,
            cmd.SetUserEmName,
            cmd.SetUserEmSurName,
            cmd.SetUserEmPhone
        ]
        
        // Đảm bảo số lượng khớp
        guard userInfoArray.count == commands.count else {
            PrintLog("⚠️ userInfoArray count không khớp commands count")
            return .just(false)
        }
        
        let observables = zip(commands, payloads).map { (command, info) -> Observable<Bool> in
            // Convert String payload to Data (UTF-8)
            let payloadData = Data(info)
            
            // Tạo gói lệnh
            let data = self.cmdData(for: command, payload: payloadData)
            
            return self.sendCommandWithBoolResponse(data)
                .flatMapLatest { ack in
                    return Observable.just(ack)
                }
        }
        
        return observables
            .reduce(Observable.just([Bool]())) { acc, next in
                acc.flatMapLatest { results in
                    next.map { results + [$0] }
                }
            }
            .map { $0.allSatisfy { $0 } } // ✅ Trả về true nếu tất cả là true
    }
    
    func sendSetSystemSettings(systemSettings: SystemSettings)  -> Observable<Bool> {
        
        // Tạo gói lệnh
        let data = self.cmdData(for: cmd.SetSystemSettings, payload: systemSettings.toData())
        return self.sendCommandWithBoolResponse(data)
            .flatMapLatest { ack in
                return Observable.just(ack)
            }
        
    }
    
    func sendSetScubaSettings(scubaSettings: ScubaSettings)  -> Observable<Bool> {
        
        // Tạo gói lệnh
        let data = self.cmdData(for: cmd.SetScubaSettings, payload: scubaSettings.toData())
        return self.sendCommandWithBoolResponse(data)
            .flatMapLatest { ack in
                return Observable.just(ack)
            }
        
    }
    
    // MARK: - PARSE DATA
    func U_SaveSetting(settings: DeviceDataSettings) -> Observable<DeviceReadResult> {
        
        if let (bleName, _) = peripheral.peripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            self.ModelID = dcInfo[2].toInt()
        }
        
        guard let serialNo = settings.serialNo,
              let userInfo = settings.userInfo,
              let systemSettings = settings.systemSettings,
              let scubaSettings = settings.scubaSettings else {
            return .just(.failure(error: nil))
        }
        
        var dcSettings: [String: Any] = [:]
        var dcGasSettings: [String: Any] = [:]
        
        dcSettings["DeviceID"] = DatabaseManager.shared.lastDevicID(modelId: ModelID, serialNo: serialNo)
        dcSettings["RecordTimeStamp"] = scubaSettings.recordTimeStamp_s.decimalString
        dcSettings["LastStopFt"] = scubaSettings.lastStopFt.decimalString
        dcSettings["LastStopM"] = scubaSettings.lastStopM.decimalString
        dcSettings["GFLow"] = String(scubaSettings.gfLow)
        dcSettings["GFHigh"] = String(scubaSettings.gfHigh)
        dcSettings["SafetyStopMode"] = scubaSettings.safetyStopMode.decimalString
        dcSettings["SafetyStopMin"] = scubaSettings.safetyStopMin.decimalString
        dcSettings["SSDepthFt"] = scubaSettings.ssDepthFt.decimalString
        dcSettings["SSDepthM"] = scubaSettings.ssDepthM.decimalString
        dcSettings["NoDecoAlarmMin"] = scubaSettings.noDecoAlarmMin.decimalString
        dcSettings["OxToxAlarmPercent"] = scubaSettings.oxToxAlarmPercent.decimalString
        dcSettings["DeepStopOn"] = scubaSettings.deepStopOn.decimalString
        dcSettings["DeepStopMin"] = scubaSettings.deepStopMin.decimalString
        dcSettings["DepthAlarmFt"] = scubaSettings.depthAlarmFt.decimalString
        dcSettings["DepthAlarmM"] = scubaSettings.depthAlarmM.decimalString
        dcSettings["DiveTimeAlarmMin"] = scubaSettings.diveTimeAlarmMin.decimalString
        dcSettings["AscentSpeedAlarmFPM"] = scubaSettings.ascentSpeedAlarmFpm.decimalString
        dcSettings["TlbgAlarm"] = scubaSettings.tlbgAlarm.decimalString
        
        dcSettings["TimeFormat"] = systemSettings.timeFormat.decimalString
        dcSettings["DateFormat"] = systemSettings.dateFormat.decimalString
        dcSettings["TimeZoneIdxLocal"] = systemSettings.timeZoneIdxLocal.decimalString
        dcSettings["TimeZoneIdxHome"] = systemSettings.timeZoneIdxHome.decimalString
        dcSettings["Units"] = systemSettings.units.decimalString
        dcSettings["WaterDensity"] = systemSettings.waterDensity.decimalString
        dcSettings["WetContacts"] = systemSettings.wetContacts.decimalString
        dcSettings["DiveMode"] = systemSettings.diveMode.decimalString
        dcSettings["DiveLogSamplingTime"] = systemSettings.diveLogSamplingTime_s.decimalString
        dcSettings["BacklightLevel"] = systemSettings.backlightLevel.decimalString
        dcSettings["BacklightDimLevel"] = systemSettings.backlightDimLevel.decimalString
        dcSettings["BacklightDimTime"] = systemSettings.backlightDimTime_s
        dcSettings["BuzzerMode"] = systemSettings.buzzerMode.decimalString
        dcSettings["EcompassDeclination"] = systemSettings.ecompassDeclination_deg.decimalString
        dcSettings["Language"] = systemSettings.language.decimalString
        
        let info = userInfo.components(separatedBy: "|").map { String($0) }
        if info.count == 8 {
            dcSettings["Name"] = info[0]
            dcSettings["SurName"] = info[1]
            dcSettings["Phone"] = info[2]
            dcSettings["Email"] = info[3]
            dcSettings["Blood"] = info[4]
            dcSettings["EmName"] = info[5]
            dcSettings["EmSurName"] = info[6]
            dcSettings["EmPhone"] = info[7]
        }
        
        // GAS
        dcGasSettings["DeviceID"] = dcSettings["DeviceID"]
        
        dcGasSettings["CurrGasNumber_OC"] = scubaSettings.mixes.CurrGasNumber_OC.decimalString
        dcGasSettings["CurrGasNumber_CC"] = scubaSettings.mixes.CurrGasNumber_CC.decimalString
        
        dcGasSettings["OC_FO2"] = scubaSettings.mixes.OC_FO2.map { String($0) }.joined(separator: ",")
        dcGasSettings["OC_FHe"] = scubaSettings.mixes.OC_FHe.map { String($0) }.joined(separator: ",")
        dcGasSettings["OC_Active"] = scubaSettings.mixes.OC_Active.map { String($0) }.joined(separator: ",")
        dcGasSettings["OC_MaxPo2"] = scubaSettings.mixes.OC_MaxPo2.map { String($0) }.joined(separator: ",")
        dcGasSettings["OC_ModFt"] = scubaSettings.mixes.OC_ModFt.map { String($0) }.joined(separator: ",")
        
        dcGasSettings["CC_FO2"] = scubaSettings.mixes.CC_FO2.map { String($0) }.joined(separator: ",")
        dcGasSettings["CC_FHe"] = scubaSettings.mixes.CC_FHe.map { String($0) }.joined(separator: ",")
        dcGasSettings["CC_Active"] = scubaSettings.mixes.CC_Active.map { String($0) }.joined(separator: ",")
        dcGasSettings["CC_MaxPo2"] = scubaSettings.mixes.CC_MaxPo2.map { String($0) }.joined(separator: ",")
        dcGasSettings["CC_ModFt"] = scubaSettings.mixes.CC_ModFt.map { String($0) }.joined(separator: ",")
        //
        
        DatabaseManager.shared.saveGasSettings(dcGasSettings: dcGasSettings)
        DatabaseManager.shared.saveDeviceSettings(modelId: self.ModelID, serialNo: self.SerialNo, dcSettings: dcSettings)
        
        return .just(.success)
    }
    
    func U_WriteSetting(settings: DeviceDataSettings) -> Observable<DeviceReadResult> {
        
        guard var systemSettings = settings.systemSettings,
              var scubaSettings = settings.scubaSettings else {
            return .just(.failure(error: nil))
        }
        
        if let (bleName, _) = peripheral.peripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            self.ModelID = dcInfo[2].toInt()
        }
        
        let path = (HomeDirectory().appendingFormat("%@", PDC_DATA) as NSString).appendingPathComponent("settingToWrite.plist")
        let url = URL(fileURLWithPath: path)
        
        guard let data = try? Data(contentsOf: url), let writeData = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return .just(.failure(error: nil))
        }
        
        // Tách ra:
        let gasMixes = writeData["GasMixes"] as! [String : Any] // giữ riêng giá trị của "GasMixes"
        let remainingSettings = writeData.filter { $0.key != "GasMixes" } // phần còn lại
        
        DatabaseManager.shared.saveGasSettings(dcGasSettings: gasMixes)
        DatabaseManager.shared.saveDeviceSettings(modelId: self.ModelID, serialNo: self.SerialNo, dcSettings: remainingSettings)
        
        do {
            let deviceID = writeData.uint8(for: "DeviceID")
            let results = try DatabaseManager.shared.fetchData(from: "DeviceSettings",
                                                               where: "DeviceID=?",
                                                               arguments: [deviceID])
            
            guard let row = results.first else { return .just(.failure(error: nil)) }
            
            // User Infos
            let userInfos: [String] = [
                row.stringValue(key: "Name"),
                //row.stringValue(key: "SurName"),
                "",
                row.stringValue(key: "Phone"),
                row.stringValue(key: "Email"),
                row.stringValue(key: "Blood"),
                row.stringValue(key: "EmName"),
                //row.stringValue(key: "EmSurName"),
                "",
                row.stringValue(key: "EmPhone")
            ]
            
            let userInfosString = userInfos.joined(separator: "|")
            
            // System Settings
            systemSettings.timeFormat = row.uint8Value(key: "TimeFormat")
            systemSettings.dateFormat = row.uint8Value(key: "DateFormat")
            systemSettings.units = row.uint8Value(key: "Units")
            systemSettings.waterDensity = row.uint8Value(key: "WaterDensity")
            systemSettings.backlightLevel = row.uint8Value(key: "BacklightLevel")
            systemSettings.backlightDimTime_s = row.uint8Value(key: "BacklightDimTime")
            systemSettings.backlightDimLevel = row.uint8Value(key: "BacklightDimLevel")
            systemSettings.buzzerMode = row.uint8Value(key: "BuzzerMode")
            systemSettings.diveLogSamplingTime_s = row.uint8Value(key: "DiveLogSamplingTime")
            
            // Scuba Settings
            scubaSettings.deepStopOn = row.uint8Value(key: "DeepStopOn")
            scubaSettings.oxToxAlarmPercent = row.uint8Value(key: "OxToxAlarmPercent")
            scubaSettings.noDecoAlarmMin = row.uint8Value(key: "NoDecoAlarmMin")
            scubaSettings.diveTimeAlarmMin = row.uint16Value(key: "DiveTimeAlarmMin")
            
            if systemSettings.units == M {
                scubaSettings.depthAlarmM = row.uint16Value(key: "DepthAlarmM")
            } else {
                scubaSettings.depthAlarmFt = row.uint16Value(key: "DepthAlarmFt")
            }
            
            /*
             [7/14/25, 4:58:14 PM] Phuc: GFLow/High thì sao?
             [7/14/25, 4:58:59 PM] MinhLV-VTM: Nó đi từ 0 anh, đọc sao lúc ghi vô trừ 1
             */
            scubaSettings.gfHigh = row.uint8Value(key: "GFHigh")
            scubaSettings.gfLow = row.uint8Value(key: "GFLow")
            
            scubaSettings.safetyStopMode = row.uint8Value(key: "SafetyStopMode")
            if scubaSettings.safetyStopMode == 1 {
                scubaSettings.safetyStopMin = row.uint8Value(key: "SafetyStopMin")
                scubaSettings.ssDepthFt = row.uint8Value(key: "SSDepthFt")
                scubaSettings.ssDepthM = row.uint8Value(key: "SSDepthM")
            }
            
            // Gas Settings
            if let activeString = gasMixes["OC_Active"] as? String {
                scubaSettings.mixes.OC_Active = activeString.split(separator: ",").compactMap { UInt8($0) }
            }
            
            if let fo2String = gasMixes["OC_FO2"] as? String {
                scubaSettings.mixes.OC_FO2 = fo2String.split(separator: ",").compactMap { UInt8($0) }
            }
            
            if let maxPo2String = gasMixes["OC_MaxPo2"] as? String {
                scubaSettings.mixes.OC_MaxPo2 = maxPo2String.split(separator: ",").compactMap { UInt8($0) }
            }
            
            PrintLog("Write Scuba Settings: \(scubaSettings)")
            
            return sendSetSystemSettings(systemSettings: systemSettings)
                .flatMap { _ in
                    return self.sendSetScubaSettings(scubaSettings: scubaSettings)
                }
                .flatMap { _ in
                    self.sendSetUserInfo(userInfosString)
                }
                .map { success in
                    success ? .success : .failure(error: nil)
                }
                .catch { error in
                    PrintLog("❌ Error while uploading settings: \(error)")
                    return .just(.failure(error: error.localizedDescription))
                }
        } catch {
            PrintLog("Failed to fetch data: \(error)")
            return .just(.failure(error: nil))
        }
    }
    
    func U_SetDateTime(settings: DeviceDataSettings) -> Observable<DeviceReadResult> {
        guard var systemSettings = settings.systemSettings else {
            return .just(.failure(error: nil))
        }
        
        if let (bleName, _) = peripheral.peripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            self.ModelID = dcInfo[2].toInt()
        }
        
        let path = (HomeDirectory().appendingFormat("%@", PDC_DATA) as NSString).appendingPathComponent("settingToWrite.plist")
        let url = URL(fileURLWithPath: path)
        
        guard let data = try? Data(contentsOf: url), let writeData = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return .just(.failure(error: nil))
        }
        
        // Tách ra:
        let remainingSettings = writeData.filter {
            $0.key != "SetDate" && $0.key != "SetTime"
        }
        
        DatabaseManager.shared.saveDeviceSettings(modelId: self.ModelID, serialNo: self.SerialNo, dcSettings: remainingSettings)
        
        var newDate = (writeData["SetDate"] as? String) ?? ""
        var newTime = (writeData["SetTime"] as? String) ?? ""
        
        do {
            let deviceID = writeData.uint8(for: "DeviceID")
            let results = try DatabaseManager.shared.fetchData(from: "DeviceSettings",
                                                               where: "DeviceID=?",
                                                               arguments: [deviceID])
            
            guard let row = results.first else { return .just(.failure(error: nil)) }
            
            // System Settings
            systemSettings.timeFormat = row.uint8Value(key: "TimeFormat")
            systemSettings.dateFormat = row.uint8Value(key: "DateFormat")
            
            if DeviceSettings.shared.useSystemDateTime {
                newDate = Utilities.getCurrentDateString(format: (systemSettings.dateFormat == 0) ? "dd.MM.yyyy":"MM.dd.yyyy")
                newTime = Utilities.getCurrentDateString(format: (systemSettings.timeFormat == 0) ? "HH:mm":"hh:mm a")
            }
            
            return sendSetSystemSettings(systemSettings: systemSettings)
                .flatMap { _ in
                    return self.sendSetGMTTime(newDate: newDate,
                                               newTime: newTime,
                                               dateFormat: systemSettings.dateFormat,
                                               timeFormat: systemSettings.timeFormat)
                }
                .map { success in
                    success ? .success : .failure(error: nil)
                }
        } catch {
            PrintLog("Failed to fetch data: \(error)")
            return .just(.failure(error: error.localizedDescription))
        }
        
    }
    
    func U_DownloadDives(settings: DeviceDataSettings) -> Observable<DeviceReadResult> {
        return sendGetLastLogID()
            .flatMap { resData -> Observable<DeviceReadResult> in
                guard let data = resData, data.count >= 4 else {
                    return .just(.failure(error: nil))
                }
                
                self.lastLogID = (data[0] << 24) | (data[1] << 16) | (data[2] << 8)  | data[3]
                //self.lastLogID = 4
                
                guard self.lastLogID > 0 else {
                    PrintLog("ℹ️ No dive profile to download")
                    return .just(.noDiveData)
                }
                
                PrintLog("✅ Last Log ID: \(self.lastLogID)")
                
                let observables = (1...Int(self.lastLogID)).map { logId in
                    PrintLog("GetLog - ID: \(logId)")
                    return self.sendGetLog(logId: logId) {
                        let percent = Int((Double(self.completedSampleCount) / Double(max(self.totalSampleCount, 1))) * 100)
                        ProgressHUD.animate("Downloading dive \(logId)/\(self.lastLogID) (\(percent)%)")
                    }
                }
                
                return Observable.concat(observables)
                    .toArray()
                    .map { records in
                        PrintLog("✅ Tổng số DiveRecords: \(records.count)")
                        
                        records.forEach { record in
                            if record != nil {
                                self.U_ConvertDives(record!, settings: settings)
                            }
                        }
                        
                        // ✅ Trả kết quả
                        return records.isEmpty ? .noDiveData : .success
                    }
                    .asObservable()
            }
            .catch { error in
                PrintLog("❌ Error while downloading logs: \(error)")
                return .just(.failure(error: error.localizedDescription))
            }
    }
    
    func U_ConvertDives(_ log: DiveRecord, settings: DeviceDataSettings) {
        var divedata: [String: Any] = [:]
        let logData = log.logData
        
        if let (bleName, _) = peripheral.peripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            divedata["DeviceName"] = dcInfo[1]
        }
        
        divedata["DiveNo"] = self.dataDecrypt(data: logData, startIndex: 0, len: 4) // Dùng DiveNo để lưu DiveID từ Log.
        divedata["ModelID"] = self.ModelID
        divedata["SerialNo"] = self.SerialNo
        
        //
        divedata["Units"] = settings.systemSettings?.units.decimalString
        divedata["Water"] = settings.systemSettings?.waterDensity.decimalString
        divedata["Light"] = settings.systemSettings?.backlightLevel.decimalString
        divedata["Sound"] = settings.systemSettings?.buzzerMode.decimalString
        //
        
        divedata["ProfileStartAddress"] = self.dataDecrypt(data: logData, startIndex: 4, len: 4)
        divedata["ProfileSizeBytes"] = self.dataDecrypt(data: logData, startIndex: 8, len: 4)
        
        var sec = logData[12]
        var min = logData[13]
        var hour = logData[14]
        var mday = logData[16]
        var mon = logData[17]
        var year = self.dataDecrypt(data: logData, startIndex: 18, len: 2)
        divedata["DiveStartLocalTime"] = String(format: "%02d/%02d/%d %02d:%02d:%02d", mday, mon, year, hour, min, sec)
        
        sec = logData[20]
        min = logData[21]
        hour = logData[22]
        mday = logData[24]
        mon = logData[25]
        year = self.dataDecrypt(data: logData, startIndex: 26, len: 2)
        divedata["DiveEndLocalTime"] = String(format: "%02d/%02d/%d %02d:%02d:%02d", mday, mon, year, hour, min, sec)
        
        divedata["TotalDiveTime"] = self.dataDecrypt(data: logData, startIndex: 28, len: 4)
        divedata["SurfTime"] = self.dataDecrypt(data: logData, startIndex: 32, len: 4)
        divedata["LocalTimeZoneID"] = logData[36]
        divedata["DiveMode"] = logData[37]
        divedata["DiveOfTheDay"] = logData[38]
        divedata["IsDecoDive"] = logData[39]
        divedata["MaxDepthFT"] = self.dataDecryptFloat(data: logData, startIndex: 40)
        divedata["AvgDepthFT"] = self.dataDecryptFloat(data: logData, startIndex: 44)
        divedata["MinTemperatureF"] = self.dataDecryptFloat(data: logData, startIndex: 48)
        divedata["MaxTemperatureF"] = self.dataDecryptFloat(data: logData, startIndex: 52)
        
        divedata["SamplingTime"] = logData[56]
        divedata["AltitudeLevel"] = logData[57]
        divedata["StartingMixIdx"] = logData[58]
        divedata["EndingMixIdx"] = logData[59]
        divedata["EndingTlbg"] = logData[60]
        divedata["EndingOxToxPercent"] = logData[61]
        divedata["MaxOxToxPercent"] = logData[62]
        divedata["MaxAscentSpeedLev"] = logData[63]
        divedata["Errors"] = self.dataDecrypt(data: logData, startIndex: 64, len: 4)
        divedata["MaxPpo2"] = self.dataDecryptFloat(data: logData, startIndex: 68)
        divedata["StartDiveTankPressurePSI"] = self.dataDecrypt(data: logData, startIndex: 72, len: 2)
        divedata["EndDiveTankPressurePSI"] = self.dataDecrypt(data: logData, startIndex: 74, len: 2)
        divedata["AvgMixConsumption"] = self.dataDecryptFloat(data: logData, startIndex: 76)
        divedata["GPSStartDive"] = self.dataDecryptFloat(data: logData, startIndex: 80)
        divedata["GPSEndDive"] = self.dataDecryptFloat(data: logData, startIndex: 84)
        divedata["GfHighPercent"] = logData[88] + 1
        divedata["GfLowPercent"] = logData[89] + 1
        divedata["OxToxAlarmPercent"] = logData[90]
        divedata["TlbgAlarm"] = logData[91]
        divedata["AscentSpeedAlarm"] = self.dataDecrypt(data: logData, startIndex: 92, len: 2)
        divedata["DiveTimeAlarm"] = self.dataDecrypt(data: logData, startIndex: 94, len: 2)
        divedata["DepthAlarmFT"] = self.dataDecrypt(data: logData, startIndex: 96, len: 2)
        divedata["DepthAlarmMT"] = self.dataDecrypt(data: logData, startIndex: 98, len: 2)
        
        divedata["NoDecoTimeAlarm"] = logData[100]
        divedata["SafetyStopMode"] = logData[101]
        divedata["SafetyStopTime"] = logData[102]
        divedata["SafetyStopDepthFT"] = logData[103]
        divedata["SafetyStopDepthMT"] = logData[104]
        divedata["DeepStopMode"] = logData[105]
        divedata["DeepStopTime"] = logData[106]
        
        divedata["Mix1Fo2Percent"] = logData[107]
        divedata["Mix2Fo2Percent"] = logData[108]
        divedata["Mix3Fo2Percent"] = logData[109]
        divedata["Mix4Fo2Percent"] = logData[110]
        divedata["Mix5Fo2Percent"] = logData[111]
        divedata["Mix6Fo2Percent"] = logData[112]
        divedata["Mix7Fo2Percent"] = logData[113]
        divedata["Mix1FHePercent"] = logData[114]
        divedata["Mix2FHePercent"] = logData[115]
        divedata["Mix3FHePercent"] = logData[116]
        divedata["Mix4FHePercent"] = logData[117]
        divedata["Mix5FHePercent"] = logData[118]
        divedata["Mix6FHePercent"] = logData[119]
        divedata["Mix7FHePercent"] = logData[120]
        divedata["Mix1PpO2Barx100"] = logData[121]
        divedata["Mix2PpO2Barx100"] = logData[122]
        divedata["Mix3PpO2Barx100"] = logData[123]
        divedata["Mix4PpO2Barx100"] = logData[124]
        divedata["Mix5PpO2Barx100"] = logData[125]
        divedata["Mix6PpO2Barx100"] = logData[126]
        divedata["Mix7PpO2Barx100"] = logData[127]
        divedata["EnabledMixes"] = self.dataDecrypt(data: logData, startIndex: 128, len: 2)
        divedata["MaxTLBG"] = logData[130]
        
        //
        //res0
        
        //TankTurnAlramOn
        divedata["TankTurnAlarmOn"] = logData[131]
        
        //TankEndAlramOn
        divedata["TankEndAlarmOn"] = logData[132]
        
        //TankTurnAlramBar
        divedata["TankTurnAlarmBar"] = self.dataDecrypt(data: logData, startIndex: 133, len: 2)
        
        //TankEndAlramBar
        divedata["TankEndAlarmBar"] = self.dataDecrypt(data: logData, startIndex: 135, len: 2)
        
        //TankTurnAlramPsi
        divedata["TankTurnAlarmPsi"] = self.dataDecrypt(data: logData, startIndex: 137, len: 2)
        
        //TankEndAlramPsi
        divedata["TankEndAlarmPsi"] = self.dataDecrypt(data: logData, startIndex: 139, len: 2)
        
        //TankReserveTimeAlramOn
        divedata["TankReserveTimeAlarmOn"] = logData[141]
        
        //TankReserveTimeAlramMin
        divedata["TankReserveTimeAlarmMin"] = logData[142]
        //
        
        
        let rs = DatabaseManager.shared.saveDiveData(diveData: divedata)
        if rs.existed == true { return }
        
        let profilesData = log.profiles
        profilesData.forEach { profile in
            var row: [String: Any] = [:]
            row["DiveID"] = rs.diveID
            row["SpeedFpm"] = self.dataDecrypt(data: profile, startIndex: 2, len: 2)
            row["DiveTime"] = self.dataDecrypt(data: profile, startIndex: 4, len: 4)
            row["DepthFT"] = self.dataDecrypt(data: profile, startIndex: 8, len: 2) // Dive Depth in meters x 10
            row["TemperatureF"] = self.dataDecrypt(data: profile, startIndex: 10, len: 2) // Temperature in Celcisuis x 10
            row["GfLocalPercent"] = profile[12]
            row["Tlbg"] = profile[13]
            row["OxToxPercent"] = profile[14]
            row["AlarmID"] = profile[15]
            row["PpO2Barx100"] = self.dataDecrypt(data: profile, startIndex: 16, len: 2)
            row["CurrentUsedMixIdx"] = profile[18]
            row["SwitchMixFlag"] = profile[19]
            row["NdlMin"] = self.dataDecrypt(data: profile, startIndex: 20, len: 2)
            row["DecoStopDepthFT"] = self.dataDecrypt(data: profile, startIndex: 22, len: 2)
            row["DecoTime"] = self.dataDecrypt(data: profile, startIndex: 24, len: 2)
            row["TankPSI"] = self.dataDecrypt(data: profile, startIndex: 26, len: 2)
            row["TankAtrMin"] = self.dataDecrypt(data: profile, startIndex: 28, len: 2)
            row["ActualTankID"] = profile[30]
            row["AlarmID2"] = profile[31]
            
            DatabaseManager.shared.saveDiveProfile(profile: row)
        }
    }
    
    func splitSamples(from data: Data, diveNo: Int, sampleSize: Int = 32) -> [Data] {
        guard data.count >= sampleSize else { return [] }
        
        var samples: [Data] = []
        let count = data.count / sampleSize
        
        for i in 0..<count {
            let start = i * sampleSize
            let end = start + sampleSize
            if end <= data.count {
                let sample = data.subdata(in: start..<end)
                
                // Lấy diveId từ 2 byte đầu tiên của sample
                let sampleDiveID = self.dataDecrypt(data: sample, startIndex: 0, len: 2)
                
                if sampleDiveID == diveNo {
                    samples.append(sample)
                } else {
                    PrintLog("⚠️ Sample bỏ qua vì DiveNo không khớp: \(sampleDiveID)")
                }
            }
        }
        
        return samples
    }
    
    
    // MARK: - Utilities
    func dataEncrypt(data: inout Data, value: Int, startIndex: Int, len: Int) {
        var mutableValue = value // Create a mutable copy of value
        
        if len == 1 {
            data[startIndex] = UInt8(mutableValue & 0xFF)
        } else {
            for i in 0..<len {
                data[startIndex + i] = UInt8(mutableValue & 0xFF)
                mutableValue >>= 8 // Now mutating the local copy
            }
        }
    }
    
    func dataDecrypt(data: Data, startIndex: Int, len: Int, dataType: DataType = .LBS) -> Int {
        var result = 0
        
        if len == 1 { // 1 byte
            result = Int(data[startIndex])
        } else {
            var v = 0
            if dataType == .LBS {
                for i in (0..<len).reversed() {
                    v = (v << 8) + Int(data[startIndex + i])
                }
            } else {
                for i in (0..<len) {
                    v = (v << 8) + Int(data[startIndex + i])
                }
            }
            result = v
        }
        
        return result
    }
    
    func dataDecryptFloat(data: Data, startIndex: Int, dataType: DataType = .MBS) -> Float {
        guard data.count >= startIndex + 4 else {
            return 0.0
        }
        
        let slice = data[startIndex..<startIndex+4]
        let bytes: [UInt8]
        
        switch dataType {
        case .LBS:
            bytes = Array(slice.reversed()) // Little Endian → reverse to Big for decoding
        case .MBS:
            bytes = Array(slice)
        }
        
        var float: Float = 0.0
        memcpy(&float, bytes, 4)
        
        return float.isNaN ? 0 : float
    }
    
    func bytesToFloat(_ data: Data) -> Float {
        guard data.count == 4 else { return 0.0 } // Đảm bảo có đủ 4 byte
        
        return data.withUnsafeBytes { buffer in
            buffer.load(as: Float.self) // Trực tiếp đọc dữ liệu thành Float
        }
    }
    
    func BCD2DecStr(value: Int, len: Int) -> String {
        var s = ""
        var v = value
        for _ in 0..<len {
            let r = v % 256
            s = "\(r / 16)\(r % 16)" + s
            v /= 256
        }
        return s
    }
    
    func CRC16(buf: Data) -> UInt16 {
        var crc: UInt32 = 0xFFFF
        
        for byte in buf {
            let index = Int((crc >> 8) ^ UInt32(byte)) & 0xFF
            crc = (crc << 8) ^ UInt32(CRC16Table[index]) // Cast to UInt32
        }
        
        return UInt16(crc & 0xFFFF)
    }
    
    func CRC16(buf: Data, len: Int) -> UInt16 {
        var crc: UInt32 = 0xFFFF
        
        for i in 0..<len {
            let byte = buf[i]
            let temp = Int((crc / 256) ^ UInt32(byte)) & 0xFF
            crc = ((crc * 256) & 0xFFFF) ^ UInt32(CRC16Table[temp])
        }
        
        return UInt16(crc & 0xFFFF)
    }
    
    /// **Tính toán CRC8 CCITT**
    private func crc8_ccitt(data: [UInt8], len: Int) -> UInt8 {
        var crc: UInt8 = 0
        for i in 0..<len {
            let value = (i == 3) ? 0 : data[i]
            let e = crc ^ value
            let f = e ^ (e >> 4) ^ (e >> 7)
            crc = (f << 1) ^ (f << 4)
        }
        return crc
    }
    
    private func isPacketValid(_ packet: [UInt8]) -> Bool {
        guard packet.count > 4 else { return false } // Kiểm tra độ dài tối thiểu
        
        if packet[0] != 0xCD {
            return false
        }
        
        let crc = Int(packet[3])
        let crc8 = crc8_ccitt(data: packet, len: Int(packet[4]) + 5)
        
        return crc == crc8
    }
    
    func getRandomPasscode() -> String {
        let lowerBound = 0
        let upperBound = 9999
        var rndValue = 0
        
        repeat {
            rndValue = lowerBound + Int(arc4random_uniform(UInt32(upperBound - lowerBound)))
        } while rndValue / 1000 <= 0
        
        let randomStr = String(format: "%04d", rndValue)
        
        var temp = rndValue
        var sum = 0
        
        while temp > 0 {
            sum += temp % 10
            temp /= 10
        }
        
        let sumOfRandomStr = String(format: "%02d", sum)
        
        return randomStr + sumOfRandomStr
    }
    
    func extractPayloadString(from response: Data?) -> String? {
        guard let response = response else { return nil }
        
        // Chuyển thành chuỗi UTF-8 (hoặc đổi encoding nếu dùng khác)
        let cleaned = response.filter { $0 != 0 }
        return String(bytes: cleaned, encoding: .utf8)
    }
    
    func extractFirmwarePayloadString(from response: Data?) -> String? {
        guard let response = response else { return nil }
        
        // Tìm vị trí 0x00 đầu tiên
        if let nullIndex = response.firstIndex(of: 0x00) {
            let subData = response.prefix(upTo: nullIndex)
            return String(data: subData, encoding: .utf8)
        } else {
            // Không có 0x00 thì decode cả chuỗi
            return String(data: response, encoding: .utf8)
        }
    }
    
    func trimmedData(from string: String, maxBytes: Int) -> Data {
        var result = Data()
        for char in string {
            let charData = Data(String(char).utf8)
            if result.count + charData.count > maxBytes {
                break
            }
            result.append(charData)
        }
        
        // Pad thêm 0x00 nếu thiếu
        if result.count < maxBytes {
            result.append(Data(repeating: 0x00, count: maxBytes - result.count))
        }
        
        return result
    }
    
}


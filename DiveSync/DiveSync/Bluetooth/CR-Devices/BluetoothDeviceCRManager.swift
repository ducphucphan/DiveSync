import Foundation
import GRDB
import ProgressHUD
import CoreBluetooth
import RxBluetoothKit
import RxSwift

final class BluetoothDeviceCRManager {
    
    struct BleCommand {
        let mainCmd: MainCmd
        let subCmd: UInt8
    }
    
    struct BleResponse {
        let data: Data
        let error: Error?
    }
    
    // ============================================
    // MARK: - BLE Protocol Definition
    // ============================================
    
    enum MainCmd: UInt8 {
        case generalSetting    = 0x41
        case deviceSetting     = 0x42
        case diveSetting       = 0x46
        case log               = 0x43
    }
    
    enum BleType: UInt8 {
        case read  = 0x00
        case write = 0x01
    }
    
    enum CmdError: UInt8, Error {
        case checksumError       = 0x02
        case unidentifiedCommand = 0x03
        case writeOnly           = 0x04
        case readOnly            = 0x05
        case parameterError      = 0x06
        case cmdForbidden        = 0x07
        case dataLengthError     = 0x08
        case noFileError         = 0x09
        
        var description: String {
            switch self {
            case .checksumError:       return "Checksum error"
            case .unidentifiedCommand: return "Unidentified command"
            case .writeOnly:           return "Write-only command"
            case .readOnly:            return "Read-only command"
            case .parameterError:      return "Parameter error"
            case .cmdForbidden:        return "Command forbidden"
            case .dataLengthError:     return "Data length error"
            case .noFileError:         return "No file error"
            }
        }
    }
    
    enum BleCommandKey: String, Hashable {
        case kUnit
        case kTimeFormat
        case kDeviceName
        case kSerialNumber
        case kFirmwareRev
        case kDiveWaterType
        case kDiveMode
        case kDiveO2
        case kDivePO2
        case kConservatism
        case kDepthAlarm
        case kTimeAlarm
        case kSamplingRate
        case kLogStartDepth
        case kLogStopTime
        case kDeepStopAlarm
        case kTimeSync
        case kNumOfLog
        
        var bleCommand: BleCommand {
            switch self {
                // MARK: - General Setting
            case .kUnit:
                return .init(mainCmd: .generalSetting, subCmd: 0x23)
            case .kTimeFormat:
                return .init(mainCmd: .generalSetting, subCmd: 0x33)
            case .kTimeSync:
                return .init(mainCmd: .generalSetting, subCmd: 0x31)
                // MARK: - Device Setting
            case .kDeviceName:
                return .init(mainCmd: .deviceSetting, subCmd: 0x11)
            case .kSerialNumber:
                return .init(mainCmd: .deviceSetting, subCmd: 0x13)
            case .kFirmwareRev:
                return .init(mainCmd: .deviceSetting, subCmd: 0x12)
                // MARK: - Dive Setting
            case .kDiveWaterType:
                return .init(mainCmd: .diveSetting, subCmd: 0x11)
            case .kDiveMode:
                return .init(mainCmd: .diveSetting, subCmd: 0x12)
            case .kDiveO2:
                return .init(mainCmd: .diveSetting, subCmd: 0x13)
            case .kDivePO2:
                return .init(mainCmd: .diveSetting, subCmd: 0x14)
            case .kConservatism:
                return .init(mainCmd: .diveSetting, subCmd: 0x21)
            case .kDepthAlarm:
                return .init(mainCmd: .diveSetting, subCmd: 0x22)
            case .kTimeAlarm:
                return .init(mainCmd: .diveSetting, subCmd: 0x23)
            case .kSamplingRate:
                return .init(mainCmd: .diveSetting, subCmd: 0x24)
            case .kLogStartDepth:
                return .init(mainCmd: .diveSetting, subCmd: 0x25)
            case .kLogStopTime:
                return .init(mainCmd: .diveSetting, subCmd: 0x26)
            case .kDeepStopAlarm:
                return .init(mainCmd: .diveSetting, subCmd: 0x27)
                // MARK: - Log
            case .kNumOfLog:
                return .init(mainCmd: .log, subCmd: 0x21)
            }
        }
    }
    
    // ============================================
    // MARK: - Properties
    // ============================================
    
    let scannedPeripheral: ScannedPeripheral
    
    private var writeCharacteristic: Characteristic?
    private var notifyCharacteristic: Characteristic?
    
    private let disposeBag = DisposeBag()
    private var notifyDisposable: Disposable?
    private let notifySubject = PublishSubject<Data>()
    
    typealias ReadStep = () -> Observable<Void>
    
    // Device info cache
    var firmwareRev = ""
    var SerialNo = ""
    var ModelID = 0
    
    var currentDateFormat = -1
    var currentTimeFormat = -1
    
    private var numOfLogs: Int = 0
    private var units: Int = M
    
    //private var responses: [BleCommandKey: BleResponse] = [:]
    private var responses: [BleCommandKey: [BleResponse]] = [:]
    
    // ============================================
    // MARK: - Init / Deinit
    // ============================================
    
    init(scannedPeripheral: ScannedPeripheral) {
        self.scannedPeripheral = scannedPeripheral
    }
    
    func dispose() {
        PrintLog("♻️ Dispose BluetoothDeviceCRManager")
        notifyDisposable?.dispose()
    }
    
    // ============================================
    // MARK: - BLE Discovery & Notify
    // ============================================
    
    func discoverServicesAndCharacteristics(
        servicesUUID: [CBUUID],
        writeCharUUID: CBUUID,
        readCharUUID: CBUUID
    ) -> Observable<Void> {
        
        scannedPeripheral.peripheral.discoverServices(servicesUUID)
            .asObservable()
            .flatMap { Observable.from($0) }
            .flatMap { service -> Observable<[Characteristic]> in
                switch service.uuid {
                case BLEConstants.SERVICES.logic[0]:
                    return service.discoverCharacteristics([readCharUUID]).asObservable()
                    
                case BLEConstants.SERVICES.logic[1]:
                    return service.discoverCharacteristics([writeCharUUID]).asObservable()
                    
                default:
                    return .empty()
                }
            }
            .do(onNext: { [weak self] characteristics in
                guard let self else { return }
                
                for char in characteristics {
                    PrintLog("🔍 Char: \(char.uuid) props: \(char.properties)")
                    
                    if char.uuid == writeCharUUID {
                        self.writeCharacteristic = char
                    }
                    
                    if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                        PrintLog("🔔 Found notify characteristic: \(char.uuid)")
                        self.notifyCharacteristic = char
                    }
                }
            })
            .filter { [weak self] _ in
                self?.writeCharacteristic != nil &&
                self?.notifyCharacteristic != nil
            }
            .take(1)
            .flatMap { [weak self] _ in
                self?.enableNotifyIfNeeded() ?? .empty()
            }
    }
    
    private func enableNotifyIfNeeded() -> Observable<Void> {
        guard let notifyChar = notifyCharacteristic else {
            return Observable.error(
                NSError(domain: "Bluetooth", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Notify characteristic not found"])
            )
        }
        
        PrintLog("🔔 Enable notify on \(notifyChar.uuid)")
        
        notifyDisposable = notifyChar
            .observeValueUpdateAndSetNotification()
            .compactMap { $0.value }
            .subscribe(onNext: { [weak self] data in
                PrintLog("📥 Notify raw: \(data.hexString)")
                self?.notifySubject.onNext(data)
            })
        
        return .just(())
    }
    
    func waitForResponse() -> Observable<Data> {
        notifySubject.take(1)
    }
    
    func runSequential(_ steps: [ReadStep]) -> Observable<Void> {
        steps.reduce(Observable.just(())) { result, step in
            result.flatMap { step() }
        }
    }
    
    // ============================================
    // MARK: - Command Transport
    // ============================================
    
    private func sendSimpleCommand(
        command: UInt8,
        subcommand: UInt8,
        rw: UInt8,
        payload: [UInt8] = []
    ) -> Observable<Void> {
        
        guard let characteristic = writeCharacteristic else {
            return Observable.error(
                NSError(domain: "Bluetooth", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Write characteristic not found"])
            )
        }
        
        let data = cmdData(
            command: command,
            subcommand: subcommand,
            rw: rw,
            payload: payload
        )
        
        if rw == BleType.write.rawValue {
            PrintLog("📤 SEND WRITE: \(data.hexString)")
        } else {
            PrintLog("📤 SEND READ: \(data.hexString)")
        }
        
        return scannedPeripheral.peripheral
            .writeValue(data, for: characteristic, type: .withoutResponse)
            .asObservable()
            .map { _ in () }
    }
    
    func sendSimpleCommandWithResponse(
        command: UInt8,
        subcommand: UInt8,
        rw: UInt8,
        payload: [UInt8] = []
    ) -> Observable<BleResponse> {
        sendSimpleCommand(
            command: command,
            subcommand: subcommand,
            rw: rw,
            payload: payload
        )
        .flatMap { [weak self] _ in
            self?.waitForResponse() ?? .empty()
        }
        .map { [weak self] raw in
            do {
                let data = try self?.parseResponse(raw) ?? Data()
                return BleResponse(data: data, error: nil)
            } catch let error {
                return BleResponse(data: Data(), error: error)
            }
        }
    }
    
    // ============================================
    // MARK: - Packet & Parser
    // ============================================
    
    private func cmdData(
        command: UInt8,
        subcommand: UInt8,
        rw: UInt8,
        payload: [UInt8] = []
    ) -> Data {
        
        var buffer: [UInt8] = [
            command,
            subcommand,
            rw,
            UInt8(payload.count)
        ]
        
        if command == BleCommandKey.kNumOfLog.bleCommand.mainCmd.rawValue {
            buffer = [
                command,
                subcommand
            ]
        }
        
        buffer.append(contentsOf: payload)
        buffer.append(calcChecksum(buffer))
        
        return Data(buffer)
    }
    
    private func parseResponse(_ data: Data) throws -> Data? {
        let bytes = [UInt8](data)
        
        guard bytes.count >= 5 else {
            throw NSError(domain: "Bluetooth", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Response too short"])
        }
        
        guard verifyChecksum(bytes) else {
            throw NSError(domain: "Bluetooth", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid checksum"])
        }
        
        if bytes[2] == 0xFF && bytes[3] == 0xFF {
            let errorCode = bytes[4]
            let error = CmdError(rawValue: errorCode)
            throw NSError(
                domain: "Bluetooth",
                code: Int(errorCode),
                userInfo: [NSLocalizedDescriptionKey:
                            error?.description ?? "Unknown BLE error"]
            )
        }
        
        let mainCmd = bytes[0]
        let subCmd = bytes[1]
        
        var len = Int(bytes[3])
        var payloadStart = 4
        
        if mainCmd == MainCmd.log.rawValue {
            len = Int((UInt16(bytes[2]) << 8) | UInt16(bytes[3]))
            payloadStart = 4
        }
        
        let payloadEnd = payloadStart + len
        
        guard bytes.count >= payloadEnd + 1 else {
            throw NSError(
                domain: "Bluetooth",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Payload length mismatch"]
            )
        }
        
        return Data(bytes[payloadStart..<payloadEnd])
    }
    
    private func calcChecksum(_ bytes: [UInt8]) -> UInt8 {
        var crc: UInt8 = 0x00
        for byte in bytes {
            crc ^= byte
            for _ in 0..<8 {
                crc = (crc & 0x80) != 0 ? (crc << 1) ^ 0x07 : crc << 1
            }
        }
        return crc
    }
    
    private func verifyChecksum(_ packet: [UInt8]) -> Bool {
        guard packet.count >= 2 else { return false }
        return calcChecksum(Array(packet.dropLast())) == packet.last
    }
    
    func readAllSettings(completion: (() -> Void)? = nil) {
        if syncType == .kDownloadSetting {
            ProgressHUD.animate("Reading device settings...".localized)
        } else if syncType == .kUploadSetting {
            ProgressHUD.animate("Writing device settings...".localized)
        } else if syncType == .kDownloadDiveData {
            ProgressHUD.animate("Downloading dives...".localized)
        } else if syncType == .kUploadOwnerInfo {
            ProgressHUD.animate("Uploading your owner info...".localized)
        }
        
        responses.removeAll()
        
        let commands: [BleCommandKey] = [
            .kUnit,
            .kTimeFormat,
            .kDeviceName,
            .kSerialNumber,
            .kFirmwareRev,
            .kDiveWaterType,
            .kDiveMode,
            .kDiveO2,
            .kDivePO2,
            .kConservatism,
            .kDepthAlarm,
            .kTimeAlarm,
            .kSamplingRate,
            .kLogStartDepth,
            .kLogStopTime,
            .kDeepStopAlarm
        ]
        
        let steps: [ReadStep] = commands.flatMap { cmd in
            
            cmd.readPayloads.map { payload in
                
                return {
                    self.sendSimpleCommandWithResponse(
                        command: cmd.bleCommand.mainCmd.rawValue,
                        subcommand: cmd.bleCommand.subCmd,
                        rw: BleType.read.rawValue,
                        payload: payload
                    )
                    .do(onNext: { [weak self] response in
                        
                        guard let self else { return }
                        
                        // Nếu là lần đọc ON/OFF (payload 0xFF)
                        if payload == [0xFF] {
                            //self.responses[cmd] = response
                            self.responses[cmd, default: []].append(response)
                        }
                        // Nếu là lần đọc giá trị thật (payload 0x00)
                        else if payload == [0x00] {
                            // bạn có thể lưu riêng nếu muốn
                            //self.responses[cmd] = response
                            self.responses[cmd, default: []].append(response)
                        }
                        else {
                            //self.responses[cmd] = response
                            self.responses[cmd, default: []].append(response)
                        }
                    })
                    .map { _ in () }
                }
            }
        }
        
        runSequential(steps)
            .flatMap { [weak self] _ -> Observable<DeviceReadResult> in
                guard let self else {
                    return .error("" as! Error)
                }
                
                if let list = responses[.kSerialNumber], let first = list.first {
                    let trimmedData = first.data.dropLast(2)
                    self.SerialNo = trimmedData.asciiString ?? ""
                }
                
                switch syncType {
                case .kUploadDateTime:
                    return self.U_LogicWriteTimeSync()
                case .kUploadSetting:
                    return self.U_LogicWriteSetting()
                default:
                    return self.U_LogicSaveSetting()
                        .flatMap { saveSuccess -> Observable<DeviceReadResult> in
                            if syncType == .kDownloadDiveData && saveSuccess == .success {
                                return self.U_DownloadLogcDives()
                            } else {
                                return .just(saveSuccess)
                            }
                        }
                }
                
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { result in
                
                ProgressHUD.dismiss()
                
                guard let m = BluetoothDeviceCoordinator.shared.crDeviceManager else { return }
                
                var props: [String: Any] = [
                    "ModelID": m.ModelID,
                    "SerialNo": m.SerialNo,
                    "Identity": m.scannedPeripheral.advertisementData.localName ?? "",
                    "LastSync": Utilities.getLastSyncText(date: Date()),
                    "Firmware": m.firmwareRev,
                    "Units": m.units
                ]
                
                if let (bleName, _) = self.scannedPeripheral.splitDeviceName(),
                   let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
                    props["Manufacture"] = dcInfo[0]
                    props["ModelName"]   = dcInfo[1]
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
                    } else if syncType == .kUploadOwnerInfo {
                        msg = "Your device's owner info are uploaded"
                    }
                }
                
                // Lưu DB
                if DatabaseManager.shared.isExistDevice(modelId: m.ModelID, serialNo: m.SerialNo) {
                    let cond = "where ModelID=\(m.ModelID) and SerialNo='\(m.SerialNo)'"
                    DatabaseManager.shared.updateTable(tableName: "devices", params: props, conditions: cond)
                } else {
                    _ = DatabaseManager.shared.insertIntoTable(tableName: "devices", params: props)
                }
                
                if syncType == .kDownloadDiveData {
                    DatabaseManager.shared.updateDeviceStatisticsFromLogs(modelId: m.ModelID, serialNo: m.SerialNo)
                }
                
                BluetoothDeviceCoordinator.shared.disconnect()
                BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: msg.localized)
            }, onError: { error in
                ProgressHUD.dismiss()
                BluetoothDeviceCoordinator.shared.disconnect()
                
                if let rxError = error as? RxError, case .timeout = rxError {
                    BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: "Time out".localized)
                } else {
                    BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: "❗️\(error.localizedDescription.localized)")
                }
            }).disposed(by: disposeBag)
    }
    
    // MARK: - PARSE DATA
    func U_LogicSaveSetting() -> Observable<DeviceReadResult> {
        
        if let (bleName, _) = scannedPeripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            self.ModelID = dcInfo[2].toInt()
        }
        
        var dcSettings: [String: Any] = [:]
        
        dcSettings["DeviceID"] = DatabaseManager.shared.lastDevicID(modelId: ModelID, serialNo: self.SerialNo)
        
        if let first = responses[.kUnit]?.first, let value = first.data.first {
            units = Int(value)
            dcSettings["Units"] = value.decimalString
        }
        
        if let first = responses[.kSerialNumber]?.first {
            let trimmedData = first.data.dropLast(2)
            self.SerialNo = trimmedData.asciiString ?? ""
        }
        
        if let first = responses[.kTimeFormat]?.first, let value = first.data.first {
            dcSettings["TimeFormat"] = value.decimalString
        }
        
        if let first = responses[.kDeviceName]?.first {
            PrintLog("DEVICE-NAME = \(first.data.utf8String ?? "")")
        }
        
        if let first = responses[.kFirmwareRev]?.first {
            self.firmwareRev = first.data.asciiString ?? ""
        }
        
        if let first = responses[.kDiveWaterType]?.first, let value = first.data.first {
            dcSettings["WaterDensity"] = value.decimalString
        }
        
        if let first = responses[.kDiveMode]?.first, let value = first.data.first {
            dcSettings["DiveMode"] = value.decimalString
        }
        
        if let first = responses[.kDiveO2]?.first, let value = first.data.first {
            dcSettings["FO2"] = value.decimalString
        }
        
        if let first = responses[.kDivePO2]?.first, let value = first.data.first {
            dcSettings["PO2"] = value.decimalString
        }
        
        if let first = responses[.kConservatism]?.first, let value = first.data.first {
            dcSettings["Conservatism"] = value.decimalString
        }
        
        if let list = responses[.kDepthAlarm], list.count == 2 {
            let onOff = list[0].data.first
            let value = list[1].data.first
            if onOff == 0 {
                dcSettings["DepthAlarmM"] = 0
            } else {
                dcSettings["DepthAlarmM"] = value?.decimalString
            }
        }
        
        if let list = responses[.kTimeAlarm], list.count == 2 {
            let onOff = list[0].data.first
            let value = list[1].data.first
            if onOff == 0 {
                dcSettings["DiveTimeAlarmMin"] = 0
            } else {
                dcSettings["DiveTimeAlarmMin"] = value?.decimalString
            }
        }
        
        if let first = responses[.kSamplingRate]?.first, let value = first.data.first {
            dcSettings["DiveLogSamplingTime"] = value.decimalString
        }
        
        if let first = responses[.kLogStartDepth]?.first, let value = first.data.first {
            dcSettings["LogStartDepth"] = value.decimalString
        }
        
        if let first = responses[.kLogStopTime]?.first, let value = first.data.first {
            dcSettings["LogStopTime"] = value.decimalString
        }
        
        if let first = responses[.kDeepStopAlarm]?.first, let value = first.data.first {
            dcSettings["DeepStopOn"] = value.decimalString
        }
        
        print(dcSettings)
        DatabaseManager.shared.saveDeviceSettings(modelId: self.ModelID, serialNo: self.SerialNo, dcSettings: dcSettings)
        
        return .just(.success)
    }
    
    func U_LogicWriteSetting() -> Observable<DeviceReadResult> {
        // 1. Lấy thông tin ModelID
        if let (bleName, _) = scannedPeripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            self.ModelID = dcInfo[2].toInt()
        }
        
        // 2. Đọc dữ liệu từ file Plist
        let path = (HomeDirectory().appendingFormat("%@", PDC_DATA) as NSString).appendingPathComponent("settingToWrite.plist")
        let url = URL(fileURLWithPath: path)
        
        guard let data = try? Data(contentsOf: url),
              let writeData = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return .just(.failure(error: nil))
        }
        
        // Lưu vào DB cục bộ trước
        DatabaseManager.shared.saveDeviceSettings(modelId: self.ModelID, serialNo: String(self.SerialNo), dcSettings: writeData)
        
        do {
            let deviceID = writeData.uint8(for: "DeviceID")
            let results = try DatabaseManager.shared.fetchData(from: "DeviceSettings",
                                                               where: "DeviceID=?",
                                                               arguments: [deviceID])
            
            guard let row = results.first else { return .just(.failure(error: nil)) }
            
            
            // 3. Chuẩn bị danh sách lệnh ghi
            let commandsToWrite: [BleCommandKey] = [
                .kUnit,
                .kTimeFormat,
                .kDiveWaterType,
                .kDiveMode,
                .kDiveO2,
                .kDivePO2,
                .kConservatism,
                .kDepthAlarm,
                .kTimeAlarm,
                .kSamplingRate,
                .kLogStartDepth,
                .kLogStopTime,
                .kDeepStopAlarm
            ]
            
            // Lấy Units để parse DepthAlarm chính xác
            let writeUnits = row.stringValue(key: "Units").toInt()
            
            units = writeUnits
            
            let steps: [ReadStep] = commandsToWrite.flatMap { cmd -> [ReadStep] in
                
                guard let payloads = cmd.getWritePayloads(from: row, units: writeUnits) else {
                    return []
                }
                
                return payloads.map { payload -> ReadStep in
                    
                    let step: ReadStep = {
                        self.sendSimpleCommandWithResponse(
                            command: cmd.bleCommand.mainCmd.rawValue,
                            subcommand: cmd.bleCommand.subCmd,
                            rw: BleType.read.rawValue,
                            payload: payload
                        )
                        .map { _ in () }
                    }
                    
                    return step
                }
            }
            
            // 4. Thực thi và trả về Observable để bên ngoài subscribe
            return runSequential(steps)
                .map { _ in DeviceReadResult.success }
                .catch { error in .just(.failure(error: error.localizedDescription)) }
            
        } catch {
            PrintLog("Failed to fetch data: \(error)")
            return .just(.failure(error: nil))
        }
    }
    
    private func U_ConvertDives(_ log: DiveRecord) throws -> Void {
        let headerSize = 512
        let sampleSize = 6
        
        let data = log.logData
        
        guard data.count >= headerSize else {
            throw NSError(domain: "DiveHeader", code: -1)
        }
        
        var divedata: [String: Any] = [:]
        
        if let (bleName, _) = scannedPeripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            divedata["DeviceName"] = dcInfo[1]
        }
        
        let header = data.prefix(headerSize)
        
        let projectName = String(
            data: header[0..<6],
            encoding: .ascii
        )?.trimmingCharacters(in: .controlCharacters) ?? ""
        
        print("PROJECT NAME: \(projectName)")
        
        let firmwareVersion = String(
            data: header[6..<22],
            encoding: .ascii
        )?.trimmingCharacters(in: .controlCharacters) ?? ""
        print("PRIMWARE VERSION: \(firmwareVersion)")
        
        let profileLength = header.u32LE(32)
        print("PROFILE LENGTH: \(profileLength)")
        
        print("Log version: \(header.u8(47))")
        
        let logIndex = header.u16LE(48)
        
        divedata["DiveNo"] = logIndex
        divedata["ModelID"] = self.ModelID
        divedata["SerialNo"] = self.SerialNo
        
        divedata["DiveOfTheDay"] = (logIndex + 1) // Do device không có trường để lấy DiveOfTheDay nên lưu tạm logindex
        
        let maxDepthRaw = header.u16LE(264)
        let maxDepth = Double(maxDepthRaw) / 100.0
        divedata["MaxDepthFT"] = convertMeter2Feet(maxDepth)
        
        let avgDepthRaw = header.u16LE(266)
        let avgDepth = Double(avgDepthRaw) / 100.0
        divedata["AvgDepthFT"] = convertMeter2Feet(avgDepth)
        
        let tempMinRaw = header.u16LE(92)
        let tempMin = Double(tempMinRaw) / 10.0
        divedata["MinTemperatureF"] = convertC2F(tempMin)
        
        let tempMaxRaw = header.u16LE(88)
        let tempMax = Double(tempMaxRaw) / 10.0
        divedata["MaxTemperatureF"] = convertC2F(tempMax)
        
        let deviceName = String(
            data: header[117..<149],
            encoding: .ascii
        )?.trimmingCharacters(in: .controlCharacters) ?? ""
        print("DEVICE NAME: \(deviceName)")
        
        let serialNumber = String(
            data: header[149..<181],
            encoding: .ascii
        )?.trimmingCharacters(in: .controlCharacters) ?? ""
        print("SERIAL NUMBER: \(serialNumber)")
        
        print("sensor_mark_count: \(header.u16LE(433))")
        print("tissue_N2_mark_count: \(header.u16LE(435))")
        print("alarm_mark_count: \(header.u16LE(437))")
        print("state_mark_count: \(header.u16LE(439))")
        print("user_mark_count: \(header.u16LE(441))")
        print("system_mark_count: \(header.u16LE(443))")
        
        //
        divedata["Units"] = units
        
        divedata["DiveMode"] = header.u8(22)
        
        divedata["Water"] = header.u8(219)
        
        let timezone = header.u8(31)
        
        let startUTC = header.u32LE(23)
        let startDate = Date(timeIntervalSince1970: TimeInterval(startUTC))
        divedata["DiveStartLocalTime"] = formatDiveDate(startDate, timezoneOffset: Int(timezone))
        
        let endUTC   = header.u32LE(27)
        let endDate   = Date(timeIntervalSince1970: TimeInterval(endUTC))
        divedata["DiveEndLocalTime"] = formatDiveDate(endDate, timezoneOffset: Int(timezone))
        
        /*
         0 : Conserve   CF1 (35/75)
         1 : Normal       CF2 (40/85)
         2 : Aggressive CF3 (45/95)
         */
        divedata["GfHighPercent"] = header.u8(217)
        divedata["GfLowPercent"] = header.u8(218)
        
        divedata["TotalDiveTime"] = header.u32LE(260)
        
        let surfTimeValue = header.u32LE(256)
        let limit24H: UInt32 = 86400 // 24 * 60 * 60
        if surfTimeValue > limit24H {
            divedata["SurfTime"] = 0
        } else {
            divedata["SurfTime"] = surfTimeValue
        }
        
        divedata["SamplingTime"] = Int(Double(header.u16LE(50)) * 0.01)
        
        divedata["TankTurnAlarmBar"] = header.u16LE(68)
        
        //TankEndAlramBar
        divedata["TankEndAlarmBar"] = header.u16LE(70)
        
        //TankTurnAlramPsi
        divedata["TankTurnAlarmPsi"] = Int(convertUBAR2PSI(Double(header.u16LE(68))))
        
        //TankEndAlramPsi
        divedata["TankEndAlarmPsi"] = Int(convertUBAR2PSI(Double(header.u16LE(70))))
        
        let rawAscentRate = Double(header.u16LE(272)) / 100 //100 in 1 meter/sec (ref. salinity), 0 at surface
        let ftPerMin = convertMeter2Feet(rawAscentRate) * 60
        // Lưu vào Database (thường làm tròn 1 hoặc 2 chữ số thập phân tùy nhu cầu)
        let ascentRatevalueToSave = (ftPerMin * 100).rounded() / 100 // Kết quả: 82.68
        divedata["AscentSpeedAlarm"] = ascentRatevalueToSave
        
        let rawDescentRate = Double(header.u16LE(276)) / 100 //100 in 1 meter/sec (ref. salinity), 0 at surface
        let ftPerMinDescent = convertMeter2Feet(rawDescentRate) * 60
        // Lưu vào Database (thường làm tròn 1 hoặc 2 chữ số thập phân tùy nhu cầu)
        let descentRatevalueToSave = (ftPerMinDescent * 100).rounded() / 100 // Kết quả: 82.68
        divedata["DescentSpeedAlarm"] = descentRatevalueToSave
        
        divedata["Mix1Fo2Percent"] = header.u8(197)
        divedata["Mix2Fo2Percent"] = header.u8(201)
        divedata["Mix3Fo2Percent"] = header.u8(205)
        divedata["Mix4Fo2Percent"] = header.u8(209)
        divedata["Mix5Fo2Percent"] = header.u8(213)
        
        divedata["Mix1FHePercent"] = header.u8(198)
        divedata["Mix2FHePercent"] = header.u8(202)
        divedata["Mix3FHePercent"] = header.u8(206)
        divedata["Mix4FHePercent"] = header.u8(210)
        divedata["Mix5FHePercent"] = header.u8(214)
        
        divedata["Mix1PpO2Barx100"] = header.u8(199)
        divedata["Mix2PpO2Barx100"] = header.u8(203)
        divedata["Mix3PpO2Barx100"] = header.u8(207)
        divedata["Mix4PpO2Barx100"] = header.u8(211)
        divedata["Mix5PpO2Barx100"] = header.u8(215)
        
        //print("start_nitro_pressure[16] = \(header.u32(282))")
        //print("end_nitro_pressure[16] = \(header.u32(314))")
        
        divedata["MaxPpo2"] = Double(header.u8(428)) / 10
        
        PrintLog(divedata)
        
        let rs = DatabaseManager.shared.saveDiveData(diveData: divedata)
        if rs.existed == true { return }
        
        // DIVE PROFILE
        let profileData = data.subdata(in: headerSize..<data.count)
        print(profileData.hexString)
        
        let count = profileData.count / sampleSize
        
        let samplingTime = divedata["SamplingTime"] as? Int ?? 0
        
        var offset = 0
        var diveTime = 0
        var currentSpO2: Int = 0
        var currentAlarmID: Int = 0
        var decoStopDepth: Double = 0
        var decoTime: Int = 0
        
        while offset < profileData.count {
            let type = profileData.u8(offset)
            
            switch type {
            case 0x01:
                if offset + 6 <= profileData.count {
                    var row: [String: Any] = [:]
                    
                    row["DiveID"] = rs.diveID
                                                            
                    // ---- SENSOR (0–5)
                    let sensorType = profileData.u8(offset)
                    let heartrate = profileData.u8(offset + 1)
                    let depthRaw = profileData.u16LE(offset + 2)
                    let tempRaw = profileData.u16LE(offset + 4)
                    
                    let depth = (Double(depthRaw) / 100.0) * 10.0 // format cho giống các device khác.
                    let temperature = Double(tempRaw)
                    
                    print("LOG_DIVE_MARK_TYPE_SENSOR:", sensorType)
                    print("heartrate:", heartrate)
                    print("depth:", depth)
                    print("temperature:", temperature)
                    
                    row["DepthFT"] = depth // Dive Depth in meters x 100
                    row["TemperatureF"] = temperature // Temperature in Celcisuis x 10
                    row["DiveTime"] = diveTime
                                        
                    // Gán các giá trị tích lũy từ các gói khác (nếu có)
                    row["OxToxPercent"] = currentSpO2 // Ánh xạ SpO2 vào cột cũ nếu cần
                    row["AlarmID"] = currentAlarmID
                    row["DecoStopDepthFT"] = decoStopDepth
                    row["DecoTime"] = decoTime
                    
                    DatabaseManager.shared.saveDiveProfile(profile: row)
                    
                    // Tăng diveTime theo chu kỳ lấy mẫu
                    diveTime += samplingTime
                    offset += 6
                    
                    // Reset các biến chỉ xuất hiện theo sự kiện (tùy nhu cầu)
                    currentAlarmID = 0
                } else { offset = profileData.count }
            case 0x02:
                if offset + 33 <= profileData.count {
                    offset += 33
                } else { offset = profileData.count }
            case 0x03:
                if offset + 9 <= profileData.count {
                    currentAlarmID = Int(profileData.u32(offset + 5))
                    offset += 9
                } else { offset = profileData.count }
            case 0x04:
                if offset + 8 <= profileData.count {
                    /*
                     update_type
                     Value      Name    Notes
                     0          LOG_MARK_UPDATE_STATE_TO_NORMAL
                     1          LOG_MARK_UPDATE_STATE_TO_NORMAL_STOP
                     2          LOG_MARK_UPDATE_STATE_TO_DECO
                     3          LOG_MARK_UPDATE_STATE_TO_DECO_STOP
                     4          LOG_MARK_UPDATE_DECO_STOP_DEPTH
                     */
                    
                    let decoType = profileData.u8(offset + 1)
                    if decoType == 4 {
                        decoStopDepth = Double(profileData.u16LE(offset + 2))
                        decoTime = Int(profileData.u16LE(offset + 4))
                    }
                    offset += 8
                } else { offset = profileData.count }
            case 0x05:
                if offset + 7 <= profileData.count {
                    offset += 7
                } else { offset = profileData.count }
            case 0x06:
                if offset + 5 <= profileData.count {
                    offset += 5
                } else { offset = profileData.count }
            default:
                offset += 1
                break
            }
            
        }
        
        /*
        for i in 0..<count {
            
            var row: [String: Any] = [:]
            row["DiveID"] = rs.diveID
            
            let base = i * sampleSize
            let sample = profileData.subdata(in: base..<base+sampleSize)
            
            print("--------- SAMPLE \(i) ---------")
            
            // ---- SENSOR (0–5)
            let sensorType = sample.u8(0)
            let heartrate = sample.u8(1)
            let depthRaw = sample.u16LE(2)
            let tempRaw = sample.u16LE(4)
            
            let depth = (Double(depthRaw) / 100.0) * 10.0 // format cho giống các device khác.
            let temperature = Double(tempRaw)
            
            print("LOG_DIVE_MARK_TYPE_SENSOR:", sensorType)
            print("heartrate:", heartrate)
            print("depth:", depth)
            print("temperature:", temperature)
            
            row["DepthFT"] = depth // Dive Depth in meters x 100
            row["TemperatureF"] = temperature // Temperature in Celcisuis x 10
            row["DiveTime"] = diveTime
            
            diveTime += divedata["SamplingTime"] as! Int
            
            DatabaseManager.shared.saveDiveProfile(profile: row)
            
        }
        */
    }
    
    func U_LogicWriteTimeSync() -> Observable<DeviceReadResult> {
        
        if let (bleName, _) = scannedPeripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            self.ModelID = dcInfo[2].toInt()
        }
        
        let path = (HomeDirectory().appendingFormat("%@", PDC_DATA) as NSString)
            .appendingPathComponent("settingToWrite.plist")
        let url = URL(fileURLWithPath: path)
        
        guard let data = try? Data(contentsOf: url),
              let writeData = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return .just(.failure(error: nil))
        }
        
        let remainingSettings = writeData.filter {
            $0.key != "SetDate" && $0.key != "SetTime"
        }
        
        DatabaseManager.shared.saveDeviceSettings(modelId: self.ModelID, serialNo: String(self.SerialNo), dcSettings: remainingSettings)
        
        do {
            let deviceID = writeData.uint8(for: "DeviceID")
            let results = try DatabaseManager.shared.fetchData(from: "DeviceSettings",
                                                               where: "DeviceID=?",
                                                               arguments: [deviceID])
            
            guard let row = results.first else { return .just(.failure(error: nil)) }
            
            // =====================================================
            // 1️⃣ Build finalDate
            // =====================================================
            
            let finalDate: Date
            let isSystem = DeviceSettings.shared.useSystemDateTime
            
            if isSystem {
                finalDate = Date()
            } else {
                let dateString = (writeData["SetDate"] as? String) ?? ""
                let timeString = (writeData["SetTime"] as? String) ?? ""
                
                let hasWhitespace = timeString.rangeOfCharacter(from: .whitespaces) != nil
                
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current
                
                if hasWhitespace {
                    formatter.dateFormat = "dd.MM.yyyy hh:mm a"
                } else {
                    formatter.dateFormat = "dd.MM.yyyy HH:mm"
                }
                
                let fullString = "\(dateString) \(timeString)"
                finalDate = formatter.date(from: fullString) ?? Date()
            }
            
            // =====================================================
            // 2️⃣ Build TimeSync payload
            // =====================================================
            
            let timestamp = UInt32(finalDate.timeIntervalSince1970)
            
            let utcBytes: [UInt8] = [
                UInt8((timestamp >> 24) & 0xFF),
                UInt8((timestamp >> 16) & 0xFF),
                UInt8((timestamp >> 8) & 0xFF),
                UInt8(timestamp & 0xFF)
            ]
            
            let minutes = TimeZone.current.secondsFromGMT() / 60
            let tzIndex = UInt8((minutes / 30) + 48)
            
            let timeSyncPayload = utcBytes + [tzIndex]
            
            // =====================================================
            // 3️⃣ Build TimeFormat payload
            // =====================================================
            
            let timeFormatValue = row.uint8Value(key: "TimeFormat")
            
            let timeFormatPayload: [UInt8] = [timeFormatValue]
            
            // =====================================================
            // 4️⃣ Create steps
            // =====================================================
            
            let timeFormatStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kTimeFormat.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kTimeFormat.bleCommand.subCmd,
                    rw: BleType.read.rawValue,   // ✅ WRITE
                    payload: timeFormatPayload
                )
                .map { _ in () }
            }
            
            let timeSyncStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kTimeSync.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kTimeSync.bleCommand.subCmd,
                    rw: BleType.read.rawValue,   // ✅ WRITE
                    payload: timeSyncPayload
                )
                .map { _ in () }
            }
            
            // =====================================================
            // 5️⃣ Run sequential (Format trước, Sync sau)
            // =====================================================
            
            return runSequential([timeFormatStep, timeSyncStep])
                .map { _ in DeviceReadResult.success }
                .catch { error in
                        .just(.failure(error: error.localizedDescription))
                }
            
        } catch {
            PrintLog("Failed to fetch data: \(error)")
            return .just(.failure(error: error.localizedDescription))
        }
    }
    
    func U_DownloadLogcDives() -> Observable<DeviceReadResult> {
        return getNumOfLogs()
            .flatMap { [weak self] result -> Observable<DeviceReadResult> in
                
                guard let self = self else {
                    return .just(.failure(error: "Manager released"))
                }
                
                switch result {
                    
                case .failure:
                    return .just(result)
                    
                case .noDiveData:
                    PrintLog("📭 No dive data")
                    return .just(.noDiveData)
                    
                case .success:
                    
                    PrintLog("🚀 Start downloading \(self.numOfLogs) logs")
                    
                    let totalLogs = Int(self.numOfLogs)
                        
                        let observables = (0..<totalLogs).map { logId in
                            return self.sendGetLog(logIndex: logId, onProgress: { percent in
                                // ✅ Hiển thị: Downloading dive 1/10 (45%)
                                let statusMessage = String(format: "%@ %d/%d (%d%%)",
                                                           "Downloading dive".localized,
                                                           logId + 1,
                                                           totalLogs,
                                                           percent)
                                
                                // Cập nhật lên UI thread
                                DispatchQueue.main.async {
                                    ProgressHUD.animate(statusMessage)
                                }
                            })
                        }
                    
                    return Observable.concat(observables)
                        .toArray()
                        .map { records in
                            // Lọc bỏ nil để chỉ còn lại những log thực sự được tải về
                            let newDownloadedRecords = records.compactMap { $0 }
                                                        
                            newDownloadedRecords.forEach { record in
                                do { try self.U_ConvertDives(record) } catch { }
                            }
                            
                            return newDownloadedRecords.isEmpty ? .noDiveData : .success
                        }
                        .asObservable()
                }
            }
    }
    
    func getNumOfLogs() -> Observable<DeviceReadResult> {
        
        let cmd = BleCommandKey.kNumOfLog
        
        return sendSimpleCommandWithResponse(
            command: cmd.bleCommand.mainCmd.rawValue,
            subcommand: cmd.bleCommand.subCmd,
            rw: BleType.read.rawValue,
            payload: [0x00, 0x00]
        )
        .flatMap { [weak self] response -> Observable<DeviceReadResult> in
            
            guard let self = self else {
                return .just(.failure(error: "Manager released"))
            }
            
            if let error = response.error {
                return .just(.failure(error: error.localizedDescription))
            }
            
            let value = response.data.extractInt16(fromOffset: 0, endian: .big)
            numOfLogs = Int(value)
            
            PrintLog("📒 NumOfLog = \(numOfLogs)")
            
            return .just(numOfLogs == 0 ? .noDiveData : .success)
        }
        .catch { error in
                .just(.failure(error: error.localizedDescription))
        }
    }
    
    private func sendGetLog(logIndex: Int, onProgress: ((Int) -> Void)? = nil) -> Observable<DiveRecord?> {
        
        if DatabaseManager.shared.isExistDiveLog(diveNo: logIndex, modelId: self.ModelID, serialNo: self.SerialNo) {
            return .just(nil)
        }
        
        return sendSimpleCommandWithResponse(
            command: 0x43,
            subcommand: 0x31,
            rw: BleType.read.rawValue,
            payload: [0x00, 0x02, UInt8(logIndex >> 8), UInt8(logIndex & 0xFF)]
        )
        .flatMap { [weak self] response -> Observable<Data> in
            guard let self = self else { return .error(NSError(domain: "BLE", code: -1)) }
            if let error = response.error { return .error(error) }
            
            let data = response.data
            guard data.count >= 10 else { return .error(NSError(domain: "BLE", code: -2)) }
            
            let segments = data.extractUInt16(fromOffset: 8, endian: .big)
            var fullData = Data()
            
            // Tạo mảng các observable download từng segment
            let steps = (0..<segments).map { segment in
                return self.sendSimpleCommandWithResponse(
                    command: 0x43,
                    subcommand: 0x41,
                    rw: BleType.read.rawValue,
                    payload: [0x00, 0x04,
                              UInt8(logIndex >> 8), UInt8(logIndex & 0xFF),
                              UInt8(segment >> 8), UInt8(segment & 0xFF)]
                )
                .map { response -> Void in
                    if let error = response.error { throw error }
                    fullData.append(response.data)
                    
                    // ✅ Tính toán % dựa trên segment hiện tại
                    let currentSegment = Int(segment) + 1
                    let totalSegments = Int(segments)
                    let percent = (currentSegment * 100) / totalSegments
                    onProgress?(percent) // Gọi callback báo phần trăm về
                    
                    return ()
                }
            }
            
            return self.runSequential(steps.map { step in { step } })
                .map { _ in fullData }
        }
        .flatMap { [weak self] fullData -> Observable<DiveRecord?> in
            guard let self = self else { return .error(NSError(domain: "BLE", code: -4)) }
            
            return self.sendSimpleCommandWithResponse(
                command: 0x43, subcommand: 0x42, rw: BleType.read.rawValue, payload: [0x00, 0x00]
            )
            .map { response in
                if let error = response.error { throw error }
                return DiveRecord(diveNo: logIndex, logData: fullData, profiles: [])
            }
        }
    }
    
    private func downloadSingleLog(at index: UInt16) -> Observable<Data> {
        
        PrintLog("📥 Start log \(index)")
        
        // STEP 1️⃣ 0x31 - Metadata
        
        return sendSimpleCommandWithResponse(
            command: 0x43,
            subcommand: 0x31,
            rw: BleType.read.rawValue,
            payload: [
                0x00, 0x02,
                UInt8(index >> 8),
                UInt8(index & 0xFF)
            ]
        )
        
        .flatMap { response -> Observable<(String, UInt32, UInt16)> in
            
            if let error = response.error {
                return .error(error)
            }
            
            let data = response.data
            
            guard data.count >= 10 else {
                return .error(NSError(domain: "BLE", code: -2))
            }
            
            let fileNameData = data.subdata(in: 0..<4)
            let fileName = fileNameData.asciiString ?? ""
            
            let logSize  = data.extractUInt32(fromOffset: 4, endian: .big)
            let segments = data.extractUInt16(fromOffset: 8, endian: .big)
            
            PrintLog("📂 name=\(fileName) size=\(logSize) segments=\(segments)")
            
            return .just((fileName, logSize, segments))
        }
        
        // STEP 2️⃣ 0x41 - Download segments
        
        .flatMap { [weak self] (_, _, segmentCount) -> Observable<Data> in
            
            guard let self = self else {
                return .error(NSError(domain: "BLE", code: -3))
            }
            
            var fullData = Data()
            
            let segmentIndexes = Array(0..<segmentCount)
            
            let steps: [() -> Observable<Void>] = segmentIndexes.map { segment in
                
                return {
                    self.sendSimpleCommandWithResponse(
                        command: 0x43,
                        subcommand: 0x41,
                        rw: BleType.read.rawValue,
                        payload: [
                            0x00, 0x04,
                            UInt8(index >> 8),
                            UInt8(index & 0xFF),
                            UInt8(segment >> 8),
                            UInt8(segment & 0xFF)
                        ]
                    )
                    .flatMap { response -> Observable<Void> in
                        
                        if let error = response.error {
                            return .error(error)
                        }
                        
                        fullData.append(response.data)
                        
                        PrintLog("   ↳ segment \(segment) size \(response.data.count)")
                        
                        return .just(())
                    }
                }
            }
            
            return self.runSequential(steps)
                .map { fullData }
        }
        
        // STEP 3️⃣ 0x42 - Finish
        
        .flatMap { [weak self] fullData -> Observable<Data> in
            
            guard let self = self else {
                return .error(NSError(domain: "BLE", code: -4))
            }
            
            return self.sendSimpleCommandWithResponse(
                command: 0x43,
                subcommand: 0x42,
                rw: BleType.read.rawValue,
                payload: [0x00, 0x00]
            )
            .flatMap { response -> Observable<Data> in
                
                if let error = response.error {
                    return .error(error)
                }
                
                PrintLog("✅ Finish log")
                
                return .just(fullData)
            }
        }
    }
}

extension BluetoothDeviceCRManager.BleCommandKey {
    var defaultPayload: [UInt8] {
        switch self {
        case .kDepthAlarm, .kTimeAlarm:
            return [0xFF]
        default:
            return []
        }
    }
    
    var readPayloads: [[UInt8]] {
        switch self {
        case .kDepthAlarm, .kTimeAlarm:
            return [[0xFF], [0x00]]
        default:
            return [defaultPayload]
        }
    }
}

extension BluetoothDeviceCRManager.BleCommandKey {
    // Chuyển đổi giá trị từ DB sang payload cho lệnh Write
    func getWritePayload(from row: Row, units: Int) -> [UInt8]? {
        switch self {
        case .kUnit:
            return [row.uint8Value(key: "Units")]
        case .kTimeFormat:
            return [row.uint8Value(key: "TimeFormat")]
        case .kDiveWaterType:
            return [row.uint8Value(key: "WaterDensity")]
        case .kDiveMode:
            return [row.uint8Value(key: "DiveMode")]
        case .kDiveO2:
            return [row.uint8Value(key: "FO2")]
        case .kDivePO2:
            return [row.uint8Value(key: "PO2")]
        case .kConservatism:
            return [row.uint8Value(key: "Conservatism")]
        case .kDepthAlarm:
            return [0x00, row.uint8Value(key: "DepthAlarmM")]
        case .kTimeAlarm:
            return [0x00, row.uint8Value(key: "DiveTimeAlarmMin")]
        case .kSamplingRate:
            return [row.uint8Value(key: "DiveLogSamplingTime")]
        case .kLogStartDepth:
            return [row.uint8Value(key: "LogStartDepth")]
        case .kLogStopTime:
            return [row.uint8Value(key: "LogStopTime")]
        case .kDeepStopAlarm:
            return [row.uint8Value(key: "DeepStopOn")]
        default:
            return nil // Các trường như SerialNumber, FirmwareRev thường là Read-only
        }
    }
    
    func getWritePayloads(from row: Row, units: Int) -> [[UInt8]]? {
        switch self {
            
        case .kDepthAlarm:
            let value = row.uint8Value(key: "DepthAlarmM")
            
            if value == 0 {
                // OFF → chỉ write ON/OFF
                return [
                    [0xFF, 0x00]
                ]
            } else {
                // ON → write ON trước, rồi write VALUE
                return [
                    [0xFF, 0x01],
                    [0x00, value]
                ]
            }
            
        case .kTimeAlarm:
            let value = row.uint8Value(key: "DiveTimeAlarmMin")
            
            if value == 0 {
                return [
                    [0xFF, 0x00]
                ]
            } else {
                return [
                    [0xFF, 0x01],
                    [0x00, value]
                ]
            }
            
        default:
            if let single = getWritePayload(from: row, units: units) {
                return [single]
            }
            return nil
        }
    }
}

extension BluetoothDeviceCRManager {
    // HELPER
    
    
    private func formatDiveDate(_ date: Date, timezoneOffset: Int) -> String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        
        if let tz = TimeZone(secondsFromGMT: timezoneOffset * 3600) {
            formatter.timeZone = tz
        }
        
        return formatter.string(from: date)
    }
    
}

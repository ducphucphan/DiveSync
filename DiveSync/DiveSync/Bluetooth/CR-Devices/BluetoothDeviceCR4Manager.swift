import Foundation
import GRDB
import ProgressHUD
import CoreBluetooth
import RxBluetoothKit
import RxSwift


final class BluetoothDeviceCR4Manager {
    
    struct BleCommand {
        let mainCmd: MainCmd
        let subCmd: UInt8
        let indexed: Bool
        let payloadLen: Int
    }
    
    struct BleResponse {
        let data: Data
        let error: Error?
    }
    
    // ============================================
    // MARK: - BLE Protocol Definition
    // ============================================
    
    enum MainCmd: UInt8 {
        case A0 = 0xA0
        case B0 = 0xB0
        case C0 = 0xC0
    }
    
    enum BleType: UInt8 {
        case read  = 0x01
        case write = 0x00
    }
    
    enum BleCommandKey: String, Hashable, CaseIterable {
        case kSerialNumber
        case kFirmwareRev
        
        case kUnit
        
        case kTimeFormat
        case kDateFormat
        case kSetTime
        case kSetDate
        case kTimeZone
        
        case kSetAutoDiveType
        case kNitroxSetting
        case kPPO2Setting
        
        case kSafetyFactorSetting
        case kScubaDepthAlarm
        case kScubaTimeAlarm
        case kThresholdScubaDepthAlarm
        case kThresholdScubaTimeAlarm
        
        case kSamplingRate
        case kScubaAutoStartDepth
        case kScubaLogStopTime
        case kGSensorFunction
        
        case kFreeDiveTimeAlarm
        case kFreeDiveDepthAlarm
        case kFreeDiveSurfaceTimeAlarm
        
        case kFreeDiveTimeAlarmThreshold1
        case kFreeDiveTimeAlarmThreshold2
        case kFreeDiveTimeAlarmThreshold3
        
        case kFreeDiveDepthAlarmThreshold1
        case kFreeDiveDepthAlarmThreshold2
        case kFreeDiveDepthAlarmThreshold3
        
        case kFreeDiveSurfaceTimeAlarmThreshold1
        case kFreeDiveSurfaceTimeAlarmThreshold2
        case kFreeDiveSurfaceTimeAlarmThreshold3
        
        case kSetPower
        case kLanguage
        case kBacklightLevel
        case kBuzzer
        case kVibration
        
        // HISTOTY
        case kTotalScubaDivingTime
        case kMaximumDivingDepthofScubadives
        case kTotalScubaDives
        case kTotalFreeDiving
        case kFreeDivingforTheLongestTime
        case kFreeDivingDeepestDepth
        
        // LOGS
        case kGetLastDiveLogNumber
        case kGetCompactLogHeader
        case kGetFullLogHeader
        case kGetLogIndexData
        
        // SPECIAL
        case kSYS_SETTING_WRITE
        case kSYS_SETTING_READ
        
        var bleCommand: BleCommand {
            switch self {
            case .kFirmwareRev:
                return .init(mainCmd: .A0, subCmd: 0x01, indexed: false, payloadLen: 6)
            case .kSerialNumber:
                return .init(mainCmd: .A0, subCmd: 0x03, indexed: false, payloadLen: 12)
                
            case .kSetDate:
                return .init(mainCmd: .B0, subCmd: 0x01, indexed: false, payloadLen: 3)
            case .kDateFormat:
                return .init(mainCmd: .B0, subCmd: 0x02, indexed: false, payloadLen: 1)
            case .kSetTime:
                return .init(mainCmd: .B0, subCmd: 0x03, indexed: false, payloadLen: 3)
            case .kTimeFormat:
                return .init(mainCmd: .B0, subCmd: 0x04, indexed: false, payloadLen: 1)
                
            case .kSetAutoDiveType:
                return .init(mainCmd: .B0, subCmd: 0x05, indexed: false, payloadLen: 1)
            case .kNitroxSetting:
                return .init(mainCmd: .B0, subCmd: 0x06, indexed: false, payloadLen: 1)
            case .kPPO2Setting:
                return .init(mainCmd: .B0, subCmd: 0x07, indexed: false, payloadLen: 1)
            case .kSafetyFactorSetting:
                return .init(mainCmd: .B0, subCmd: 0x08, indexed: false, payloadLen: 1)
            case .kScubaDepthAlarm:
                return .init(mainCmd: .B0, subCmd: 0x09, indexed: false, payloadLen: 1)
            case .kScubaTimeAlarm:
                return .init(mainCmd: .B0, subCmd: 0x0A, indexed: false, payloadLen: 1)
            case .kThresholdScubaDepthAlarm:
                return .init(mainCmd: .B0, subCmd: 0x0B, indexed: false, payloadLen: 1)
            case .kThresholdScubaTimeAlarm:
                return .init(mainCmd: .B0, subCmd: 0x0C, indexed: false, payloadLen: 1)
                
            case .kSamplingRate:
                return .init(mainCmd: .B0, subCmd: 0x0D, indexed: false, payloadLen: 1)
            case .kScubaAutoStartDepth:
                return .init(mainCmd: .B0, subCmd: 0x0E, indexed: false, payloadLen: 1)
            case .kScubaLogStopTime:
                return .init(mainCmd: .B0, subCmd: 0x0F, indexed: false, payloadLen: 1)
            case .kGSensorFunction:
                return .init(mainCmd: .B0, subCmd: 0x10, indexed: false, payloadLen: 1)
            
            case .kFreeDiveTimeAlarm:
                return .init(mainCmd: .B0, subCmd: 0x11, indexed: false, payloadLen: 1)
            case .kFreeDiveDepthAlarm:
                return .init(mainCmd: .B0, subCmd: 0x12, indexed: false, payloadLen: 1)
            case .kFreeDiveSurfaceTimeAlarm:
                return .init(mainCmd: .B0, subCmd: 0x13, indexed: false, payloadLen: 1)
            
            case .kFreeDiveTimeAlarmThreshold1:
                return .init(mainCmd: .B0, subCmd: 0x14, indexed: false, payloadLen: 2)
            case .kFreeDiveTimeAlarmThreshold2:
                return .init(mainCmd: .B0, subCmd: 0x15, indexed: false, payloadLen: 2)
            case .kFreeDiveTimeAlarmThreshold3:
                return .init(mainCmd: .B0, subCmd: 0x16, indexed: false, payloadLen: 2)
            
            case .kFreeDiveDepthAlarmThreshold1:
                return .init(mainCmd: .B0, subCmd: 0x17, indexed: false, payloadLen: 2)
            case .kFreeDiveDepthAlarmThreshold2:
                return .init(mainCmd: .B0, subCmd: 0x18, indexed: false, payloadLen: 2)
            case .kFreeDiveDepthAlarmThreshold3:
                return .init(mainCmd: .B0, subCmd: 0x19, indexed: false, payloadLen: 2)
            
            case .kFreeDiveSurfaceTimeAlarmThreshold1:
                return .init(mainCmd: .B0, subCmd: 0x1A, indexed: false, payloadLen: 1)
            case .kFreeDiveSurfaceTimeAlarmThreshold2:
                return .init(mainCmd: .B0, subCmd: 0x1B, indexed: false, payloadLen: 1)
            case .kFreeDiveSurfaceTimeAlarmThreshold3:
                return .init(mainCmd: .B0, subCmd: 0x1C, indexed: false, payloadLen: 1)
                
            case .kUnit:
                return .init(mainCmd: .B0, subCmd: 0x1D, indexed: false, payloadLen: 1)
            case .kSetPower:
                return .init(mainCmd: .B0, subCmd: 0x1E, indexed: false, payloadLen: 1)
            case .kTimeZone:
                return .init(mainCmd: .B0, subCmd: 0x1F, indexed: false, payloadLen: 1)
                
            case .kBuzzer:
                return .init(mainCmd: .B0, subCmd: 0x20, indexed: false, payloadLen: 1)
            case .kBacklightLevel:
                return .init(mainCmd: .B0, subCmd: 0x21, indexed: false, payloadLen: 1)
            case .kVibration:
                return .init(mainCmd: .B0, subCmd: 0x22, indexed: false, payloadLen: 1)
            
            case .kLanguage:
                return .init(mainCmd: .B0, subCmd: 0x30, indexed: false, payloadLen: 1)
                
            case .kTotalScubaDivingTime:
                return .init(mainCmd: .A0, subCmd: 0x06, indexed: false, payloadLen: 4)
            case .kMaximumDivingDepthofScubadives:
                return .init(mainCmd: .A0, subCmd: 0x07, indexed: false, payloadLen: 2)
            case .kTotalScubaDives:
                return .init(mainCmd: .A0, subCmd: 0x08, indexed: false, payloadLen: 2)
            case .kTotalFreeDiving:
                return .init(mainCmd: .A0, subCmd: 0x09, indexed: false, payloadLen: 2)
            case .kFreeDivingforTheLongestTime:
                return .init(mainCmd: .A0, subCmd: 0x0A, indexed: false, payloadLen: 2)
            case .kFreeDivingDeepestDepth:
                return .init(mainCmd: .A0, subCmd: 0x0B, indexed: false, payloadLen: 2)
                
            case .kGetLastDiveLogNumber:
                return .init(mainCmd: .A0, subCmd: 0x04, indexed: false, payloadLen: 2)
            case .kGetCompactLogHeader:
                return .init(mainCmd: .C0, subCmd: 0x01, indexed: false, payloadLen: 36)
            case .kGetFullLogHeader:
                return .init(mainCmd: .C0, subCmd: 0x02, indexed: false, payloadLen: 156)
            case .kGetLogIndexData:
                return .init(mainCmd: .C0, subCmd: 0x03, indexed: false, payloadLen: 128)
                
            case .kSYS_SETTING_WRITE:
                return .init(mainCmd: .B0, subCmd: 0x27, indexed: false, payloadLen: 0)
            case .kSYS_SETTING_READ:
                return .init(mainCmd: .B0, subCmd: 0x28, indexed: false, payloadLen: 0)
                
            
            }
        }
        
        static func from(mainCmd: UInt8, subCmd: UInt8) -> BleCommandKey? {
            // Duyệt qua tất cả các cases của enum
            // Lưu ý: Enum của bạn cần kế thừa CaseIterable để dùng .allCases
            return BleCommandKey.allCases.first { key in
                let cmd = key.bleCommand
                return cmd.mainCmd.rawValue == mainCmd && cmd.subCmd == subCmd
            }
        }
    }
    
    struct BleWriteConfig {
        let payload: [UInt8]
        let isReserved: Bool
        let indexes: Int?
        
        init(payload: [UInt8], isReserved: Bool, index: Int? = -1) {
            self.payload = payload
            self.isReserved = isReserved
            self.indexes = index
        }
    }
    
    // ============================================
    // MARK: - Properties
    // ============================================
    
    let scannedPeripheral: ScannedPeripheral
    
    private let disposeBag = DisposeBag()
    
    private let compositeDisposable = CompositeDisposable()
    
    private let notifySubject = PublishSubject<(uuid: CBUUID, data: Data)>()
    
    typealias ReadStep = () -> Observable<Void>
    
    // Device info cache
    var firmwareRev = ""
    var SerialNo = ""
    var ModelID = 0
    
    var currentDateFormat = -1
    var currentTimeFormat = -1
    
    private var numOfLogs: Int = 0
    private var units: Int = M
    
    private var responses: [BleCommandKey: [BleResponse]] = [:]
    
    private var currentDeviceTimeZone = 0.0
    
    private var writeCharacteristic: Characteristic?
    private var indicateCharacteristic: Characteristic?
    private var directoryAllFileChar: Characteristic?
    private var readDataChar: Characteristic?
    private var notifyCharacteristics: [CBUUID: Characteristic] = [:]
    
    private var discoveredChars: [Characteristic] = []
    private var enabledUUIDs = Set<CBUUID>()
    
    
    
    let timezoneOffsets: [Double] = [-12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1, +0, +1, +2, +3, +4, +5, +6, +7, +8, +9, +10, +11, +12]
    
    var logStatistics: [String: Any] = [:]
    
    
    // ============================================
    // MARK: - Init / Deinit
    // ============================================
    
    init(scannedPeripheral: ScannedPeripheral) {
        self.scannedPeripheral = scannedPeripheral
    }
    
    func dispose() {
        compositeDisposable.dispose()
    }
    
    // ============================================
    // MARK: - BLE Discovery & Notify
    // ============================================
    
    
    func discoverServicesAndCharacteristics(
        servicesUUID: [CBUUID],
        indicateCharUUID: CBUUID,
        notifyCharUUIDs: [CBUUID]
    ) -> Observable<Void> {
        
        self.enabledUUIDs.removeAll()
        self.discoveredChars.removeAll()
        self.notifyCharacteristics.removeAll()
        
        return scannedPeripheral.peripheral.discoverServices(servicesUUID)
            .asObservable()
        
        // duyệt từng service
            .flatMap { Observable.from($0) }
        
        // discover tất cả char cần dùng
            .flatMap { service in
                service.discoverCharacteristics([indicateCharUUID] + notifyCharUUIDs)
                    .asObservable()
            }
        
        // map char
            .do(onNext: { [weak self] characteristics in
                guard let self = self else { return }
                
                self.discoveredChars = characteristics
                self.notifyCharacteristics.removeAll()
                
                for char in characteristics {
                    PrintLog(char.uuid)
                    if char.uuid == indicateCharUUID {
                        self.writeCharacteristic = char
                        self.indicateCharacteristic = char
                        PrintLog("✅ Found Write/Indicate: \(char.uuid)")
                    }
                    
                    if char.uuid == BLEConstants.RWCharCR5.notify1 {
                        self.directoryAllFileChar = char
                    }
                    
                    if char.uuid == BLEConstants.RWCharCR5.notify2 {
                        self.readDataChar = char
                    }
                    
                    if notifyCharUUIDs.contains(char.uuid) {
                        self.notifyCharacteristics[char.uuid] = char
                    }
                }
            })
        
        // enable notify + indicate
            .flatMap { [weak self] _ in
                guard let self = self else { return Observable<Void>.empty() }
                
                let uuids = [indicateCharUUID] + notifyCharUUIDs
                
                uuids.forEach {
                    _ = self.enableNotifyObservable(for: $0)
                }
                
                // delay nhẹ để BLE ready
                return Observable.just(())
                    .delay(.milliseconds(200), scheduler: MainScheduler.instance)
                
            }
    }
    
    private func enableNotifyObservable(for uuid: CBUUID) -> Observable<Void> {
        
        // tránh enable nhiều lần
        if enabledUUIDs.contains(uuid) {
            return .just(())
        }
        
        guard let char = discoveredChars.first(where: { $0.uuid == uuid }) else {
            PrintLog("❌ Không tìm thấy char: \(uuid)")
            return .empty()
        }
        
        guard char.properties.contains(.notify) || char.properties.contains(.indicate) else {
            PrintLog("❌ Char không hỗ trợ notify/indicate: \(uuid)")
            return .empty()
        }
        
        enabledUUIDs.insert(uuid)
                
        let disposable = char.observeValueUpdateAndSetNotification()
            .compactMap { $0.value }
            .subscribe(onNext: { [weak self] data in
                PrintLog("📥 [\(uuid.uuidString)]: \(data.hexString)")
                self?.notifySubject.onNext((uuid: uuid, data: data))
            })
        
        _ = compositeDisposable.insert(disposable)
        
        return .just(())
    }
    
    func waitForResponse() -> Observable<Data> {
        return notifySubject
            .map { $0.data }
            .take(1)
            .timeout(.seconds(5), scheduler: MainScheduler.instance)
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
        isReserved: Bool = true,
        index: Int? = -1,
        payload: [UInt8] = []
    ) -> Observable<Void> {
        
        guard let characteristic = writeCharacteristic else {
            return Observable.error(
                NSError(domain: "Bluetooth", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Write characteristic not found"])
            )
        }
        
        let dataLength = payload.count
        
        let sentence = CommandSentence(
            commandGroup: command,
            subCommand: subcommand,
            directionWR: rw,
            reserved: isReserved,
            index: index,
            data: payload,
            dateLen: dataLength
        )
        let bytes = sentence.getBytes()
        let dataToSend = Data(bytes)
        
        if rw == BleType.write.rawValue {
            PrintLog("📤 SEND WRITE: \(dataToSend.hexString)")
        } else {
            PrintLog("📤 SEND READ: \(dataToSend.hexString)")
        }
        
        return scannedPeripheral.peripheral.writeValue(dataToSend, for: characteristic, type: .withoutResponse)
            .asObservable()
            .map { _ in return () }
    }
    
    func sendSimpleCommandWithResponse(
        command: UInt8,
        subcommand: UInt8,
        rw: UInt8,
        isReserved: Bool = true,
        index: Int? = -1,
        payload: [UInt8] = []
    ) -> Observable<BleResponse> {
        sendSimpleCommand(
            command: command,
            subcommand: subcommand,
            rw: rw,
            isReserved: isReserved,
            index: index,
            payload: payload,
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
    
    // RESPONSE FORMAT
    private func parseResponse(_ data: Data) throws -> Data? {
        let bytes = [UInt8](data)
        
        // Tối thiểu phải có 5 bytes: Cmd, Sub, R/W, Len, Checksum (ngay cả khi data len = 0)
        guard bytes.count >= 5 else {
            return nil
        }
        
        // 1. Xác định Command gốc (Request = Response - 1)
        let commandByte = bytes[0] - 1
        let subByte = bytes[1]
        // let rwByte = bytes[2] // Thường là 0x00 (Write) hoặc 0x01 (Read)
        
        // 2. Lấy độ dài data được khai báo trong gói tin
        let dataLength = Int(bytes[3])
        
        // 3. Kiểm tra tính toàn vẹn (Checksum) - Tùy chọn nhưng nên có
        // Checksum = ~ (command + subcommand + rw + length + data) [cite: 48]
        let expectedChecksum = bytes.last!
        var sum: UInt8 = 0
        // Tính tổng các byte từ index 0 đến trước byte checksum cuối cùng
        for i in 0..<(bytes.count - 1) {
            sum = sum &+ bytes[i] // Sử dụng &+ để xử lý tràn số (overflow) tương đương uint8
        }
        let calculatedChecksum = ~sum
        
        if calculatedChecksum != expectedChecksum {
            print("❌ Checksum mismatch! Calc: \(calculatedChecksum), Expected: \(expectedChecksum)")
            // return nil // Bạn có thể bỏ comment nếu muốn chặn dữ liệu sai
        }

        // 4. Trích xuất Payload
        // Theo spec, data bắt đầu từ index 4 [cite: 40]
        let dataStartPos = 4
        let dataEndPos = dataStartPos + dataLength
        
        // Kiểm tra an toàn để không cắt mảng vượt quá độ dài thực tế nhận được
        if bytes.count >= dataEndPos + 1 { // +1 cho byte checksum
            let payloadData = Data(bytes[dataStartPos..<dataEndPos])
            
            // Debug
            if let commandKey = BleCommandKey.from(mainCmd: commandByte, subCmd: subByte) {
                print("Command: \(commandKey), Data Len: \(dataLength), Payload: \(payloadData as NSData)")
            }
            
            return payloadData
        }
        
        return nil
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
            .kSYS_SETTING_READ,
            .kSerialNumber,
            .kFirmwareRev,
            
            .kTimeFormat,
            .kDateFormat,
            .kTimeZone,
            .kSetDate,
            .kSetTime,
            
            .kUnit,
            .kLanguage,
            .kBuzzer,
            .kVibration,
            .kSetPower,
            .kSetAutoDiveType,
            .kScubaAutoStartDepth,
            
            .kNitroxSetting,
            .kPPO2Setting,
            .kSafetyFactorSetting,
            .kSamplingRate,
            .kBacklightLevel,
            
            .kScubaDepthAlarm,
            .kThresholdScubaDepthAlarm,
            .kScubaTimeAlarm,
            .kThresholdScubaTimeAlarm,
            
            .kFreeDiveTimeAlarm,
            .kFreeDiveTimeAlarmThreshold1,
            .kFreeDiveTimeAlarmThreshold2,
            .kFreeDiveTimeAlarmThreshold3,
            
            .kFreeDiveDepthAlarm,
            .kFreeDiveDepthAlarmThreshold1,
            .kFreeDiveDepthAlarmThreshold2,
            .kFreeDiveDepthAlarmThreshold3,
            
            .kFreeDiveSurfaceTimeAlarm,
            .kFreeDiveSurfaceTimeAlarmThreshold1,
            .kFreeDiveSurfaceTimeAlarmThreshold2,
            .kFreeDiveSurfaceTimeAlarmThreshold3,
            
            .kTotalScubaDivingTime,
            .kMaximumDivingDepthofScubadives,
            .kTotalScubaDives,
            .kTotalFreeDiving,
            .kFreeDivingforTheLongestTime,
            //.kFreeDivingDeepestDepth
        ]
        
        let steps: [ReadStep] = commands.flatMap { cmd in
            
            cmd.readPayloads.map { payload in
                
                return {
                    self.sendSimpleCommandWithResponse(
                        command: cmd.bleCommand.mainCmd.rawValue,
                        subcommand: cmd.bleCommand.subCmd,
                        rw: (cmd == .kSYS_SETTING_READ) ? BleType.write.rawValue : BleType.read.rawValue,
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
                        
                        if let first = responses[.kTimeZone]?.first {
                            let rawIndex = first.data.toInt()
                            if rawIndex >= 0 && rawIndex < timezoneOffsets.count {
                                let deviceOffset = timezoneOffsets[rawIndex]
                                self.currentDeviceTimeZone = deviceOffset
                                print("Device đang ở múi giờ: UTC \(deviceOffset)")
                            }
                        }
                        
                    })
                    .map { _ in () }
                }
            }
        }
        
        
        
        runSequential(steps)
            .do(onError: { print("Lỗi xuất hiện từ runSequential: \($0)") })
            .flatMap { [weak self] _ -> Observable<DeviceReadResult> in
                guard let self else {
                    return .error("" as! Error)
                }
                
                if let list = responses[.kSerialNumber], let first = list.first {
                    let trimmedData = first.data
                    
                    // Lọc bỏ các byte không phải ASCII chuẩn (như byte BA) trước khi chuyển sang String
                    let cleanData = trimmedData.filter { $0 >= 32 && $0 <= 126 }
                    
                    self.SerialNo = cleanData.asciiString ?? ""
                    print("SerialNo = \(self.SerialNo)")
                }
                
                if let list = responses[.kFirmwareRev], let first = list.first {
                    let trimmedData = first.data
                    self.firmwareRev = trimmedData.asciiString ?? ""
                    print("firmwareRev = \(self.firmwareRev)")
                }
                
                switch syncType {
                case .kUploadDateTime:
                    return self.U_WriteTimeSync()
                case .kUploadSetting:
                    return self.U_CR4WriteSetting()
                default:
                    return self.U_CR4SaveSetting()
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
                
                guard let m = BluetoothDeviceCoordinator.shared.cr4DeviceManager else { return }
                
                var props: [String: Any] = [
                    "ModelID": m.ModelID,
                    "SerialNo": m.SerialNo,
                    "Identity": m.scannedPeripheral.advertisementData.localName ?? "",
                    "LastSync": Utilities.getLastSyncText(date: Date()),
                    "Firmware": m.firmwareRev
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
                BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: "❗️\(error.localizedDescription.localized)")
            }).disposed(by: disposeBag)
    }
    
    // MARK: - PARSE DATA
    func U_CR4SaveSetting() -> Observable<DeviceReadResult> {
        
        if let (bleName, _) = scannedPeripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            self.ModelID = dcInfo[2].toInt()
        }
        
        var dcSettings: [String: Any] = [:]
        
        dcSettings["DeviceID"] = DatabaseManager.shared.lastDevicID(modelId: ModelID, serialNo: self.SerialNo)
        
        if let first = responses[.kSerialNumber]?.first {
            let cleanData = first.data.filter { $0 >= 32 && $0 <= 126 }
            self.SerialNo = cleanData.asciiString ?? ""
        }
        
        if let first = responses[.kTimeFormat]?.first{
            dcSettings["TimeFormat"] = first.data.toInt()
        }
        
        if let first = responses[.kDateFormat]?.first {
            dcSettings["DateFormat"] = first.data.toInt()
        }
        
        if let first = responses[.kTimeZone]?.first {
            dcSettings["TimeZone"] = first.data.toInt()
        }
        
        if let first = responses[.kUnit]?.first {
            units = first.data.toInt()
            dcSettings["Units"] = units
        }
        
        if let first = responses[.kLanguage]?.first {
            dcSettings["Language"] = first.data.toInt()
        }
        
        if let first = responses[.kBuzzer]?.first {
            dcSettings["BuzzerMode"] = first.data.toInt()
        }
        
        if let first = responses[.kVibration]?.first {
            dcSettings["Vibration"] = first.data.toInt()
        }
        
        if let first = responses[.kSetPower]?.first {
            dcSettings["PowerSaving"] = first.data.toInt()
        }
        
        if let first = responses[.kBacklightLevel]?.first {
            dcSettings["BacklightDimLevel"] = first.data.toInt()
        }
        
        if let first = responses[.kSetAutoDiveType]?.first {
            dcSettings["DiveMode"] = first.data.toInt()
        }
        
        if let first = responses[.kScubaAutoStartDepth]?.first {
            dcSettings["ScubaAutoStartDepth"] = first.data.toInt()
        }
        
        if let first = responses[.kNitroxSetting]?.first {
            dcSettings["FO2"] = first.data.toInt()
        }
        
        if let first = responses[.kPPO2Setting]?.first {
            dcSettings["PO2"] = first.data.toInt()
        }
        
        if let first = responses[.kSafetyFactorSetting]?.first {
            dcSettings["Conservatism"] = first.data.toInt()
        }
        
        if let first = responses[.kSamplingRate]?.first {
            dcSettings["DiveLogSamplingTime"] = first.data.toInt()
        }
        
        if let first = responses[.kScubaDepthAlarm]?.first {
            dcSettings["DepthAlarmEnable"] = first.data.toInt()
        }
        
        if let first = responses[.kThresholdScubaDepthAlarm]?.first {
            dcSettings["DepthAlarmM"] = first.data.toInt()
        }
        
        if let first = responses[.kScubaTimeAlarm]?.first {
            dcSettings["TimeAlarmEnable"] = first.data.toInt()
        }
        
        if let first = responses[.kThresholdScubaTimeAlarm]?.first {
            dcSettings["DiveTimeAlarmMin"] = first.data.toInt()
        }
        
        if let first = responses[.kFreeDiveDepthAlarm]?.first {
            dcSettings["FreeDiveDepthAlarmEnable"] = first.data.toInt()
        }
        
        if let first = responses[.kFreeDiveDepthAlarmThreshold1]?.first {
            dcSettings["FREE_DEPTH_ALARM1"] = first.data.u16LE(0)
        }
        
        if let first = responses[.kFreeDiveDepthAlarmThreshold2]?.first {
            dcSettings["FREE_DEPTH_ALARM2"] = first.data.u16LE(0)
        }
        
        if let first = responses[.kFreeDiveDepthAlarmThreshold3]?.first {
            dcSettings["FREE_DEPTH_ALARM3"] = first.data.u16LE(0)
        }
        ///
        
        if let first = responses[.kFreeDiveTimeAlarm]?.first {
            dcSettings["FreeDiveTimeAlarmEnable"] = first.data.toInt()
        }
        
        if let first = responses[.kFreeDiveTimeAlarmThreshold1]?.first {
            dcSettings["FREE_TIME_ALARM1"] = first.data.u16LE(0)
        }
        
        if let first = responses[.kFreeDiveTimeAlarmThreshold2]?.first {
            dcSettings["FREE_TIME_ALARM2"] = first.data.u16LE(0)
        }
        
        if let first = responses[.kFreeDiveTimeAlarmThreshold3]?.first {
            dcSettings["FREE_TIME_ALARM3"] = first.data.u16LE(0)
        }
        ///
        
        if let first = responses[.kFreeDiveSurfaceTimeAlarm]?.first {
            dcSettings["FreeDiveSurfaceTimeAlarmEnable"] = first.data.toInt()
        }
        
        if let first = responses[.kFreeDiveSurfaceTimeAlarmThreshold1]?.first {
            dcSettings["FREE_SI_ALARM1"] = first.data.toInt()
        }
        
        if let first = responses[.kFreeDiveSurfaceTimeAlarmThreshold2]?.first {
            dcSettings["FREE_SI_ALARM2"] = first.data.toInt()
        }
        
        if let first = responses[.kFreeDiveSurfaceTimeAlarmThreshold3]?.first {
            dcSettings["FREE_SI_ALARM3"] = first.data.toInt()
        }
        
        // HISTORY
        if let first = responses[.kTotalScubaDivingTime]?.first {
            let totalScubarTime = first.data.u32LE(0)
            PrintLog("totalScubarTime: \(totalScubarTime)")
        }
        if let first = responses[.kMaximumDivingDepthofScubadives]?.first {
            let maxDepth = first.data.u16LE(0)
            PrintLog("maxDepth: \(maxDepth)")
        }
        if let first = responses[.kTotalScubaDives]?.first {
            let totalScubaDives = first.data.u16LE(0)
            PrintLog("totalScubaDives: \(totalScubaDives)")
        }
        if let first = responses[.kTotalFreeDiving]?.first {
            let totalFreeDiving = first.data.u16LE(0)
            PrintLog("totalFreeDiving: \(totalFreeDiving)")
        }
        if let first = responses[.kFreeDivingforTheLongestTime]?.first {
            let freeDivingforTheLongestTime = first.data.u16LE(0)
            PrintLog("freeDivingforTheLongestTime: \(freeDivingforTheLongestTime)")
        }
        if let first = responses[.kFreeDivingDeepestDepth]?.first {
            let freeDivingDeepestDepth = first.data.u16LE(0)
            PrintLog("freeDivingDeepestDepth: \(freeDivingDeepestDepth)")
        }
        
        print(dcSettings)
        DatabaseManager.shared.saveDeviceSettings(modelId: self.ModelID, serialNo: self.SerialNo, dcSettings: dcSettings)
        
        return .just(.success)
    }
    
    func U_CR4WriteSetting() -> Observable<DeviceReadResult> {
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
            
            print("\(results)")
            
            let writeUnits = row.stringValue(key: "Units").toInt()
            
            // 3. Chuẩn bị danh sách lệnh ghi
            let commandsToWrite: [BleCommandKey] = [
                .kUnit,
                .kLanguage,
                .kSetPower,
                .kBacklightLevel,
                .kBuzzer,
                .kVibration,
                .kSetAutoDiveType,
                .kScubaAutoStartDepth,
                
                .kNitroxSetting,
                .kPPO2Setting,
                .kSafetyFactorSetting,
                .kScubaLogStopTime,
                .kSamplingRate,
                
                .kScubaDepthAlarm,
                .kScubaTimeAlarm,
                .kThresholdScubaDepthAlarm,
                .kThresholdScubaTimeAlarm,
                
                .kFreeDiveTimeAlarm,
                .kFreeDiveDepthAlarm,
                .kFreeDiveSurfaceTimeAlarm,
                
                .kFreeDiveTimeAlarmThreshold1,
                .kFreeDiveTimeAlarmThreshold2,
                .kFreeDiveTimeAlarmThreshold3,
                
                .kFreeDiveDepthAlarmThreshold1,
                .kFreeDiveDepthAlarmThreshold2,
                .kFreeDiveDepthAlarmThreshold3,
                
                .kFreeDiveSurfaceTimeAlarmThreshold1,
                .kFreeDiveSurfaceTimeAlarmThreshold2,
                .kFreeDiveSurfaceTimeAlarmThreshold3,
                
                .kSYS_SETTING_WRITE
                
            ]
            
            let steps: [ReadStep] = commandsToWrite.flatMap { cmd -> [ReadStep] in
                // Trường hợp đặc biệt cho lệnh xác nhận hệ thống
                if cmd == .kSYS_SETTING_WRITE {
                    let systemStep: ReadStep = {
                        self.sendSimpleCommandWithResponse(
                            command: cmd.bleCommand.mainCmd.rawValue,
                            subcommand: cmd.bleCommand.subCmd,
                            rw: BleType.write.rawValue,
                            payload: [], // Hoặc payload mặc định của lệnh xác nhận
                        )
                        .map { _ in () }
                    }
                    return [systemStep]
                }
                
                guard let configs = cmd.getWritePayloads(from: row, units: writeUnits) else {
                    return []
                }
                
                return configs.map { config -> ReadStep in
                    let step: ReadStep = {
                        self.sendSimpleCommandWithResponse(
                            command: cmd.bleCommand.mainCmd.rawValue,
                            subcommand: cmd.bleCommand.subCmd,
                            rw: BleType.write.rawValue,
                            isReserved: config.isReserved,
                            index: config.indexes,
                            payload:config.payload
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
        let headerSize = 548
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
        
        // 2. Firmware Version (Offset 0x022 - Byte 34, Size 6)
        let firmwareVersion = String(data: header[34..<40], encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? ""
        print("FIRMWARE VERSION: \(firmwareVersion)")
        
        // 3. Log Index (Offset 0x02A - Byte 42, Size 2)
        let logIndex = header.u16LE(42)
        divedata["DiveNo"] = logIndex
        divedata["ModelID"] = self.ModelID
        divedata["SerialNo"] = self.SerialNo
        
        divedata["DiveOfTheDay"] = logIndex // Do device không có trường để lấy DiveOfTheDay nên lưu tạm logindex
        
        // 4. Dive Mode (Offset 0x02C - Byte 44, Size 1)
        // 0: scuba, 1: gauge, 2: freedive, 3: TEC
        let diveType = header.u8(44)
        divedata["DiveMode"] = diveType
        
        divedata["Water"] = header.u8(45)
        
        // Timezone: Offset 0x04E (78)
        let startUTC = header.u32LE(56)       // Offset 0x038
        let duration = header.u16LE(50) // 1030 giây (Offset 0x032)
        let tzIndex = Int(header.u8(78))      // Offset 0x04E [cite: 4]

        let tzHours = (tzIndex >= 0 && tzIndex < timezoneOffsets.count) ? timezoneOffsets[tzIndex] : 0.0

        let endUTC = startUTC + duration

        let startDate = Date(timeIntervalSince1970: TimeInterval(startUTC))
        let endDate = Date(timeIntervalSince1970: TimeInterval(endUTC))

        divedata["DiveStartLocalTime"] = formatDiveDate(startDate, timezoneOffset: tzHours)
        divedata["DiveEndLocalTime"] = formatDiveDate(endDate, timezoneOffset: tzHours)
        
        divedata["TotalDiveTime"] = duration // Lưu giá trị 1030
        
        // 6. Depth (Offset 0x050 & 0x052) - Đơn vị: 100 = 1m
        let maxDepthRaw = header.u16LE(80)
        let maxDepth = Double(maxDepthRaw) / 100.0
        divedata["MaxDepthFT"] = convertMeter2Feet(maxDepth)
        
        let avgDepthRaw = header.u16LE(82)
        let avgDepth = Double(avgDepthRaw) / 100.0
        divedata["AvgDepthFT"] = convertMeter2Feet(avgDepth)
        
        // 7. Temperature (Offset 0x058) - Đơn vị: 0.1 C
        let tempMinRaw = header.u16LE(88)
        let tempMin = convertC2F(Double(tempMinRaw) / 10.0)
        divedata["MinTemperatureF"] = tempMin
        // Spec mới không ghi rõ MaxTemp, thường dùng MinTemp làm mốc môi trường
        divedata["MaxTemperatureF"] = tempMin
        
        // 8. Dive Time & Surface Interval
        // Dive Time (Offset 0x032 - 50): seconds (u16)
        //divedata["TotalDiveTime"] = UInt32(header.u16LE(50))
        
        // Surface Interval (Offset 0x034 - 52): seconds (u32)
        let surfTimeValue = header.u32LE(52)
        let limit24H: UInt32 = 86400 // 24 * 60 * 60
        if surfTimeValue > limit24H {
            divedata["SurfTime"] = 0
        } else {
            divedata["SurfTime"] = surfTimeValue
        }
        
        
        // 9. Sampling Rate (Offset 0x04F - 79): seconds (u8)
        let sampleRate = header.u8(79)
        divedata["SamplingTime"] = Int(sampleRate)
        
        let rawAscentRate = Double(header.u16LE(90)) / 100 //100 in 1 meter/sec (ref. salinity), 0 at surface
        let ftPerMin = convertMeter2Feet(rawAscentRate) * 60
        // Lưu vào Database (thường làm tròn 1 hoặc 2 chữ số thập phân tùy nhu cầu)
        let ascentRatevalueToSave = (ftPerMin * 100).rounded() / 100 // Kết quả: 82.68
        divedata["AscentSpeedAlarm"] = ascentRatevalueToSave
        
        let startNitroPressure = header.u16ArrayLE(144, count: 16)
        print("startNitroPressure: \(startNitroPressure)")
        
        let endNitroPressure = header.u16ArrayLE(208, count: 16)
        print("endNitroPressure: \(endNitroPressure)")
        
        let startHeliumPressure = header.u16ArrayLE(176, count: 16)
        print("startHeliumPressure: \(startHeliumPressure)")
        
        let endHeliumPressure = header.u16ArrayLE(240, count: 16)
        print("endHeliumPressure: \(endHeliumPressure)")
        
        // 10. Mark Counts (Dùng để debug/biết lượng profile data)
        print("hrMarkCount: \(header.u16LE(382))")
        print("depthMarkCount: \(header.u16LE(384))")
        print("alarmMarkCount: \(header.u16LE(386))")
        print("systemMarkCount: \(header.u16LE(396))")
        
        divedata["Mix1Fo2Percent"] = header.u8(125)
        divedata["Mix2Fo2Percent"] = header.u8(126)
        divedata["Mix3Fo2Percent"] = header.u8(127)
        divedata["Mix4Fo2Percent"] = header.u8(128)
        divedata["Mix5Fo2Percent"] = header.u8(129)
        
        divedata["Mix1FHePercent"] = header.u8(130)
        divedata["Mix2FHePercent"] = header.u8(131)
        divedata["Mix3FHePercent"] = header.u8(132)
        divedata["Mix4FHePercent"] = header.u8(133)
        divedata["Mix5FHePercent"] = header.u8(134)
        
        divedata["Mix1PpO2Barx100"] = header.u8(135)
        divedata["Mix2PpO2Barx100"] = header.u8(136)
        divedata["Mix3PpO2Barx100"] = header.u8(137)
        divedata["Mix4PpO2Barx100"] = header.u8(138)
        divedata["Mix5PpO2Barx100"] = header.u8(139)

        divedata["MaxPpo2"] = Double(header.u8(135)) / 10
        
        /*
         0 : Conserve   CF1 (35/75)
         1 : Normal       CF2 (40/85)
         2 : Aggressive CF3 (45/95)
         */
        divedata["GfHighPercent"] = header.u8(142)
        divedata["GfLowPercent"] = header.u8(143)
        
        let depthAlarmOffset = 280
        let rawDepth = data.u16(depthAlarmOffset)

        // Kiểm tra nếu báo động đang tắt (0xFFFF)
        let depthInMeters: Double = (rawDepth == 0xFFFF) ? 0.0 : Double(rawDepth) / 100.0

        if units == M {
            // Gán giá trị đơn lẻ (không để trong ngoặc vuông nếu bạn muốn lưu kiểu Double)
            divedata["DepthAlarmMT"] = depthInMeters
        } else {
            // Chuyển đổi sang Feet nếu đơn vị không phải là Mét
            divedata["DepthAlarmFT"] = convertMeter2Feet(depthInMeters)
        }
        
        let timeStartOffset = 290
        let rawTime = data.u16(timeStartOffset)

        // Kiểm tra nếu báo động tắt (0xFF hoặc 0xFFFF tùy theo thực tế thiết bị)
        // Đơn vị ở đây đã là giây (seconds) nên không cần chia 100
        let timeInSeconds: Int = (rawTime == 0xFFFF || rawTime == 0xFF) ? 0 : rawTime

        // Gán vào divedata
        divedata["DiveTimeAlarm"] = timeInSeconds
        
        // 11. Profile Length / Data Length (Offset 0x18E - 398)
        let dataLength = header.u16LE(398)
        print("DATA LENGTH: \(dataLength)")
        
        divedata["Units"] = units
        PrintLog(divedata)
        
        let rs = DatabaseManager.shared.saveDiveData(diveData: divedata)
        if rs.existed == true { return }
        
        // DIVE PROFILE
        // 12. DIVE PROFILE (Bắt đầu từ byte 548)
        let profileData = data.subdata(in: headerSize..<data.count)
        var offset = 0
        var diveTime = 0
        let samplingTime = divedata["SamplingTime"] as? Int ?? 0

        // Các biến tạm để giữ dữ liệu sự kiện cho đến khi gặp gói MT_DEPTH
        //var currentHeartRate: Int = 0
        var currentSpO2: Int = 0
        var currentAlarmID: Int = 0
        var decoStopDepth: Double = 0
        var decoTime: Int = 0
        var maxTemp = tempMinRaw
        
        while offset < profileData.count {
            let type = profileData.u8(offset)
            
            switch type {
            case 0x51: // MT_DEPTH (Size: 6 bytes)
                if offset + 6 <= profileData.count {
                    let depthRaw = profileData.u16LE(offset + 2) // depth in mBar
                    let tempRaw = profileData.u16LE(offset + 4)  // 0.1°C
                    
                    let depth = (Double(depthRaw) / 100.0) * 10.0
                    let temperature = Double(tempRaw)
                    
                    // Khởi tạo row với các thông số từ thiết bị cũ
                    var row: [String: Any] = [:]
                    row["DiveID"] = rs.diveID
                    row["DiveTime"] = diveTime
                    row["DepthFT"] = depth
                    row["TemperatureF"] = temperature
                    
                    if tempRaw > maxTemp { maxTemp = tempRaw }
                    
                    // Gán các giá trị tích lũy từ các gói khác (nếu có)
                    row["OxToxPercent"] = currentSpO2 // Ánh xạ SpO2 vào cột cũ nếu cần
                    row["AlarmID"] = currentAlarmID
                    row["DecoStopDepthFT"] = decoStopDepth
                    row["DecoTime"] = decoTime
                    
                    // LƯU VÀO DATABASE (Đúng lúc gặp gói Depth)
                    DatabaseManager.shared.saveDiveProfile(profile: row)
                    
                    // Tăng diveTime theo chu kỳ lấy mẫu
                    diveTime += samplingTime
                    offset += 6
                    
                    // Reset các biến chỉ xuất hiện theo sự kiện (tùy nhu cầu)
                    currentAlarmID = 0
                } else { offset = profileData.count }
                
            case 0x5B: // MT_HR (Size: 4 bytes)
                if offset + 4 <= profileData.count {
                    //currentHeartRate = Int(profileData.u8(offset + 2))
                    currentSpO2 = Int(profileData.u8(offset + 3))
                    offset += 4
                } else { offset = profileData.count }
                
            case 0x52: // MT_ALARM (Size: 8 bytes)
                if offset + 8 <= profileData.count {
                    currentAlarmID = Int(profileData.u8(offset + 1))
                    offset += 8
                } else { offset = profileData.count }
                
            case 0x54: // MT_DECO (Size: 8 bytes)
                if offset + 8 <= profileData.count {
                    let decoType = profileData.u8(offset + 1) // 0=deco state, 1=stop depth [cite: 4]
                    if decoType == 1 {
                        decoStopDepth = Double(profileData.u16LE(offset + 4)) // value1 [cite: 4, 5]
                        decoTime = Int(profileData.u16LE(offset + 6)) // value2 [cite: 5]
                    }
                    offset += 8
                } else { offset = profileData.count }
                
            case 0x58: // MT_TISSUE_N2 (Size: 36 bytes)
                offset += 36
                
            case 0x5F: // MT_SYSTEM (Size: 6 bytes)
                offset += 6
                
            default:
                offset += 1
            }
        }
        
        DatabaseManager.shared.updateTable(tableName: "DiveLog",
                                           params: ["MaxTemperatureF": convertC2F(Double(maxTemp) / 10.0)],
                                           conditions: "where DiveID=\(Int64(rs.diveID!))")
        
    }
    
    func U_WriteTimeSync() -> Observable<DeviceReadResult> {
        
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
            
            let systemTimeZoneOffset = getSystemTimeZoneIndex()
            
            let dateFormatValue = row.uint8Value(key: "DateFormat") // 0: yyyy.MM.dd, 1: MM.dd.yyyy, 2: dd.MM.yyyy
            
            var finalDate: Date
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
                
                // Xác định phần định dạng ngày dựa trên dateFormatValue
                var datePartFormat = ""
                switch dateFormatValue {
                case 0: datePartFormat = "yyyy.MM.dd"
                case 1: datePartFormat = "MM.dd.yyyy"
                case 2: datePartFormat = "dd.MM.yyyy"
                default: datePartFormat = "dd.MM.yyyy"
                }
                
                // Xác định phần định dạng giờ
                let timePartFormat = hasWhitespace ? "hh:mm a" : "HH:mm"
                
                formatter.dateFormat = "\(datePartFormat) \(timePartFormat)"
                
                let fullString = "\(dateString) \(timeString)"
                finalDate = formatter.date(from: fullString) ?? Date()
            }
            
            // =====================================================
            // 2️⃣ Chuẩn bị dữ liệu cho Date và Time (New Spec)
            // =====================================================
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: finalDate)
            
            // Year lấy 2 số cuối (ví dụ 2026 -> 26) theo spec [Year<100]
            let yearValue = UInt8((components.year ?? 2026) % 100)
            let monthValue = UInt8(components.month ?? 1)
            let dayValue = UInt8(components.day ?? 1)
            let hourValue = UInt8(components.hour ?? 0)
            let minuteValue = UInt8(components.minute ?? 0)
            let secondValue = UInt8(components.second ?? 0)
            
            let datePayload: [UInt8] = [yearValue, monthValue, dayValue]
            let timePayload: [UInt8] = [hourValue, minuteValue, secondValue]
            
            // =====================================================
            // 3️⃣ Build TimeFormat payload
            // =====================================================
            
            let timeFormatValue = row.uint8Value(key: "TimeFormat")
            let timeZoneValue = isSystem ? UInt8(systemTimeZoneOffset) : row.uint8Value(key: "TimeZone")
            
            let timeFormatPayload: [UInt8] = [timeFormatValue]
            let dateFormatPayload: [UInt8] = [dateFormatValue]
            let timeZonePayload: [UInt8] = [timeZoneValue]
            
            // =====================================================
            // 4️⃣ Create steps
            // =====================================================
            
            let timeFormatStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kTimeFormat.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kTimeFormat.bleCommand.subCmd,
                    rw: BleType.write.rawValue,   // ✅ WRITE
                    isReserved: false,
                    payload: timeFormatPayload
                )
                .map { _ in () }
            }
            
            let dateFormatStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kDateFormat.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kDateFormat.bleCommand.subCmd,
                    rw: BleType.write.rawValue,   // ✅ WRITE
                    isReserved: false,
                    payload: dateFormatPayload
                )
                .map { _ in () }
            }
            
            let timeZoneStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kTimeZone.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kTimeZone.bleCommand.subCmd,
                    rw: BleType.write.rawValue,   // ✅ WRITE
                    isReserved: false,
                    payload: timeZonePayload
                )
                .map { _ in () }
            }
            
            let setDateStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kSetDate.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kSetDate.bleCommand.subCmd,
                    rw: BleType.write.rawValue,   // ✅ WRITE
                    isReserved: false,
                    payload: datePayload
                )
                .map { _ in () }
            }
            
            let setTimeStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kSetTime.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kSetTime.bleCommand.subCmd,
                    rw: BleType.write.rawValue,   // ✅ WRITE
                    isReserved: false,
                    payload: timePayload
                )
                .map { _ in () }
            }
            
            let setSystemStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kSYS_SETTING_WRITE.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kSYS_SETTING_WRITE.bleCommand.subCmd,
                    rw: BleType.write.rawValue,   // ✅ WRITE
                    payload: []
                )
                .map { _ in () }
            }
            
            // =====================================================
            // 5️⃣ Run sequential (Format trước, Sync sau)
            // =====================================================
            
            var steps: [ReadStep] = [timeFormatStep, dateFormatStep, setDateStep, setTimeStep, setSystemStep]
            if isSystem {
                steps = [timeFormatStep, dateFormatStep, timeZoneStep, setDateStep, setTimeStep, setSystemStep]
            }
            
            return runSequential(steps)
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
                    
//                    PrintLog("🚀 Start downloading \(self.numOfLogs) logs")
//                    
//                    let totalLogs = Int(self.numOfLogs)
//                        
//                        let observables = (0..<totalLogs).map { logId in
//                            return self.sendGetLog(logIndex: logId, onProgress: { percent in
//                                // ✅ Hiển thị: Downloading dive 1/10 (45%)
//                                let statusMessage = String(format: "%@ %d/%d (%d%%)",
//                                                           "Downloading dive".localized,
//                                                           logId + 1,
//                                                           totalLogs,
//                                                           percent)
//                                
//                                // Cập nhật lên UI thread
//                                DispatchQueue.main.async {
//                                    ProgressHUD.animate(statusMessage)
//                                }
//                            })
//                        }
//                    
//                    return Observable.concat(observables)
//                        .toArray()
//                        .map { records in
//                            // Lọc bỏ nil để chỉ còn lại những log thực sự được tải về
//                            let newDownloadedRecords = records.compactMap { $0 }
//                                                        
//                            newDownloadedRecords.forEach { record in
//                                do { try self.U_ConvertDives(record) } catch { }
//                            }
//                            
//                            return newDownloadedRecords.isEmpty ? .noDiveData : .success
//                        }
//                        .asObservable()
                    
                    return .just(.success)
                    
                }
            }
    }
    
    func getNumOfLogs() -> Observable<DeviceReadResult> {
        
        let cmd = BleCommandKey.kGetLastDiveLogNumber
        
        return sendSimpleCommandWithResponse(
            command: cmd.bleCommand.mainCmd.rawValue,
            subcommand: cmd.bleCommand.subCmd,
            rw: BleType.read.rawValue,
            payload: []
        )
        .flatMap { [weak self] response -> Observable<DeviceReadResult> in
            
            guard let self = self else {
                return .just(.failure(error: "Manager released"))
            }
            
            if let error = response.error {
                return .just(.failure(error: error.localizedDescription))
            }
            
            let value = response.data.u16LE(0)
            numOfLogs = Int(value)
            
            PrintLog("📒 NumOfLog = \(numOfLogs)")
            
            return .just(numOfLogs == 0 ? .noDiveData : .success)
        }
        .catch { error in
                .just(.failure(error: error.localizedDescription))
        }
    }
}

extension BluetoothDeviceCR4Manager.BleCommandKey {
    var defaultPayload: [UInt8] {
        switch self {
            //        case .kDepthAlarm, .kTimeAlarm:
            //            return [0xFF]
        default:
            return []
        }
    }
    
    var readPayloads: [[UInt8]] {
        switch self {
            //        case .kDepthAlarm, .kTimeAlarm:
            //            return [[0xFF], [0x00]]
        default:
            return [defaultPayload]
        }
    }
}

extension BluetoothDeviceCR4Manager.BleCommandKey {
    // Chuyển đổi giá trị từ DB sang payload cho lệnh Write
    func getWritePayload(from row: Row, units: Int) -> [UInt8]? {
        switch self {
        case .kUnit:
            return [row.uint8Value(key: "Units")]
            
        case .kLanguage:
            return [row.uint8Value(key: "Language")]
        case .kBacklightLevel:
            return [row.uint8Value(key: "BacklightDimLevel")]
        case .kBuzzer:
            return [row.uint8Value(key: "BuzzerMode")]
        case .kVibration:
            return [row.uint8Value(key: "Vibration")]
        case .kSetPower:
            return [row.uint8Value(key: "PowerSaving")]
        case .kSetAutoDiveType:
            return [row.uint8Value(key: "DiveMode")]
        case .kScubaAutoStartDepth:
            return [row.uint8Value(key: "ScubaAutoStartDepth")]
            
        case .kNitroxSetting:
            return [row.uint8Value(key: "FO2")]
        case .kPPO2Setting:
            return [row.uint8Value(key: "PO2")]
        case .kSafetyFactorSetting:
            return [row.uint8Value(key: "Conservatism")]
        case .kSamplingRate:
            return [row.uint8Value(key: "DiveLogSamplingTime")]
        case .kScubaLogStopTime:
            return [row.uint8Value(key: "LogStopTime")]
            
        case .kScubaDepthAlarm:
            return [row.uint8Value(key: "DepthAlarmEnable")]
        case .kScubaTimeAlarm:
            return [row.uint8Value(key: "TimeAlarmEnable")]
        case .kThresholdScubaDepthAlarm:
            return [row.uint8Value(key: "DepthAlarmM")]
        case .kThresholdScubaTimeAlarm:
            return [row.uint8Value(key: "DiveTimeAlarmMin")]
            
        case .kFreeDiveTimeAlarm:
            return [row.uint8Value(key: "FreeDiveTimeAlarmEnable")]
        case .kFreeDiveDepthAlarm:
            return [row.uint8Value(key: "FreeDiveDepthAlarmEnable")]
        case .kFreeDiveSurfaceTimeAlarm:
            return [row.uint8Value(key: "FreeDiveSurfaceTimeAlarmEnable")]
        
        case .kFreeDiveTimeAlarmThreshold1:
            let value = row.stringValue(key: "FREE_TIME_ALARM1").toInt()
            return value.to2Bytes()
        case .kFreeDiveTimeAlarmThreshold2:
            let value = row.stringValue(key: "FREE_TIME_ALARM2").toInt()
            return value.to2Bytes()
        case .kFreeDiveTimeAlarmThreshold3:
            let value = row.stringValue(key: "FREE_TIME_ALARM3").toInt()
            return value.to2Bytes()
        
        case .kFreeDiveDepthAlarmThreshold1:
            return [row.uint8Value(key: "FREE_DEPTH_ALARM1")]
        case .kFreeDiveDepthAlarmThreshold2:
            return [row.uint8Value(key: "FREE_DEPTH_ALARM2")]
        case .kFreeDiveDepthAlarmThreshold3:
            return [row.uint8Value(key: "FREE_DEPTH_ALARM3")]
        
        case .kFreeDiveSurfaceTimeAlarmThreshold1:
            return [row.uint8Value(key: "FREE_SI_ALARM1")]
        case .kFreeDiveSurfaceTimeAlarmThreshold2:
            return [row.uint8Value(key: "FREE_SI_ALARM2")]
        case .kFreeDiveSurfaceTimeAlarmThreshold3:
            return [row.uint8Value(key: "FREE_SI_ALARM3")]
            
        default:
            return nil // Các trường như SerialNumber, FirmwareRev thường là Read-only
        }
    }
    
    func getWritePayloads(from row: Row, units: Int) -> [BluetoothDeviceCR4Manager.BleWriteConfig]? {
        if let data = getWritePayload(from: row, units: units) {
            return [BluetoothDeviceCR4Manager.BleWriteConfig(payload: data, isReserved: false)]
        }
        return nil
    }
}

extension BluetoothDeviceCR4Manager {
    // HELPER
    
    private func formatDiveDate(_ date: Date, timezoneOffset: Double) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        
        // Tính toán giây từ GMT dựa trên giá trị Double (VD: 5.5 * 3600 = 19800 giây)
        let seconds = Int(timezoneOffset * 3600)
        if let tz = TimeZone(secondsFromGMT: seconds) {
            formatter.timeZone = tz
        }
        
        return formatter.string(from: date)
    }
    
    func getSystemTimeZoneIndex() -> UInt8 {
        
        // 1. Lấy số giây lệch so với UTC (ví dụ VN +7 là 25200 giây)
        let secondsFromGMT = TimeZone.current.secondsFromGMT()
        
        // 2. Chuyển sang đơn vị giờ (Double)
        let currentOffset = Double(secondsFromGMT) / 3600.0
        
        // 3. Tìm index của currentOffset trong mảng
        // Nếu không tìm thấy (trường hợp hiếm), mặc định trả về index 12 (UTC+0)
        if let index = timezoneOffsets.firstIndex(of: currentOffset) {
            return UInt8(index)
        }
        
        return 12 // Mặc định là UTC+0
    }
}

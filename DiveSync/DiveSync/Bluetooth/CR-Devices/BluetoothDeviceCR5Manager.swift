import Foundation
import GRDB
import ProgressHUD
import CoreBluetooth
import RxBluetoothKit
import RxSwift

struct CommandSentence {
    var checksum: UInt8 = 0
    var commandGroup: UInt8
    var data: [UInt8]?
    var dataLen: Int = 0
    var idx: Int? = -1
    var direction: UInt8
    var subCommand: UInt8
    var reserved: Bool
    
    // ===== CONSTRUCTOR 1: WITH INDEX DATA =====
    init(commandGroup: UInt8,
         subCommand: UInt8,
         directionWR: UInt8,
         reserved: Bool,
         index: Int?,
         data: [UInt8]?) {
        
        self.commandGroup = commandGroup
        self.subCommand = subCommand
        self.direction = directionWR
        self.data = data
        self.reserved = reserved
        self.idx = index
        
        self.checksum = CommandSentence.getChecksum(
            b: commandGroup,
            b2: subCommand,
            b3: directionWR,
            bArr: data,
            index: index
        )
    }
    
    // ===== CONSTRUCTOR 2: WRITE VALUE (Single byte data) =====
    init(commandGroup: UInt8,
         subCommand: UInt8,
         directionWR: UInt8,
         writeValue: Int) {
        
        self.commandGroup = commandGroup
        self.subCommand = subCommand
        self.direction = directionWR
        self.data = [UInt8(writeValue & 0xFF)]
        self.dataLen = 0
        self.reserved = false // Java mặc định boolean là false
        self.idx = -1
        
        self.checksum = CommandSentence.getChecksum(
            b: commandGroup,
            b2: subCommand,
            b3: directionWR,
            bArr: self.data,
            index: -1
        )
    }
    
    // Gộp mảng byte để gửi qua BLE
    func getBytes() -> [UInt8] {
        var size = 4 // Group + Sub + Direction + Checksum
        if idx != -1 { size += 1 }
        if let data = data { size += data.count }
        if reserved { size += 1 }
        
        var buf = [UInt8](repeating: 0, count: size)
        
        buf[0] = commandGroup
        buf[1] = subCommand
        buf[2] = direction
        
        var pos = 3
        
        if reserved {
            buf[pos] = 0
            pos += 1
        }
        
        if idx != -1 {
            buf[pos] = UInt8(idx! & 0xFF)
            pos += 1
        }
        
        if let data = data {
            for i in 0..<data.count {
                buf[pos] = data[i]
                pos += 1
            }
        }
        
        buf[pos] = checksum
        return buf
    }
    
    // Hàm tính Checksum (Convert từ Java logic)
    static func getChecksum(b: UInt8, b2: UInt8, b3: UInt8, bArr: [UInt8]?, index: Int? = -1) -> UInt8 {
        var sum: UInt8 = b &+ b2 &+ b3
        
        if let bArr = bArr {
            for d in bArr {
                sum = sum &+ d
            }
        }
        
        if index != -1 {
            sum = sum &+ UInt8(index! & 0xFF)
        }
        
        return sum ^ 0xFF
    }
}

final class BluetoothDeviceCR5Manager {
    
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
    
    enum BleCommandKey: String, Hashable, CaseIterable {
        case kUnit
        case kTimeFormat
        case kDateFormat
        case kSetTime
        case kTimeZone
        case kDST // Daylight Saving Time Enable(DST)
        case kSerialNumber
        case kFirmwareRev
        case kLanguage
        case kGNSS
        case kTWIST
        case kDiveWaterType
        case kBacklightLevel
        case kBacklightTime
        case kBuzzer
        case kVibration
        case kDiveMode
        case kDiveStartDepth
        case kFo2
        case kPo2
        case kConservatism
        case kDepthAlarmEnable
        case kDepthAlarmM
        case kDepthAlarmFT
        case kTimeAlarmEnable
        case kTimeAlarm
        case kSamplingRate
        case kDivingLogStopTime
        
        case kFreeDepth1AlarmEnable
        case kFreeDepth2AlarmEnable
        case kFreeDepth3AlarmEnable
        
        case kFreeDepth1Alarm
        case kFreeDepth2Alarm
        case kFreeDepth3Alarm
        
        case kFreeTime1AlarmEnable
        case kFreeTime2AlarmEnable
        case kFreeTime3AlarmEnable
        
        case kFreeTime1Alarm
        case kFreeTime2Alarm
        case kFreeTime3Alarm
        
        case kFreeSI1AlarmEnable
        case kFreeSI2AlarmEnable
        case kFreeSI3AlarmEnable
        
        case kFreeSI1Alarm
        case kFreeSI2Alarm
        case kFreeSI3Alarm
        
        var bleCommand: BleCommand {
            switch self {
                
            case .kFirmwareRev:
                return .init(mainCmd: .A0, subCmd: 0x01, indexed: false, payloadLen: 6)
            case .kSerialNumber:
                return .init(mainCmd: .A0, subCmd: 0x02, indexed: false, payloadLen: 16)
                
            case .kTimeFormat:
                return .init(mainCmd: .B0, subCmd: 0x0E, indexed: false, payloadLen: 1)
            case .kDateFormat:
                return .init(mainCmd: .B0, subCmd: 0x0C, indexed: false, payloadLen: 1)
            case .kSetTime:
                return .init(mainCmd: .B0, subCmd: 0x0D, indexed: false, payloadLen: 1)
            case .kTimeZone:
                return .init(mainCmd: .B0, subCmd: 0x0F, indexed: false, payloadLen: 1)
            case .kDST:
                return .init(mainCmd: .B0, subCmd: 0x10, indexed: false, payloadLen: 1)
            case .kUnit:
                return .init(mainCmd: .B0, subCmd: 0x14, indexed: false, payloadLen: 1)
            case .kLanguage:
                return .init(mainCmd: .B0, subCmd: 0x13, indexed: false, payloadLen: 1)
            case .kGNSS:
                return .init(mainCmd: .B0, subCmd: 0x00, indexed: false, payloadLen: 1)
            case .kBacklightLevel:
                return .init(mainCmd: .B0, subCmd: 0x06, indexed: false, payloadLen: 1)
            case .kBacklightTime:
                return .init(mainCmd: .B0, subCmd: 0x07, indexed: false, payloadLen: 1)
            case .kBuzzer:
                return .init(mainCmd: .B0, subCmd: 0x09, indexed: false, payloadLen: 1)
            case .kVibration:
                return .init(mainCmd: .B0, subCmd: 0x0A, indexed: false, payloadLen: 1)
                
                
            case .kDiveMode:
                return .init(mainCmd: .C0, subCmd: 0x00, indexed: false, payloadLen: 1)
            case .kDiveStartDepth:
                return .init(mainCmd: .C0, subCmd: 0x01, indexed: false, payloadLen: 1)
            case .kTWIST:
                return .init(mainCmd: .C0, subCmd: 0x02, indexed: false, payloadLen: 1)
            case .kDiveWaterType:
                return .init(mainCmd: .C0, subCmd: 0x03, indexed: false, payloadLen: 1)
                
            case .kFo2:
                return .init(mainCmd: .C0, subCmd: 0x20, indexed: false, payloadLen: 1)
            case .kPo2:
                return .init(mainCmd: .C0, subCmd: 0x21, indexed: false, payloadLen: 1)
            case .kConservatism:
                return .init(mainCmd: .C0, subCmd: 0x23, indexed: false, payloadLen: 1)
            case .kDepthAlarmEnable:
                return .init(mainCmd: .C0, subCmd: 0x24, indexed: true, payloadLen: 1)
            case .kDepthAlarmM, .kDepthAlarmFT:
                return .init(mainCmd: .C0, subCmd: 0x25, indexed: true, payloadLen: 2)
            case .kTimeAlarmEnable:
                return .init(mainCmd: .C0, subCmd: 0x26, indexed: true, payloadLen: 1)
            case .kTimeAlarm:
                return .init(mainCmd: .C0, subCmd: 0x27, indexed: true, payloadLen: 1)
            case .kSamplingRate:
                return .init(mainCmd: .C0, subCmd: 0x28, indexed: false, payloadLen: 1)
            case .kDivingLogStopTime:
                return .init(mainCmd: .C0, subCmd: 0x29, indexed: false, payloadLen: 1)
                
            case .kFreeDepth1AlarmEnable, .kFreeDepth2AlarmEnable, .kFreeDepth3AlarmEnable:
                return .init(mainCmd: .C0, subCmd: 0x40, indexed: true, payloadLen: 1)
            case .kFreeDepth1Alarm, .kFreeDepth2Alarm, .kFreeDepth3Alarm:
                return .init(mainCmd: .C0, subCmd: 0x41, indexed: true, payloadLen: 2)
                
            case .kFreeTime1AlarmEnable, .kFreeTime2AlarmEnable, .kFreeTime3AlarmEnable:
                return .init(mainCmd: .C0, subCmd: 0x42, indexed: true, payloadLen: 1)
            case .kFreeTime1Alarm, .kFreeTime2Alarm, .kFreeTime3Alarm:
                return .init(mainCmd: .C0, subCmd: 0x43, indexed: false, payloadLen: 2)
                
            case .kFreeSI1AlarmEnable, .kFreeSI2AlarmEnable, .kFreeSI3AlarmEnable:
                return .init(mainCmd: .C0, subCmd: 0x44, indexed: true, payloadLen: 1)
            case .kFreeSI1Alarm, .kFreeSI2Alarm, .kFreeSI3Alarm:
                return .init(mainCmd: .C0, subCmd: 0x45, indexed: false, payloadLen: 2)
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
    
    
    
    let timezoneOffsets: [Double] = [
        -12.0, -11.0, -10.0, -9.0, -8.0, -7.0, -6.0, -5.0, -4.5, -4.0,
         -3.5, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 3.5, 4.0,
         5.0, 5.5, 6.0, 6.5, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0
    ]
    
    
    
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
        
        let sentence = CommandSentence(
            commandGroup: command,
            subCommand: subcommand,
            directionWR: rw,
            reserved: isReserved,
            index: index,
            data: payload
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
    
    // RESPONSE FORMAT
    //C1 41 01 00 00 0B 00 F1
    //[0] C1  header (response of C0 group)
    //[1] 41  sub = Free Depth Alarm
    //[2] 01  len/count of logical entries
    //[3] 00  index
    //[4] 00  reserved
    //[5] 0B  value LSB
    //[6] 00  value MSB
    //[7] F1  CRC
    //Value: 0x000B = 11
    private func parseResponse(_ data: Data) throws -> Data? {
        let bytes = [UInt8](data)
        
        guard bytes.count >= 3 else {
            return nil
        }
        
        let groupByte = UInt8((Int(bytes[0]) - 1) & 0xFF)
        let subByte = bytes[1]
        
        if let commandKey = BleCommandKey.from(mainCmd: groupByte, subCmd: subByte) {
            let meta = commandKey.bleCommand
            
            var pos = 3
            var outIndex: Int = -1
            
            // 1. Xử lý Index
            if meta.indexed {
                if bytes.count > pos {
                    outIndex = Int(bytes[pos])
                    pos += 1
                }
            }
            
            // 2. Xử lý skip byte nếu là loại 2 bytes
            if meta.payloadLen == 2 {
                pos += 1
            }
                        
            // 3. Trích xuất Payload thô dưới dạng Data
            var payloadData: Data? = nil
            
            if meta.payloadLen > 0 {
                // Kiểm tra an toàn để không cắt mảng vượt quá độ dài bytes nhận được
                let endPos = pos + meta.payloadLen
                if bytes.count >= endPos {
                    let range = pos..<endPos
                    payloadData = Data(bytes[range])
                }
            }
            
            // Debug thử
            if let pData = payloadData {
                print("Command: \(commandKey), Index: \(outIndex), Payload: \(pData as NSData)")
            } else {
                print("Command: \(commandKey), Index: \(outIndex), Payload: Empty")
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
            .kSerialNumber,
            .kFirmwareRev,
            .kUnit,
            .kLanguage,
            .kGNSS,
            .kDiveWaterType,
            .kBacklightLevel,
            .kBacklightTime,
            .kBuzzer,
            .kVibration,
            .kDiveMode,
            .kTWIST,
            .kTimeFormat,
            .kDateFormat,
            .kTimeZone,
            .kDST,
            .kDiveStartDepth,
            .kFo2,
            .kPo2,
            .kConservatism,
            .kDepthAlarmEnable,
            .kTimeAlarmEnable,
            .kTimeAlarm,
            .kSamplingRate,
            .kDivingLogStopTime
        ]
        
        var steps: [ReadStep] = commands.flatMap { cmd in
            
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
        
        // Tạo danh sách các index cần đọc (0 cho Mét, 1 cho Feet)
        let depthIndices: [Int] = [0, 1]
        let depthAlarmCmds:[BleCommandKey] = [.kDepthAlarmM, .kDepthAlarmFT]
        for idx in depthIndices {
            let getDepthStep: ReadStep = {
                let cmdInfo = depthAlarmCmds[idx].bleCommand
                return self.sendSimpleCommandWithResponse(
                    command: cmdInfo.mainCmd.rawValue,
                    subcommand: cmdInfo.subCmd,
                    rw: BleType.read.rawValue,
                    isReserved: true,
                    index: idx // Sử dụng idx ở đây (0 hoặc 1)
                )
                .do(onNext: { [weak self] response in
                    guard let self = self else { return }
                    self.responses[depthAlarmCmds[idx], default: []].append(response)
                })
                .map { _ in () }
            }
            steps.append(getDepthStep)
        }
        
        // Free Dive Depth Alarm Enable
        let freeDepthEnableIndices: [Int] = [0, 1, 2]
        let freeDepthAlarmEnableCmds:[BleCommandKey] = [.kFreeDepth1AlarmEnable, .kFreeDepth2AlarmEnable, .kFreeDepth3AlarmEnable]
        for idx in freeDepthEnableIndices {
            let getFreeDepthEnableStep: ReadStep = {
                let cmdInfo = freeDepthAlarmEnableCmds[idx].bleCommand
                return self.sendSimpleCommandWithResponse(
                    command: cmdInfo.mainCmd.rawValue,
                    subcommand: cmdInfo.subCmd,
                    rw: BleType.read.rawValue,
                    isReserved: false,
                    index: idx // Sử dụng idx ở đây (0 hoặc 1)
                )
                .do(onNext: { [weak self] response in
                    guard let self = self else { return }
                    self.responses[freeDepthAlarmEnableCmds[idx], default: []].append(response)
                })
                .map { _ in () }
            }
            steps.append(getFreeDepthEnableStep)
        }
        
        let freeDepthIndices: [Int] = [0, 1, 2]
        let freeDepthAlarmCmds:[BleCommandKey] = [.kFreeDepth1Alarm, .kFreeDepth2Alarm, .kFreeDepth3Alarm]
        for idx in freeDepthIndices {
            let getFreeDepthStep: ReadStep = {
                let cmdInfo = freeDepthAlarmCmds[idx].bleCommand
                return self.sendSimpleCommandWithResponse(
                    command: cmdInfo.mainCmd.rawValue,
                    subcommand: cmdInfo.subCmd,
                    rw: BleType.read.rawValue,
                    isReserved: true,
                    index: idx // Sử dụng idx ở đây (0 hoặc 1)
                )
                .do(onNext: { [weak self] response in
                    guard let self = self else { return }
                    self.responses[freeDepthAlarmCmds[idx], default: []].append(response)
                })
                .map { _ in () }
            }
            steps.append(getFreeDepthStep)
        }
        
        // Free Dive Time Alarm Enable
        let freeTimeEnableIndices: [Int] = [0, 1, 2]
        let freeTimeAlarmEnableCmds:[BleCommandKey] = [.kFreeTime1AlarmEnable, .kFreeTime2AlarmEnable, .kFreeTime3AlarmEnable]
        for idx in freeTimeEnableIndices {
            let getFreeTimeEnableStep: ReadStep = {
                let cmdInfo = freeTimeAlarmEnableCmds[idx].bleCommand
                return self.sendSimpleCommandWithResponse(
                    command: cmdInfo.mainCmd.rawValue,
                    subcommand: cmdInfo.subCmd,
                    rw: BleType.read.rawValue,
                    isReserved: false,
                    index: idx // Sử dụng idx ở đây (0 hoặc 1)
                )
                .do(onNext: { [weak self] response in
                    guard let self = self else { return }
                    self.responses[freeTimeAlarmEnableCmds[idx], default: []].append(response)
                })
                .map { _ in () }
            }
            steps.append(getFreeTimeEnableStep)
        }
        
        let freeTimeIndices: [Int] = [0, 1, 2]
        let freeTimeAlarmCmds:[BleCommandKey] = [.kFreeTime1Alarm, .kFreeTime2Alarm, .kFreeTime3Alarm]
        for idx in freeTimeIndices {
            let getFreeTimeStep: ReadStep = {
                let cmdInfo = freeTimeAlarmCmds[idx].bleCommand
                return self.sendSimpleCommandWithResponse(
                    command: cmdInfo.mainCmd.rawValue,
                    subcommand: cmdInfo.subCmd,
                    rw: BleType.read.rawValue,
                    isReserved: false,
                    index: idx // Sử dụng idx ở đây (0 hoặc 1)
                )
                .do(onNext: { [weak self] response in
                    guard let self = self else { return }
                    self.responses[freeTimeAlarmCmds[idx], default: []].append(response)
                })
                .map { _ in () }
            }
            steps.append(getFreeTimeStep)
        }
        
        // Free Dive Time Alarm Enable
        let freeSIEnableIndices: [Int] = [0, 1, 2]
        let freeSIAlarmEnableCmds:[BleCommandKey] = [.kFreeSI1AlarmEnable, .kFreeSI2AlarmEnable, .kFreeSI3AlarmEnable]
        for idx in freeSIEnableIndices {
            let getFreeSIEnableStep: ReadStep = {
                let cmdInfo = freeSIAlarmEnableCmds[idx].bleCommand
                return self.sendSimpleCommandWithResponse(
                    command: cmdInfo.mainCmd.rawValue,
                    subcommand: cmdInfo.subCmd,
                    rw: BleType.read.rawValue,
                    isReserved: false,
                    index: idx // Sử dụng idx ở đây (0 hoặc 1)
                )
                .do(onNext: { [weak self] response in
                    guard let self = self else { return }
                    self.responses[freeSIAlarmEnableCmds[idx], default: []].append(response)
                })
                .map { _ in () }
            }
            steps.append(getFreeSIEnableStep)
        }
        
        let freeSIIndices: [Int] = [0, 1, 2]
        let freeSIAlarmCmds:[BleCommandKey] = [.kFreeSI1Alarm, .kFreeSI2Alarm, .kFreeSI3Alarm]
        for idx in freeSIIndices {
            let getFreeSIStep: ReadStep = {
                let cmdInfo = freeSIAlarmCmds[idx].bleCommand
                return self.sendSimpleCommandWithResponse(
                    command: cmdInfo.mainCmd.rawValue,
                    subcommand: cmdInfo.subCmd,
                    rw: BleType.read.rawValue,
                    isReserved: false,
                    index: idx // Sử dụng idx ở đây (0 hoặc 1)
                )
                .do(onNext: { [weak self] response in
                    guard let self = self else { return }
                    self.responses[freeSIAlarmCmds[idx], default: []].append(response)
                })
                .map { _ in () }
            }
            steps.append(getFreeSIStep)
        }
        
        runSequential(steps)
            .flatMap { [weak self] _ -> Observable<DeviceReadResult> in
                guard let self else {
                    return .error("" as! Error)
                }
                
                if let list = responses[.kSerialNumber], let first = list.first {
                    let trimmedData = first.data
                    self.SerialNo = trimmedData.asciiString ?? ""
                    print("SerialNo = \(self.SerialNo)")
                }
                
                if let list = responses[.kFirmwareRev], let first = list.first {
                    let trimmedData = first.data
                    self.firmwareRev = trimmedData.asciiString ?? ""
                    print("firmwareRev = \(self.firmwareRev)")
                }
                
                switch syncType {
                case .kUploadDateTime:
                    return self.U_LogicWriteTimeSync()
                case .kUploadSetting:
                    return self.U_CR5WriteSetting()
                default:
                    return self.U_CR5SaveSetting()
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
                
                guard let m = BluetoothDeviceCoordinator.shared.cr5DeviceManager else { return }
                
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
            },
                       onError: { error in
                ProgressHUD.dismiss()
                BluetoothDeviceCoordinator.shared.disconnect()
                BluetoothDeviceCoordinator.shared.delegate?.didConnectToDevice(message: "❗️\(error.localizedDescription.localized)")
            }).disposed(by: disposeBag)
    }
    
    // MARK: - PARSE DATA
    func U_CR5SaveSetting() -> Observable<DeviceReadResult> {
        
        if let (bleName, _) = scannedPeripheral.splitDeviceName(),
           let dcInfo = DcInfo.shared.getValues(forKey: bleName) {
            self.ModelID = dcInfo[2].toInt()
        }
        
        var dcSettings: [String: Any] = [:]
        
        dcSettings["DeviceID"] = DatabaseManager.shared.lastDevicID(modelId: ModelID, serialNo: self.SerialNo)
        
        if let first = responses[.kUnit]?.first {
            units = first.data.toInt()
            dcSettings["Units"] = units
        }
        
        if let first = responses[.kSerialNumber]?.first {
            self.SerialNo = first.data.asciiString ?? ""
        }
        
        if let first = responses[.kTimeFormat]?.first{
            dcSettings["TimeFormat"] = first.data.toInt()
        }
        
        if let first = responses[.kDateFormat]?.first {
            dcSettings["DateFormat"] = first.data.toInt()
        }
        
        if let first = responses[.kDST]?.first {
            dcSettings["DST"] = first.data.toInt()
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
        
        if let first = responses[.kGNSS]?.first {
            dcSettings["GNSS"] = first.data.toInt()
        }
        
        if let first = responses[.kDiveWaterType]?.first {
            dcSettings["WaterDensity"] = first.data.toInt()
        }
        
        if let first = responses[.kDiveMode]?.first {
            dcSettings["DiveMode"] = first.data.toInt()
        }
        
        if let first = responses[.kDiveStartDepth]?.first {
            dcSettings["LogStartDepth"] = first.data.toInt()
        }
        
        if let first = responses[.kTWIST]?.first {
            dcSettings["TWIST"] = first.data.toInt()
        }
        
        if let first = responses[.kFo2]?.first {
            dcSettings["FO2"] = first.data.toInt()
        }
        
        if let first = responses[.kPo2]?.first {
            dcSettings["PO2"] = first.data.toInt()
        }
        
        if let first = responses[.kConservatism]?.first {
            dcSettings["Conservatism"] = first.data.toInt()
        }
        
        if let first = responses[.kBacklightLevel]?.first {
            dcSettings["BacklightDimLevel"] = first.data.toInt()
        }
        
        if let first = responses[.kBacklightTime]?.first {
            dcSettings["BacklightDimTime"] = first.data.toInt()
        }
        
        if let first = responses[.kSamplingRate]?.first {
            dcSettings["DiveLogSamplingTime"] = first.data.toInt()
        }
        
        if let first = responses[.kDivingLogStopTime]?.first {
            dcSettings["LogStopTime"] = first.data.toInt()
        }
        
        if let first = responses[.kDepthAlarmEnable]?.first {
            let DepthAlarmEnable = first.data.toInt()
            if DepthAlarmEnable == 0 {
                dcSettings["DepthAlarmM"] = -1 // OFF
                dcSettings["DepthAlarmFt"] = -1
            } else {
                dcSettings["DepthAlarmM"] = 0 // ON
                dcSettings["DepthAlarmFt"] = 0
            }
        }
        
        if let first = responses[.kDepthAlarmM]?.first {
            if let DepthAlarmEnable = dcSettings["DepthAlarmM"] as? Int, DepthAlarmEnable != -1 {
                dcSettings["DepthAlarmM"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kDepthAlarmFT]?.first {
            if let DepthAlarmEnable = dcSettings["DepthAlarmFt"] as? Int, DepthAlarmEnable != -1 {
                dcSettings["DepthAlarmFt"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kTimeAlarmEnable]?.first {
            let TimeAlarmEnable = first.data.toInt()
            if TimeAlarmEnable == 0 {
                dcSettings["DiveTimeAlarmMin"] = -1 // OFF
            } else {
                dcSettings["DiveTimeAlarmMin"] = 0
            }
        }
        
        if let first = responses[.kTimeAlarm]?.first {
            if let TimeAlarmEnable = dcSettings["DiveTimeAlarmMin"] as? Int, TimeAlarmEnable != -1 {
                dcSettings["DiveTimeAlarmMin"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kFreeDepth1AlarmEnable]?.first {
            let FreeDepth1AlarmEnable = first.data.toInt()
            if FreeDepth1AlarmEnable == 0 {
                dcSettings["FREE_DEPTH_ALARM1"] = -1 // OFF
            } else {
                dcSettings["FREE_DEPTH_ALARM1"] = 0
            }
        }
        
        if let first = responses[.kFreeDepth2AlarmEnable]?.first {
            let FreeDepth2AlarmEnable = first.data.toInt()
            if FreeDepth2AlarmEnable == 0 {
                dcSettings["FREE_DEPTH_ALARM2"] = -1 // OFF
            } else {
                dcSettings["FREE_DEPTH_ALARM2"] = 0
            }
        }
        
        if let first = responses[.kFreeDepth3AlarmEnable]?.first {
            let FreeDepth3AlarmEnable = first.data.toInt()
            if FreeDepth3AlarmEnable == 0 {
                dcSettings["FREE_DEPTH_ALARM3"] = -1 // OFF
            } else {
                dcSettings["FREE_DEPTH_ALARM3"] = 0
            }
        }
        
        if let first = responses[.kFreeDepth1Alarm]?.first {
            if let FreeDepth1AlarmEnable = dcSettings["FREE_DEPTH_ALARM1"] as? Int, FreeDepth1AlarmEnable != -1 {
                dcSettings["FREE_DEPTH_ALARM1"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kFreeDepth2Alarm]?.first {
            if let FreeDepth2AlarmEnable = dcSettings["FREE_DEPTH_ALARM2"] as? Int, FreeDepth2AlarmEnable != -1 {
                dcSettings["FREE_DEPTH_ALARM2"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kFreeDepth3Alarm]?.first {
            if let FreeDepth3AlarmEnable = dcSettings["FREE_DEPTH_ALARM3"] as? Int, FreeDepth3AlarmEnable != -1 {
                dcSettings["FREE_DEPTH_ALARM3"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kFreeTime1AlarmEnable]?.first {
            let Enabled = first.data.toInt()
            if Enabled == 0 {
                dcSettings["FREE_TIME_ALARM1"] = -1 // OFF
            } else {
                dcSettings["FREE_TIME_ALARM1"] = 0
            }
        }
        
        if let first = responses[.kFreeTime2AlarmEnable]?.first {
            let Enabled = first.data.toInt()
            if Enabled == 0 {
                dcSettings["FREE_TIME_ALARM2"] = -1 // OFF
            } else {
                dcSettings["FREE_TIME_ALARM2"] = 0
            }
        }
        
        if let first = responses[.kFreeTime3AlarmEnable]?.first {
            let Enabled = first.data.toInt()
            if Enabled == 0 {
                dcSettings["FREE_TIME_ALARM3"] = -1 // OFF
            } else {
                dcSettings["FREE_TIME_ALARM3"] = 0
            }
        }
        
        if let first = responses[.kFreeTime1Alarm]?.first {
            if let Enabled = dcSettings["FREE_TIME_ALARM1"] as? Int, Enabled != -1 {
                dcSettings["FREE_TIME_ALARM1"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kFreeTime2Alarm]?.first {
            if let Enabled = dcSettings["FREE_TIME_ALARM2"] as? Int, Enabled != -1 {
                dcSettings["FREE_TIME_ALARM2"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kFreeTime3Alarm]?.first {
            if let Enabled = dcSettings["FREE_TIME_ALARM3"] as? Int, Enabled != -1 {
                dcSettings["FREE_TIME_ALARM3"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kFreeSI1AlarmEnable]?.first {
            let Enabled = first.data.toInt()
            if Enabled == 0 {
                dcSettings["FREE_SI_ALARM1"] = -1 // OFF
            } else {
                dcSettings["FREE_SI_ALARM1"] = 0
            }
        }
        
        if let first = responses[.kFreeSI2AlarmEnable]?.first {
            let Enabled = first.data.toInt()
            if Enabled == 0 {
                dcSettings["FREE_SI_ALARM2"] = -1 // OFF
            } else {
                dcSettings["FREE_SI_ALARM2"] = 0
            }
        }
        
        if let first = responses[.kFreeSI3AlarmEnable]?.first {
            let Enabled = first.data.toInt()
            if Enabled == 0 {
                dcSettings["FREE_SI_ALARM3"] = -1 // OFF
            } else {
                dcSettings["FREE_SI_ALARM3"] = 0
            }
        }
        
        if let first = responses[.kFreeSI1Alarm]?.first {
            if let Enabled = dcSettings["FREE_SI_ALARM1"] as? Int, Enabled != -1 {
                dcSettings["FREE_SI_ALARM1"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kFreeSI2Alarm]?.first {
            if let Enabled = dcSettings["FREE_SI_ALARM2"] as? Int, Enabled != -1 {
                dcSettings["FREE_SI_ALARM2"] = first.data.toInt()
            }
        }
        
        if let first = responses[.kFreeSI3Alarm]?.first {
            if let Enabled = dcSettings["FREE_SI_ALARM3"] as? Int, Enabled != -1 {
                dcSettings["FREE_SI_ALARM3"] = first.data.toInt()
            }
        }
        
        //print(dcSettings)
        DatabaseManager.shared.saveDeviceSettings(modelId: self.ModelID, serialNo: self.SerialNo, dcSettings: dcSettings)
        
        return .just(.success)
    }
    
    func U_CR5WriteSetting() -> Observable<DeviceReadResult> {
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
            var commandsToWrite: [BleCommandKey] = [
                .kUnit,
                .kLanguage,
                .kGNSS,
                .kDiveWaterType,
                .kBacklightLevel,
                .kBacklightTime,
                .kBuzzer,
                .kVibration,
                .kDiveMode,
                .kTWIST,
                .kTimeFormat,
                .kDateFormat,
                .kDST,
                .kDiveStartDepth,
                .kFo2,
                .kPo2,
                .kConservatism,
                .kDepthAlarmEnable,
                .kTimeAlarmEnable,
                .kTimeAlarm,
                .kSamplingRate,
                .kDivingLogStopTime,
                .kFreeDepth1AlarmEnable,
                .kFreeDepth1Alarm,
                .kFreeDepth2AlarmEnable,
                .kFreeDepth2Alarm,
                .kFreeDepth3AlarmEnable,
                .kFreeDepth3Alarm,
                
                .kFreeTime1AlarmEnable,
                .kFreeTime1Alarm,
                .kFreeTime2AlarmEnable,
                .kFreeTime2Alarm,
                .kFreeTime3AlarmEnable,
                .kFreeTime3Alarm,
                
                .kFreeSI1AlarmEnable,
                .kFreeSI1Alarm,
                .kFreeSI2AlarmEnable,
                .kFreeSI2Alarm,
                .kFreeSI3AlarmEnable,
                .kFreeSI3Alarm,
            ]
            
            if writeUnits == M {
                commandsToWrite.append(.kDepthAlarmM)
            } else {
                commandsToWrite.append(.kDepthAlarmFT)
            }
            
            
            let steps: [ReadStep] = commandsToWrite.flatMap { cmd -> [ReadStep] in
                
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
            
            // Giả sử bạn lấy được timezone của device (ví dụ là 8)0F
            let deviceTimeZoneOffset = currentDeviceTimeZone
            let systemTimeZoneOffset = Double(TimeZone.current.secondsFromGMT()) / 3600.0
            
            // Tính toán độ lệch (tính bằng giây)
            // Nếu máy +7, device +8 -> chênh lệch là -3600 giây (phải lùi lại 1 tiếng để khi device +8 cộng vào là vừa đủ)
            let offsetDifference = TimeInterval((systemTimeZoneOffset - deviceTimeZoneOffset) * 3600.0)
            
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
                
                if hasWhitespace {
                    formatter.dateFormat = "dd.MM.yyyy hh:mm a"
                } else {
                    formatter.dateFormat = "dd.MM.yyyy HH:mm"
                }
                
                let fullString = "\(dateString) \(timeString)"
                finalDate = formatter.date(from: fullString) ?? Date()
            }
            
            // Cộng thêm khoảng chênh lệch để "ép" timestamp về đúng ý đồ của Device
            finalDate = finalDate.addingTimeInterval(offsetDifference)
            
            // =====================================================
            // 2️⃣ Build TimeSync payload
            // =====================================================
            
            let timestamp = UInt32(finalDate.timeIntervalSince1970) // Số giây tính từ 1970 - Luôn là chuẩn UTC
            
            let utcBytes: [UInt8] = [
                UInt8(timestamp & 0xFF),
                UInt8((timestamp >> 8) & 0xFF),
                UInt8((timestamp >> 16) & 0xFF),
                UInt8((timestamp >> 24) & 0xFF)
            ]
            
            // =====================================================
            // 3️⃣ Build TimeFormat payload
            // =====================================================
            
            let timeFormatValue = row.uint8Value(key: "TimeFormat")
            let dateFormatValue = row.uint8Value(key: "DateFormat")
            let dstValue = row.uint8Value(key: "DST")
            
            let timeFormatPayload: [UInt8] = [timeFormatValue]
            let dateFormatPayload: [UInt8] = [dateFormatValue]
            let dstPayload: [UInt8] = [dstValue]
            
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
            
            let dstStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kDST.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kDST.bleCommand.subCmd,
                    rw: BleType.write.rawValue,   // ✅ WRITE
                    isReserved: false,
                    payload: dstPayload
                )
                .map { _ in () }
            }
            
            let timeSyncStep: ReadStep = {
                self.sendSimpleCommandWithResponse(
                    command: BleCommandKey.kSetTime.bleCommand.mainCmd.rawValue,
                    subcommand: BleCommandKey.kSetTime.bleCommand.subCmd,
                    rw: BleType.write.rawValue,   // ✅ WRITE
                    isReserved: false,
                    payload: utcBytes
                )
                .map { _ in () }
            }
            
            // =====================================================
            // 5️⃣ Run sequential (Format trước, Sync sau)
            // =====================================================
            
            return runSequential([timeFormatStep, dateFormatStep, dstStep, timeSyncStep])
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
            .flatMap { [weak self] (result, records) -> Observable<DeviceReadResult> in
                
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
                    let totalLogs = records.count
                    PrintLog("🚀 Start downloading \(totalLogs) logs")
                    
                    // 1. Tạo danh sách các Observable tải file
                    let downloadObservables = records.enumerated().map { (idx, logInfo) in
                        return self.downloadFullFile(log: logInfo)
                            .do(onNext: { _ in
                                // ✅ Cập nhật ProgressHUD (Ví dụ tính 100% khi xong 1 block/file)
                                // Nếu muốn phần trăm chi tiết hơn, bạn phải truyền closure vào downloadFullFile
                                let statusMessage = String(format: "%@ %d/%d (100%%)",
                                                           "Downloading dive".localized,
                                                           idx + 1,
                                                           totalLogs)
                                
                                DispatchQueue.main.async {
                                    ProgressHUD.animate(statusMessage)
                                }
                            })
                    }
                    
                    // 2. Chạy tuần tự bằng concat, gom vào mảng bằng toArray
                    return Observable.concat(downloadObservables)
                        .toArray()
                        .asObservable()
                        .map { (downloadedRecords: [DiveRecord?]) in
                            
                            // 3. Lọc bỏ nil (các file tải lỗi)
                            let validRecords = downloadedRecords.compactMap { $0 }
                            
                            PrintLog("✅ Tải xong \(validRecords.count)/\(totalLogs) files. Bắt đầu convert...")
                            
                            // 4. Gọi hàm Convert cho từng record
                            validRecords.forEach { record in
                                do {
                                    try self.U_ConvertDives(record)
                                    PrintLog("CONVERT RECORD")
                                } catch {
                                    PrintLog("⚠️ Convert lỗi cho dive #\(record.diveNo): \(error)")
                                }
                            }
                            
                            // 5. Trả về kết quả cuối cùng cho UI
                            return validRecords.isEmpty ? .noDiveData : .success
                        }
                }
            }
    }
    
    func directoryBrowseAllFile() -> Observable<[Data]> {
        guard let characteristic = writeCharacteristic else {
            return .error(NSError(domain: "Bluetooth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Write characteristic not found"]))
        }
        
        guard let indicateChar = indicateCharacteristic, let notifyChar = directoryAllFileChar else {
            return .error(NSError(domain: "Bluetooth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Write characteristic not found"]))
        }
        
        let cmdBuf: [UInt8] = [0x38, 0x00, 0x44, 0x49, 0x56, 0x45, 0x4C, 0x4F, 0x47]
        
        // Tạo trình lắng nghe trước
        let responseCollector = self.notifySubject
        // 1. Thay vì chỉ gom [Data], ta gom vào một Tuple chứa cả mảng và UUID vừa nhận
            .scan(into: (list: [Data](), lastUUID: CBUUID?.none)) { (accumulator, next) in
                if next.uuid == notifyChar.uuid {
                    accumulator.list.append(next.data)
                } else if next.uuid == indicateChar.uuid {
                    accumulator.list.insert(next.data, at: 0)
                }
                // Lưu lại UUID vừa nhận để tầng dưới (take) kiểm tra
                accumulator.lastUUID = next.uuid
            }
        // 2. Bây giờ 'state' là (list: [Data], lastUUID: CBUUID?)
            .take(until: { state in
                return state.lastUUID == indicateChar.uuid
            }, behavior: .inclusive) // .inclusive LÀ ĐỂ LẤY CẢ PACKAGE SAU CÙNG.
        // 3. Sau khi lấy xong, ta chỉ cần mảng [Data] cuối cùng
            .map { $0.list }
            .takeLast(1)
            .ifEmpty(default: [])
        
        // Sau đó mới thực hiện ghi và nối (concat) với collector
        return scannedPeripheral.peripheral.writeValue(Data(cmdBuf), for: characteristic, type: .withoutResponse)
            .asObservable()
            .flatMap { _ in responseCollector }
    }
    
    func readFileAtBlock(fileIndex: Int, blockIndex: Int, maxPackets: Int) -> Observable<Data> {
        guard let characteristic = writeCharacteristic,
              let indicateChar = indicateCharacteristic,
              let notifyChar = readDataChar else {
            return .error(NSError(domain: "Bluetooth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Characteristics not found"]))
        }
        
        // 1. Tạo Command Buffer (0x39...)
        var bArr = [UInt8](repeating: 0, count: 14)
        bArr[0] = 0x39
        bArr[1] = UInt8(fileIndex & 0xFF)
        bArr[2] = UInt8((fileIndex >> 8) & 0xFF)
        bArr[3] = UInt8(blockIndex & 0xFF)
        bArr[4] = UInt8((blockIndex >> 8) & 0xFF)
        bArr[5] = UInt8(maxPackets & 0xFF)
        let folderName = "DIVELOG"
        let nameBytes = Array(folderName.utf8)
        for i in 0..<min(8, nameBytes.count) { bArr[6 + i] = nameBytes[i] }
        
        // 2. Gom dữ liệu và Checksum
        let responseCollector = self.notifySubject
            .scan(into: (fullData: Data(), indicateData: Data?.none, lastUUID: CBUUID?.none, packetCount: 0, currentChecksum: UInt32(0))) { (state, next) in
                state.lastUUID = next.uuid
                
                if next.uuid == notifyChar.uuid {
                    state.packetCount += 1
                    
                    if next.data.count > 1 {
                        // 1. Luôn lấy 19 bytes data (bỏ byte index 0 ở mỗi gói)
                        let data19Bytes = next.data.subdata(in: 1..<next.data.count)
                        
                        // 2. Cộng vào checksum (vì bạn đã debug thấy Rx khớp với Calc With Header)
                        state.currentChecksum += data19Bytes.reduce(0) { $0 + UInt32($1) }
                        
                        // 3. LUÔN append vào fullData (bao gồm cả gói đầu tiên packetCount == 1)
                        state.fullData.append(data19Bytes)
                        
                        // PrintLog để bạn theo dõi
                        if state.packetCount == 1 {
                            PrintLog("📄 Đã nhận gói Header/FileName (Gói 1), size: \(data19Bytes.count)")
                        }
                    }
                } else if next.uuid == indicateChar.uuid {
                    state.indicateData = next.data
                }
            }
            .take(until: { $0.lastUUID == indicateChar.uuid }, behavior: .inclusive)
            .takeLast(1)
            .flatMap { state -> Observable<Data> in
                guard let indicate = state.indicateData, indicate.count >= 8 else {
                    return .error(NSError(domain: "BLE", code: -2, userInfo: [NSLocalizedDescriptionKey: "Indicate data error"]))
                }
                
                let receivedChecksum = indicate.extractUInt32(fromOffset: 4, endian: .little)
                
                if receivedChecksum == state.currentChecksum {
                    PrintLog("✅ Block \(blockIndex) Checksum OK (\(receivedChecksum))")
                    return .just(state.fullData)
                } else {
                    PrintLog("❌ Block \(blockIndex) Checksum Mismatch! Rx: \(receivedChecksum), Calc: \(state.currentChecksum)")
                    return .error(NSError(domain: "BLE", code: -3, userInfo: [NSLocalizedDescriptionKey: "Checksum mismatch"]))
                }
            }
        
        // 3. Thực thi ghi lệnh
        return scannedPeripheral.peripheral.writeValue(Data(bArr), for: characteristic, type: .withoutResponse)
            .asObservable()
            .flatMap { _ in responseCollector }
    }
    
    func getNumOfLogs() -> Observable<(result: DeviceReadResult, records: [FileInfoRecord])> {
        return directoryBrowseAllFile()
            .flatMap { [weak self] dataList -> Observable<(result: DeviceReadResult, records: [FileInfoRecord])> in
                guard let self = self else {
                    return .just((.failure(error: "Manager released"), []))
                }
                
                if dataList.isEmpty {
                    self.numOfLogs = 0
                    PrintLog("📒 NumOfLog = 0 (No data)")
                    return .just((.noDiveData, []))
                }
                
                // 1. Lấy Header (Gói 0)
                let headerData = dataList[0]
                let fileCount = Int(headerData.extractInt16(fromOffset: 1, endian: .little))
                self.numOfLogs = fileCount
                
                PrintLog("📒 NumOfLog = \(self.numOfLogs) (Parsed from Directory)")
                
                // 2. Parse các Record còn lại (Gói 1...n)
                let parsedRecords = dataList.dropFirst().compactMap { data -> FileInfoRecord? in
                    guard data.count >= 18 else { return nil } // u16 + 8b + u32 + u32 = 18
                    
                    let index = Int(data.extractInt16(fromOffset: 0, endian: .little))
                    let name = data.subdata(in: 2..<10).asciiString ?? ""
                    let size = data.extractUInt32(fromOffset: 10, endian: .little)
                    let checksum = data.extractUInt32(fromOffset: 14, endian: .little)
                    
                    return FileInfoRecord(index: index, fileName: name, fileSize: size, checksum: checksum)
                }
                
                PrintLog("📒 Found \(fileCount) files, Parsed \(parsedRecords.count) records")
                
                let status: DeviceReadResult = (fileCount == 0) ? .noDiveData : .success
                return .just((status, parsedRecords))
            }
            .catch { error in
                PrintLog("❌ Error browsing directory: \(error.localizedDescription)")
                return .just((.failure(error: error.localizedDescription), []))
            }
    }
    
    /*
     Read the data content of the specified file in the folder.
     
     Important Notes:
     1. Each block contains 256 packets, each packet being 19 bytes.
     2. Only one packet of data is transmitted at a time.
     3. A brief pause occurs every 27 packets.
     4. Reading each block always starts from Packet Index = 0.
     5. The checksum is calculated by adding all bytes of the read data.
     6. Entering 00 for the Number of packets represents 256 packets.
     7. If a read command is sent during the read process, the device will skip it.
     8. Do not perform other file operations during the read process (otherwise, the read may fail or result in an error).
     */
    func downloadFullFile(log: FileInfoRecord) -> Observable<DiveRecord?> {
        
        if DatabaseManager.shared.isExistDiveLog(diveNo: (log.index + 1), modelId: self.ModelID, serialNo: self.SerialNo) {
            return .just(nil)
        }
        
        let blockSize = 256 * 19 // 4864 bytes
        let totalBlocks = Int(ceil(Double(log.fileSize) / Double(blockSize)))
        
        PrintLog("📂 Tải file \(log.fileName): \(log.fileSize) bytes -> \(totalBlocks) blocks")
        
        // Biến tạm để gom toàn bộ dữ liệu của file qua các block
        var collectedFileData = Data()
        
        let blockObservables = (0..<totalBlocks).map { bIndex -> Observable<Data> in
            // Tính số packet cho block này
            var numPackets = 0 // 0 tương đương với 256 theo spec số 6
            if bIndex == totalBlocks - 1 {
                let remainingBytes = Int(log.fileSize) % blockSize
                if remainingBytes > 0 {
                    numPackets = Int(ceil(Double(remainingBytes) / 19.0))
                }
            }
            
            // Gọi hàm mới trả về Observable<Data>
            return self.readFileAtBlock(fileIndex: log.index, blockIndex: bIndex, maxPackets: numPackets)
                .do(onNext: { blockData in
                    collectedFileData.append(blockData)
                    PrintLog("✅ Đã nhận Block \(bIndex), size block: \(blockData.count) bytes. Tổng tích lũy: \(collectedFileData.count)")
                })
        }
        
        // Nếu file rỗng
        if blockObservables.isEmpty {
            return .just(nil)
        }
        
        return Observable.concat(blockObservables)
            .takeLast(1) // Đợi tải xong block cuối cùng
            .map {_ -> DiveRecord? in
                // Cắt dữ liệu theo đúng fileSize thực tế để loại bỏ byte rác ở packet cuối
                let cleanData = collectedFileData.prefix(Int(log.fileSize))
                
                PrintLog("🚀 Hoàn tất tải file #\(log.index). Tạo DiveRecord...")
                
                // Tạo đối tượng DiveRecord
                return DiveRecord(
                    diveNo: log.index,
                    logData: cleanData,
                    profiles: [] // Bạn có thể thêm logic parse profile vào đây nếu cần
                )
            }
            .catch { error in
                PrintLog("❌ Lỗi khi tải file \(log.fileName): \(error.localizedDescription)")
                // Trả về nil khi có lỗi để luồng chính không bị ngắt nhưng vẫn biết là thất bại
                return .just(nil)
            }
    }
}

extension BluetoothDeviceCR5Manager.BleCommandKey {
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

extension BluetoothDeviceCR5Manager.BleCommandKey {
    // Chuyển đổi giá trị từ DB sang payload cho lệnh Write
    func getWritePayload(from row: Row, units: Int) -> [UInt8]? {
        switch self {
        case .kUnit:
            return [row.uint8Value(key: "Units")]
            
        case .kLanguage:
            return [row.uint8Value(key: "Language")]
        case .kGNSS:
            return [row.uint8Value(key: "GNSS")]
        case .kDiveWaterType:
            return [row.uint8Value(key: "WaterDensity")]
        case .kBacklightLevel:
            return [row.uint8Value(key: "BacklightDimLevel")]
        case .kBacklightTime:
            return [row.uint8Value(key: "BacklightDimTime")]
        case .kBuzzer:
            return [row.uint8Value(key: "BuzzerMode")]
        case .kVibration:
            return [row.uint8Value(key: "Vibration")]
        case .kDiveMode:
            return [row.uint8Value(key: "DiveMode")]
        case .kDiveStartDepth:
            return [row.uint8Value(key: "LogStartDepth")]
        case .kTWIST:
            return [row.uint8Value(key: "TWIST")]
        case .kTimeFormat:
            return [row.uint8Value(key: "TimeFormat")]
        case .kDateFormat:
            return [row.uint8Value(key: "DateFormat")]
        case .kDST:
            return [row.uint8Value(key: "DST")]
        case .kFo2:
            return [row.uint8Value(key: "FO2")]
        case .kPo2:
            return [row.uint8Value(key: "PO2")]
        case .kConservatism:
            return [row.uint8Value(key: "Conservatism")]
        case .kDepthAlarmEnable:
            var value = -1
            if units == M {
                value = row.stringValue(key: "DepthAlarmM").toInt()
            } else {
                value = row.stringValue(key: "DepthAlarmFt").toInt()
            }
            
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kDepthAlarmM, .kDepthAlarmFT:
            var value = -1
            if units == M {
                value = row.stringValue(key: "DepthAlarmM").toInt()
            } else {
                value = row.stringValue(key: "DepthAlarmFt").toInt()
            }
            
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
            /*
             if value == OFF {
             dcSettings["DiveTimeAlarmMin"] = -1
             } else {
             dcSettings["DiveTimeAlarmMin"] = value.toInt()
             }
             */
        case .kTimeAlarmEnable:
            let value = row.stringValue(key: "DiveTimeAlarmMin").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kTimeAlarm:
            let value = row.stringValue(key: "DiveTimeAlarmMin").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return [UInt8(value & 0xFF)]
            }
        case .kSamplingRate:
            return [row.uint8Value(key: "DiveLogSamplingTime")]
        case .kDivingLogStopTime:
            return [row.uint8Value(key: "LogStopTime")]
            
            
        case .kFreeDepth1AlarmEnable:
            let value = row.stringValue(key: "FREE_DEPTH_ALARM1").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kFreeDepth1Alarm:
            let value = row.stringValue(key: "FREE_DEPTH_ALARM1").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
            
        case .kFreeDepth2AlarmEnable:
            let value = row.stringValue(key: "FREE_DEPTH_ALARM2").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kFreeDepth2Alarm:
            let value = row.stringValue(key: "FREE_DEPTH_ALARM2").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
            
        case .kFreeDepth3AlarmEnable:
            let value = row.stringValue(key: "FREE_DEPTH_ALARM3").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kFreeDepth3Alarm:
            let value = row.stringValue(key: "FREE_DEPTH_ALARM3").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
            
        case .kFreeTime1AlarmEnable:
            let value = row.stringValue(key: "FREE_TIME_ALARM1").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kFreeTime1Alarm:
            let value = row.stringValue(key: "FREE_TIME_ALARM1").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
            
        case .kFreeTime2AlarmEnable:
            let value = row.stringValue(key: "FREE_TIME_ALARM2").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kFreeTime2Alarm:
            let value = row.stringValue(key: "FREE_TIME_ALARM2").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
            
        case .kFreeTime3AlarmEnable:
            let value = row.stringValue(key: "FREE_TIME_ALARM3").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kFreeTime3Alarm:
            let value = row.stringValue(key: "FREE_TIME_ALARM3").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
            
            
        case .kFreeSI1AlarmEnable:
            let value = row.stringValue(key: "FREE_SI_ALARM1").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kFreeSI1Alarm:
            let value = row.stringValue(key: "FREE_SI_ALARM1").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
            
        case .kFreeSI2AlarmEnable:
            let value = row.stringValue(key: "FREE_SI_ALARM2").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kFreeSI2Alarm:
            let value = row.stringValue(key: "FREE_SI_ALARM2").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
            
        case .kFreeSI3AlarmEnable:
            let value = row.stringValue(key: "FREE_SI_ALARM3").toInt()
            if value == -1 { // OFF
                return [0x00]
            } else {
                return [0x01]
            }
        case .kFreeSI3Alarm:
            let value = row.stringValue(key: "FREE_SI_ALARM3").toInt()
            if value == -1 { // OFF thi khong can ghi
                return nil
            } else {
                return value.to2Bytes()
            }
        default:
            return nil // Các trường như SerialNumber, FirmwareRev thường là Read-only
        }
    }
    
    func getWritePayloads(from row: Row, units: Int) -> [BluetoothDeviceCR5Manager.BleWriteConfig]? {
        switch self {
        case .kTimeAlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: true)]
            }
            return nil
        case .kTimeAlarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 0)]
            }
            return nil
        case .kDepthAlarmM:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: true, index: 0)]
            }
            return nil
        case .kDepthAlarmFT:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: true, index: 1)]
            }
            return nil
        case .kDepthAlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 0)]
            }
            return nil
            
        case .kFreeDepth1AlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 0)]
            }
            return nil
        case .kFreeDepth1Alarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: true, index: 0)]
            }
            return nil
            
        case .kFreeDepth2AlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 1)]
            }
            return nil
        case .kFreeDepth2Alarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: true, index: 1)]
            }
            return nil
            
        case .kFreeDepth3AlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 2)]
            }
            return nil
        case .kFreeDepth3Alarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: true, index: 2)]
            }
            return nil
            
        case .kFreeTime1AlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 0)]
            }
            return nil
        case .kFreeTime1Alarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 0)]
            }
            return nil
            
        case .kFreeTime2AlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 1)]
            }
            return nil
        case .kFreeTime2Alarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 1)]
            }
            return nil
            
        case .kFreeTime3AlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 2)]
            }
            return nil
        case .kFreeTime3Alarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 2)]
            }
            return nil
            
        case .kFreeSI1AlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 0)]
            }
            return nil
        case .kFreeSI1Alarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 0)]
            }
            return nil
            
        case .kFreeSI2AlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 1)]
            }
            return nil
        case .kFreeSI2Alarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 1)]
            }
            return nil
            
        case .kFreeSI3AlarmEnable:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 2)]
            }
            return nil
        case .kFreeSI3Alarm:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false, index: 2)]
            }
            return nil
        default:
            if let data = getWritePayload(from: row, units: units) {
                return [BluetoothDeviceCR5Manager.BleWriteConfig(payload: data, isReserved: false)] // Mặc định là true
            }
            return nil
        }
    }
}

extension BluetoothDeviceCR5Manager {
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
    
}

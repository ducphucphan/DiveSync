//
//  RomData.swift
//  teststruct
//
//  Created by Phan Duc Phuc on 6/25/25.
//

import Foundation

// MARK: - System Time (tương đương system_time_t)
struct SystemTime {
    var sec: UInt8        // Seconds after the minute: 0..59
    var min: UInt8        // Minutes after the hour: 0..59
    var hour: UInt8       // Hours past midnight: 0..23
    var wday: UInt8       // Day of the week: 0 (Sunday) .. 6 (Saturday)
    var mday: UInt8       // Day of the month: 1..31
    var mon: UInt8        // Month: 1..12
    var year: UInt16      // Year: 2000+
    
    init(sec: UInt8, min: UInt8, hour: UInt8, wday: UInt8, mday: UInt8, mon: UInt8, year: UInt16) {
        self.sec = sec
        self.min = min
        self.hour = hour
        self.wday = wday
        self.mday = mday
        self.mon = mon
        self.year = year
    }
    
    init(from date: Date) {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.second, .minute, .hour, .weekday, .day, .month, .year], from: date)
        self.sec = UInt8(components.second ?? 0)
        self.min = UInt8(components.minute ?? 0)
        self.hour = UInt8(components.hour ?? 0)
        self.wday = UInt8(((components.weekday ?? 1) - 1) % 7)
        self.mday = UInt8(components.day ?? 1)
        self.mon = UInt8(components.month ?? 1)
        self.year = UInt16(components.year ?? 2000)
    }
}

// MARK: - System Settings (tương đương system_settings_t)
struct SystemSettings {
    var resHeader: [UInt8] = Array(repeating: 0, count: 4) // 4 bytes
    var timeFormat: UInt8                            // 0: 24H, 1: 12H
    var dateFormat: UInt8                            // 0: DD/MM/YY, 1: MM/DD/YY
    var timeZoneIdxLocal: UInt8                      // Index * 2
    var timeZoneIdxHome: UInt8                       // Index * 2
    var units: UInt8                                 // 0: metric, 1: imperial
    var waterDensity: UInt8                          // 0: Salt, 1: Fresh
    var wetContacts: UInt8                           // 0: off, 1: on
    var bluetoothOn: UInt8                           // 0: off, 1: on
    var diveMode: UInt8                              // 0: Scuba, 3: Gauge
    var diveLogSamplingTime_s: UInt8                 // 2/10/20/60
    var res0: UInt8
    var res1: UInt8
    var res2: [UInt8] = Array(repeating: 0, count: 4) // 4 bytes
    var res3: [UInt8] = Array(repeating: 0, count: 4) // 4 bytes
    var backlightLevel: UInt8
    var backlightDimLevel: UInt8
    var backlightDimTime_s: UInt8
    var buzzerMode: UInt8
    var ecompassDeclination_deg: UInt8
    var language: UInt8
    var resFooter: [UInt8] = []
}

enum AltitudeLevel: UInt8 {
    case level0 = 0  // 0 - 3000FT
    case level1      // 3001FT - 5000FT
    case level2      // 5001FT - 7000FT
    case level3      // 7001FT - 9000FT
    case level4      // 9001FT - 11000FT
    case level5      // > 11000FT
}

struct DiveLog {
    var diveNo: UInt32
    var profileStartAddress: UInt32
    var profileSizeBytes: UInt32
    var diveStartLocalTime: SystemTime
    var diveEndLocalTime: SystemTime
    var totalDiveTime_s: Int32
    var surfTime_s: Int32
    var localTimeZoneIdx: UInt8
    var diveMode: UInt8
    var diveOfTheDay: UInt8
    var isDecoDive: UInt8
    var maxDepth_ft: Float
    var avgDepth_ft: Float
    var minTemperature_F: Float
    var maxTemperature_F: Float
    var samplingTime_s: UInt8
    var altitudeLevel: AltitudeLevel
    var startingMixIdx: UInt8
    var endingMixIdx: UInt8
    var endingTlbg: UInt8
    var endingOxTox_percent: UInt8
    var maxOxTox_percent: UInt8
    var maxAscentSpeed_lev: UInt8
    var errors: UInt32
    var maxPpo2: Float
    var startDiveTankPressure_Psi: UInt16
    var endDiveTankPressure_Psi: UInt16
    var avgMixConsumption_LtpMin: Float
    var gpsStartDive: Float
    var gpsEndDive: Float
    var gfHigh_percent: UInt8
    var gfLow_percent: UInt8
    var oxToxAlarm_percent: UInt8
    var tlbgAlarm: UInt8
    var ascentSpeedAlarm_fpm: Int16
    var diveTimeAlarm_minute: UInt16
    var depthAlarm_ft: UInt16
    var depthAlarm_mt: UInt16
    var noDecoTimeAlarm_minute: UInt8
    var safetyStopMode: UInt8
    var safetyStopTime_min: UInt8
    var safetyStopDepth_ft: UInt8
    var safetyStopDepth_mt: UInt8
    var deepStopMode: UInt8
    var deepStopTime_min: UInt8
    
    var mixFo2: [UInt8]  // 7 elements
    var mixFHe: [UInt8]  // 7 elements
    var mixPpo2BarX100: [UInt8]  // 7 elements
    
    var enabledMixes: UInt16
    var dummy: [UInt8]   // 60 bytes
    var res0: UInt8
    var res1: UInt8
    
    init() {
        diveNo = 0
        profileStartAddress = 0
        profileSizeBytes = 0
        diveStartLocalTime = SystemTime(from: Date())
        diveEndLocalTime = SystemTime(from: Date())
        totalDiveTime_s = 0
        surfTime_s = 0
        localTimeZoneIdx = 0
        diveMode = 0
        diveOfTheDay = 0
        isDecoDive = 0
        maxDepth_ft = 0
        avgDepth_ft = 0
        minTemperature_F = 0
        maxTemperature_F = 0
        samplingTime_s = 0
        altitudeLevel = .level0
        startingMixIdx = 0
        endingMixIdx = 0
        endingTlbg = 0
        endingOxTox_percent = 0
        maxOxTox_percent = 0
        maxAscentSpeed_lev = 0
        errors = 0
        maxPpo2 = 0
        startDiveTankPressure_Psi = 0
        endDiveTankPressure_Psi = 0
        avgMixConsumption_LtpMin = 0
        gpsStartDive = 0
        gpsEndDive = 0
        gfHigh_percent = 0
        gfLow_percent = 0
        oxToxAlarm_percent = 0
        tlbgAlarm = 0
        ascentSpeedAlarm_fpm = 0
        diveTimeAlarm_minute = 0
        depthAlarm_ft = 0
        depthAlarm_mt = 0
        noDecoTimeAlarm_minute = 0
        safetyStopMode = 0
        safetyStopTime_min = 0
        safetyStopDepth_ft = 0
        safetyStopDepth_mt = 0
        deepStopMode = 0
        deepStopTime_min = 0
        mixFo2 = Array(repeating: 0, count: 7)
        mixFHe = Array(repeating: 0, count: 7)
        mixPpo2BarX100 = Array(repeating: 0, count: 7)
        enabledMixes = 0
        dummy = Array(repeating: 0, count: 60)
        res0 = 0
        res1 = 0
    }
}

struct ComLogStats {
    var lastLogId: UInt32                         // Last saved Log Id
    var statsLogTotalDives: UInt32                // Total number of dives
    var statsTotalDive_s: UInt32                  // Total seconds of all dives
    var statsMaxDepth_ft: Float                   // Max Depth in feet
    var statsAvgDepth_ft: Float                   // Avg Depth in feet
    var statsMinTemperature_F: Float              // Min Temperature in Fahrenheit
    var statsMaxAltitudeLevel: AltitudeLevel      // Maximum Altitude Level (0-5)
    var res: (UInt8, UInt8, UInt8)                // 3 bytes reserved
    
    init() {
        lastLogId = 0
        statsLogTotalDives = 0
        statsTotalDive_s = 0
        statsMaxDepth_ft = 0
        statsAvgDepth_ft = 0
        statsMinTemperature_F = 0
        statsMaxAltitudeLevel = .level0
        res = (0, 0, 0)
    }
}

struct DiveLogProfile {
    var diveNo: UInt16                    // Incremental Dive ID
    var speedFpm: Int16                   // Speed in feet per minute
    var depthFt: Float                    // Dive Depth in feet
    var diveTime_s: Int32                 // Dive Time in seconds
    var temperatureF: Float               // Temperature in Fahrenheit
    var gfLocalPercent: UInt8            // Local Gradient Factor (%)
    var tlbg: UInt8                       // Tissue Load Bar Graph
    var oxToxPercent: UInt8              // Oxygen Toxicity Percentage
    var alarmId: UInt8                   // Occurred Alarm ID
    var ppO2_Barx100: UInt16             // Current PpO2 in bar × 100
    var currentUsedMixIdx: UInt8         // Current used mix index
    var switchMixFlag: UInt8             // 0: No Switch; 1: Switch suggested
    var tankPsi: UInt16                  // Tank pressure in psi
    var ndlMin: UInt16                   // No Deco Limit in minutes
    var decoStopDepthFt: UInt16          // Deepest Deco Stop Depth in feet
    var decoTimeMin: UInt16              // Deepest Deco Stop Time in minutes
    
    init() {
        diveNo = 0
        speedFpm = 0
        depthFt = 0
        diveTime_s = 0
        temperatureF = 0
        gfLocalPercent = 0
        tlbg = 0
        oxToxPercent = 0
        alarmId = 0
        ppO2_Barx100 = 0
        currentUsedMixIdx = 0
        switchMixFlag = 0
        tankPsi = 0
        ndlMin = 0
        decoStopDepthFt = 0
        decoTimeMin = 0
    }
}

enum DCResponseError: Error, CustomStringConvertible {
    case busy
    case corruptedFrame
    case wrongCommand
    case wrongLength
    case wrongData
    case logNotFound
    case profileNotFound
    case unknown(code: UInt8)

    var description: String {
        switch self {
        case .busy: return "Dive Computer is busy, not able to process command."
        case .corruptedFrame: return "CRC of received frame is not correct."
        case .wrongCommand: return "Command does not exist or no permission granted."
        case .wrongLength: return "Received frame length is not correct."
        case .wrongData: return "Data received in payload are not correct or out of allowed range."
        case .logNotFound: return "Requested Log ID not found on ExFlash."
        case .profileNotFound: return "Requested Profile sample not found on ExFlash."
        case .unknown(let code): return "Unknown error code: \(code)"
        }
    }

    static func from(code: UInt8) -> DCResponseError {
        switch code {
        case 0x01: return .busy
        case 0x02: return .corruptedFrame
        case 0x03: return .wrongCommand
        case 0x04: return .wrongLength
        case 0x05: return .wrongData
        case 0x06: return .logNotFound
        case 0x07: return .profileNotFound
        default:   return .unknown(code: code)
        }
    }
}

extension SystemSettings {
    func toData() -> Data {
            var bytes: [UInt8] = []
            bytes += resHeader
            bytes += [timeFormat, dateFormat, timeZoneIdxLocal, timeZoneIdxHome, units,
                      waterDensity, wetContacts, bluetoothOn, diveMode, diveLogSamplingTime_s,
                      res0, res1]
            bytes += res2
            bytes += res3
            bytes += [backlightLevel, backlightDimLevel, backlightDimTime_s,
                      buzzerMode, ecompassDeclination_deg, language]
            bytes += resFooter
            return Data(bytes)
        }
    
    static func from(data: Data) -> SystemSettings {
        var offset = 0

        func read<T: FixedWidthInteger>(_ type: T.Type) -> T {
            guard offset + MemoryLayout<T>.size <= data.count else { return 0 as! T }
            let value = data.subdata(in: offset..<offset + MemoryLayout<T>.size)
                .withUnsafeBytes { $0.load(as: T.self) }
            offset += MemoryLayout<T>.size
            return value
        }

        func readTuple4() -> (UInt8, UInt8, UInt8, UInt8) {
            return (read(UInt8.self), read(UInt8.self), read(UInt8.self), read(UInt8.self))
        }

        func readBytes(_ count: Int) -> [UInt8] {
            guard offset + count <= data.count else {
                let available = max(data.count - offset, 0)
                let part = data.subdata(in: offset..<offset + available)
                offset = data.count
                return Array(part) + Array(repeating: 0, count: count - available)
            }
            let slice = data.subdata(in: offset..<offset + count)
            offset += count
            return Array(slice)
        }

        let resHeader = readBytes(4)
        let timeFormat = read(UInt8.self)
        let dateFormat = read(UInt8.self)
        let timeZoneIdxLocal = read(UInt8.self)
        let timeZoneIdxHome = read(UInt8.self)
        let units = read(UInt8.self)
        let waterDensity = read(UInt8.self)
        let wetContacts = read(UInt8.self)
        let bluetoothOn = read(UInt8.self)
        let diveMode = read(UInt8.self)
        let diveLogSamplingTime_s = read(UInt8.self)
        let res0 = read(UInt8.self)
        let res1 = read(UInt8.self)
        let res2 = readBytes(4)
        let res3 = readBytes(4)
        let backlightLevel = read(UInt8.self)
        let backlightDimLevel = read(UInt8.self)
        let backlightDimTime_s = read(UInt8.self)
        let buzzerMode = read(UInt8.self)
        let ecompassDeclination_deg = read(UInt8.self)
        let language = read(UInt8.self)
        
        let resFooter = readBytes(data.count - offset)

        return SystemSettings(
            resHeader: resHeader,
            timeFormat: timeFormat,
            dateFormat: dateFormat,
            timeZoneIdxLocal: timeZoneIdxLocal,
            timeZoneIdxHome: timeZoneIdxHome,
            units: units,
            waterDensity: waterDensity,
            wetContacts: wetContacts,
            bluetoothOn: bluetoothOn,
            diveMode: diveMode,
            diveLogSamplingTime_s: diveLogSamplingTime_s,
            res0: res0,
            res1: res1,
            res2: res2,
            res3: res3,
            backlightLevel: backlightLevel,
            backlightDimLevel: backlightDimLevel,
            backlightDimTime_s: backlightDimTime_s,
            buzzerMode: buzzerMode,
            ecompassDeclination_deg: ecompassDeclination_deg,
            language: language,
            resFooter: resFooter
        )
    }
}

// MARK: - SCUBA SETTINGS
struct Mixes {
    var CurrGasNumber_OC: UInt8
    var CurrGasNumber_CC: UInt8
    var res1: UInt8
    var res2: UInt8

    var OC_FO2: [UInt8] = Array(repeating: 0, count: 8)
    var OC_FHe: [UInt8] = Array(repeating: 0, count: 8)
    var OC_Active: [UInt8] = Array(repeating: 0, count: 8)
    var OC_MaxPo2: [UInt8] = Array(repeating: 0, count: 8)
    var OC_ModFt: [UInt16] = Array(repeating: 0, count: 8)

    var CC_FO2: [UInt8] = Array(repeating: 0, count: 8)
    var CC_FHe: [UInt8] = Array(repeating: 0, count: 8)
    var CC_Active: [UInt8] = Array(repeating: 0, count: 8)
    var CC_MaxPo2: [UInt8] = Array(repeating: 0, count: 8)
    var CC_ModFt: [UInt16] = Array(repeating: 0, count: 8)
}

struct ScubaSettings {
    var recordTimeStamp_s: UInt32
    var mixes: Mixes

    var lastStopFt: UInt8
    var lastStopM: UInt8

    var gfLow: UInt8
    var gfHigh: UInt8

    var safetyStopMode: UInt8
    var safetyStopMin: UInt8
    var ssDepthFt: UInt8
    var ssDepthM: UInt8

    var noDecoAlarmMin: UInt8
    var oxToxAlarmPercent: UInt8

    var deepStopOn: UInt8
    var deepStopMin: UInt8

    var depthAlarmFt: UInt16
    var depthAlarmM: UInt16

    var diveTimeAlarmMin: UInt16
    var ascentSpeedAlarmFpm: UInt16

    var tlbgAlarm: UInt8
    var res: [UInt8] = []
}

extension ScubaSettings {
    func toData() -> Data {
            var data = Data()
            data.append(recordTimeStamp_s)
            data.append(contentsOf: mixes.toData())

            data.append(lastStopFt)
            data.append(lastStopM)

            data.append(gfLow)
            data.append(gfHigh)

            data.append(safetyStopMode)
            data.append(safetyStopMin)
            data.append(ssDepthFt)
            data.append(ssDepthM)

            data.append(noDecoAlarmMin)
            data.append(oxToxAlarmPercent)

            data.append(deepStopOn)
            data.append(deepStopMin)

            data.append(depthAlarmFt)
            data.append(depthAlarmM)

            data.append(diveTimeAlarmMin)
            data.append(ascentSpeedAlarmFpm)

            data.append(tlbgAlarm)
            data.append(contentsOf: res)

            return data
        }
    
    static func from(data: Data) throws -> ScubaSettings {
        var offset = 0
        
        func readUInt8() throws -> UInt8 {
            guard offset + 1 <= data.count else { throw ParseError.outOfBounds }
            defer { offset += 1 }
            return data[offset]
        }

        func readUInt16() throws -> UInt16 {
            guard offset + 2 <= data.count else { throw ParseError.outOfBounds }
            defer { offset += 2 }
            return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
        }

        func readInt16() throws -> UInt16 {
            let value = try readUInt16()
            return value
        }

        func readUInt32() throws -> UInt32 {
            guard offset + 4 <= data.count else { throw ParseError.outOfBounds }
            defer { offset += 4 }
            
            return UInt32(data[offset]) |
                   UInt32(data[offset + 1]) << 8 |
                   UInt32(data[offset + 2]) << 16 |
                   UInt32(data[offset + 3]) << 24
        }

        func readArray(_ count: Int) throws -> [UInt8] {
            guard offset + count <= data.count else { throw ParseError.outOfBounds }
            let slice = data[offset..<offset + count]
            offset += count
            return Array(slice)
        }

        func readUInt16Array(_ count: Int) throws -> [UInt16] {
            var result: [UInt16] = []
            for _ in 0..<count {
                result.append(try readUInt16())
            }
            return result
        }

        enum ParseError: Error {
            case outOfBounds
        }

        let timestamp = try readUInt32()

        let mixes = Mixes(
            CurrGasNumber_OC: try readUInt8(),
            CurrGasNumber_CC: try readUInt8(),
            res1: try readUInt8(),
            res2: try readUInt8(),
            OC_FO2: try readArray(8),
            OC_FHe: try readArray(8),
            OC_Active: try readArray(8),
            OC_MaxPo2: try readArray(8),
            OC_ModFt: try readUInt16Array(8),
            CC_FO2: try readArray(8),
            CC_FHe: try readArray(8),
            CC_Active: try readArray(8),
            CC_MaxPo2: try readArray(8),
            CC_ModFt: try readUInt16Array(8)
        )

        let lastStopFt = try readUInt8()
        let lastStopM = try readUInt8()
        let gfLow = try readUInt8()
        let gfHigh = try readUInt8()
        let safetyStopMode = try readUInt8()
        let safetyStopMin = try readUInt8()
        let ssDepthFt = try readUInt8()
        let ssDepthM = try readUInt8()
        let noDecoAlarmMin = try readUInt8()
        let oxToxAlarmPercent = try readUInt8()
        let deepStopOn = try readUInt8()
        let deepStopMin = try readUInt8()
        let depthAlarmFt = try readUInt16()
        let depthAlarmM = try readUInt16()
        let diveTimeAlarmMin = try readUInt16()
        let ascentSpeedAlarmFpm = try readInt16()
        let tlbgAlarm = try readUInt8()
        let res = Array(data[offset...])

        // Skip CRC if có
        // let crcMsb = try readUInt8()
        // let crcLsb = try readUInt8()

        return ScubaSettings(
            recordTimeStamp_s: timestamp,
            mixes: mixes,
            lastStopFt: lastStopFt,
            lastStopM: lastStopM,
            gfLow: gfLow,
            gfHigh: gfHigh,
            safetyStopMode: safetyStopMode,
            safetyStopMin: safetyStopMin,
            ssDepthFt: ssDepthFt,
            ssDepthM: ssDepthM,
            noDecoAlarmMin: noDecoAlarmMin,
            oxToxAlarmPercent: oxToxAlarmPercent,
            deepStopOn: deepStopOn,
            deepStopMin: deepStopMin,
            depthAlarmFt: depthAlarmFt,
            depthAlarmM: depthAlarmM,
            diveTimeAlarmMin: diveTimeAlarmMin,
            ascentSpeedAlarmFpm: ascentSpeedAlarmFpm,
            tlbgAlarm: tlbgAlarm,
            res: res
        )
    }
}

extension Mixes {
    func toData() -> Data {
        var data = Data()
        data.append(CurrGasNumber_OC)
        data.append(CurrGasNumber_CC)
        data.append(res1)
        data.append(res2)

        data.append(contentsOf: OC_FO2)
        data.append(contentsOf: OC_FHe)
        data.append(contentsOf: OC_Active)
        data.append(contentsOf: OC_MaxPo2)
        OC_ModFt.forEach { data.append($0) }

        data.append(contentsOf: CC_FO2)
        data.append(contentsOf: CC_FHe)
        data.append(contentsOf: CC_Active)
        data.append(contentsOf: CC_MaxPo2)
        CC_ModFt.forEach { data.append($0) }

        return data
    }
}

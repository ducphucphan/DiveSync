//
//  DiveLogMapper.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 10/20/25.
//

import Foundation
import GRDB

///
/// Do tren android và ios model_id định nghĩa khác nhau nên cần có hàm này để mapping.
///
func modelIDExport(modelId: Int) -> Int {
    switch modelId {
    case C_DAV:
        return 686586
    case C_SKI:
        return 837573
    case C_SPI:
        return 838073
    default:
        return modelId
    }
}

func modelIDImport(modelId: Int) -> Int {
    switch modelId {
    case 686586:
        return C_DAV
    case 837573:
        return C_SKI
    case 838073:
        return C_SPI
    default:
        return modelId
    }
}

struct DiveLogMapper: RowMapper {
    
    static func from(row: Row) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        func safeValue(_ value: String) -> String { value.isEmpty ? "0" : value }
        
        // MARK: - DiveLog mapping
        dict["UserID"] = row.stringValue(key: "UserID")
        dict["DiveSiteID"] = row.stringValue(key: "DiveSiteID")
        dict["ModelID"] = "\(modelIDExport(modelId: row.stringValue(key: "ModelID").toInt()))"
        dict["SerialNo"] = row.stringValue(key: "SerialNo")
        dict["DeviceName"] = row.stringValue(key: "DeviceName")
        dict["AddressID"] = row.stringValue(key: "AddressID")
        dict["ProfileStartAddress"] = row.stringValue(key: "ProfileStartAddress")
        dict["ProfileSizeBytes"] = row.stringValue(key: "ProfileSizeBytes")
        
        var DiveStartLocalTime = row.stringValue(key: "DiveStartLocalTime")
        DiveStartLocalTime = Utilities.convertDateFormat(from: DiveStartLocalTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: "MM/dd/yyyy HH:mm:ss")
        
        var DiveEndLocalTime = row.stringValue(key: "DiveEndLocalTime")
        DiveEndLocalTime = Utilities.convertDateFormat(from: DiveEndLocalTime, fromFormat: "dd/MM/yyyy HH:mm:ss", toFormat: "MM/dd/yyyy HH:mm:ss")
        
        dict["DiveStartLocalTime"] = DiveStartLocalTime
        dict["DiveEndLocalTime"] = DiveEndLocalTime
        dict["TotalDiveTime"] = row.stringValue(key: "TotalDiveTime")
        dict["SurfTime"] = row.stringValue(key: "SurfTime")
        dict["LocalTimeZoneID"] = row.stringValue(key: "LocalTimeZoneID")
        dict["DiveMode"] = row.stringValue(key: "DiveMode")
        dict["DiveOfTheDay"] = row.stringValue(key: "DiveOfTheDay")
        dict["DiveNoOfDay"] = row.stringValue(key: "DiveNo")
        dict["IsDecoDive"] = row.stringValue(key: "IsDecoDive")
        dict["MaxDepthFT"] = row.stringValue(key: "MaxDepthFT")
        dict["AvgDepthFT"] = row.stringValue(key: "AvgDepthFT")
        dict["MinTemperatureF"] = row.stringValue(key: "MinTemperatureF")
        dict["MaxTemperatureF"] = row.stringValue(key: "MaxTemperatureF")
        dict["SamplingTime"] = row.stringValue(key: "SamplingTime")
        dict["AltitudeLevel"] = row.stringValue(key: "AltitudeLevel")
        dict["StartingMixIdx"] = row.stringValue(key: "StartingMixIdx")
        dict["EndingMixIdx"] = row.stringValue(key: "EndingMixIdx")
        dict["EndingTlbg"] = row.stringValue(key: "EndingTlbg")
        dict["EndingOxToxPercent"] = row.stringValue(key: "EndingOxToxPercent")
        dict["MaxOxToxPercent"] = row.stringValue(key: "MaxOxToxPercent")
        dict["MaxAscentSpeedLev"] = row.stringValue(key: "MaxAscentSpeedLev")
        //dict["Errors"] = Utilities.to8BitBinaryString(row.stringValue(key: "Errors").toInt())
        dict["Errors"] =  row.stringValue(key: "Errors")
        dict["MaxPpo2"] = row.stringValue(key: "MaxPpo2")
        dict["StartDiveTankPressurePSI"] = row.stringValue(key: "StartDiveTankPressurePSI")
        dict["EndDiveTankPressurePSI"] = row.stringValue(key: "EndDiveTankPressurePSI")
        dict["AvgMixConsumption"] = row.stringValue(key: "AvgMixConsumption")
        dict["GPSEndDive"] = row.stringValue(key: "GPSEndDive")
        dict["GfHighPercent"] = row.stringValue(key: "GfHighPercent")
        dict["GfLowPercent"] = row.stringValue(key: "GfLowPercent")
        dict["OxToxAlarmPercent"] = row.stringValue(key: "OxToxAlarmPercent")
        dict["TlbgAlarm"] = row.stringValue(key: "TlbgAlarm")
        dict["AscentSpeedAlarm"] = row.stringValue(key: "AscentSpeedAlarm")
        dict["DiveTimeAlarm"] = row.stringValue(key: "DiveTimeAlarm")
        dict["DepthAlarmFT"] = row.stringValue(key: "DepthAlarmFT")
        dict["DepthAlarmMT"] = row.stringValue(key: "DepthAlarmMT")
        dict["NoDecoTimeAlarm"] = row.stringValue(key: "NoDecoTimeAlarm")
        dict["SafetyStopMode"] = row.stringValue(key: "SafetyStopMode")
        dict["SafetyStopTime"] = row.stringValue(key: "SafetyStopTime")
        dict["SafetyStopDepthFT"] = row.stringValue(key: "SafetyStopDepthFT")
        dict["SafetyStopDepthMT"] = row.stringValue(key: "SafetyStopDepthMT")
        dict["DeepStopMode"] = row.stringValue(key: "DeepStopMode")
        dict["DeepStopTime"] = row.stringValue(key: "DeepStopTime")
        
        // Mix fields
        dict["Mix1Fo2Percent"] = row.stringValue(key: "Mix1Fo2Percent")
        dict["Mix2Fo2Percent"] = row.stringValue(key: "Mix2Fo2Percent")
        dict["Mix3Fo2Percent"] = row.stringValue(key: "Mix3Fo2Percent")
        dict["Mix4Fo2Percent"] = row.stringValue(key: "Mix4Fo2Percent")
        dict["Mix5Fo2Percent"] = row.stringValue(key: "Mix5Fo2Percent")
        dict["Mix6Fo2Percent"] = row.stringValue(key: "Mix6Fo2Percent")
        dict["Mix7Fo2Percent"] = row.stringValue(key: "Mix7Fo2Percent")
        
        dict["Mix1FHePercent"] = row.stringValue(key: "Mix1FHePercent")
        dict["Mix2FHePercent"] = row.stringValue(key: "Mix2FHePercent")
        dict["Mix3FHePercent"] = row.stringValue(key: "Mix3FHePercent")
        dict["Mix4FHePercent"] = row.stringValue(key: "Mix4FHePercent")
        dict["Mix5FHePercent"] = row.stringValue(key: "Mix5FHePercent")
        dict["Mix6FHePercent"] = row.stringValue(key: "Mix6FHePercent")
        dict["Mix7FHePercent"] = row.stringValue(key: "Mix7FHePercent")
        
        dict["Mix1PpO2Barx100"] = row.stringValue(key: "Mix1PpO2Barx100")
        dict["Mix2PpO2Barx100"] = row.stringValue(key: "Mix2PpO2Barx100")
        dict["Mix3PpO2Barx100"] = row.stringValue(key: "Mix3PpO2Barx100")
        dict["Mix4PpO2Barx100"] = row.stringValue(key: "Mix4PpO2Barx100")
        dict["Mix5PpO2Barx100"] = row.stringValue(key: "Mix5PpO2Barx100")
        dict["Mix6PpO2Barx100"] = row.stringValue(key: "Mix6PpO2Barx100")
        dict["Mix7PpO2Barx100"] = row.stringValue(key: "Mix7PpO2Barx100")
        
        dict["EnabledMixes"] = Utilities.to8BitBinaryString(row.stringValue(key: "EnabledMixes").toInt())
        dict["Units"] = row.stringValue(key: "Units")
        dict["MaxTLBG"] = row.stringValue(key: "MaxTLBG")
        dict["DateFormat"] = safeValue(row.stringValue(key: "DateFormat"))
        dict["TimeFormat"] = safeValue(row.stringValue(key: "TimeFormat"))
        dict["Memo"] = row.stringValue(key: "Memo")
        
        // MARK: - Extra keys (not in table, default empty)
        dict["Favorites"] = row.intValue(key: "IsFavorite")
        dict["BuzzerMode"] = row.stringValue(key: "Sound")
        dict["WaterDensity"] = row.stringValue(key: "Water")
        dict["DiveStatus"] = ""
        if row.stringValue(key: "ModelID").toInt() == C_DAV {
            dict["BacklightLevel"] = row.stringValue(key: "BacklightDimTime")
        } else {
            dict["BacklightLevel"] = row.stringValue(key: "Light")
        }
        
        dict["TankTurnAlarmOn"] = safeValue(row.stringValue(key: "TankTurnAlarmOn"))
        dict["TankEndAlarmOn"] = safeValue(row.stringValue(key: "TankEndAlarmOn"))
        
        dict["TankEndAlarmBar"] = safeValue(row.stringValue(key: "TankEndAlarmBar"))
        dict["TankEndAlarmPsi"] = safeValue(row.stringValue(key: "TankEndAlarmPsi"))
        dict["TankTurnAlarmBar"] = safeValue(row.stringValue(key: "TankTurnAlarmBar"))
        dict["TankTurnAlarmPsi"] = safeValue(row.stringValue(key: "TankTurnAlarmPsi"))
        
        dict["DiveSiteName"] = ""
        dict["LifeTimeDiveNo"] = "0"
        
        
        let diveMode = row.stringValue(key: "DiveMode").toInt()
        if diveMode >= 100 {
            dict["ManualDive"] = "1"
            dict["MaxGAS"] = "3"
        } else {
            dict["ManualDive"] = "0"
            dict["MaxGAS"] = "4"
        }
        
        dict["GPSStartDive"] = ""
        dict["AvgTemperatureF"] = "0"
        
        // Thêm các field khác nếu cần
        return dict
    }
    
    // MARK: - Dictionary (JSON) → Dictionary cho DB insert
    static func toDatabaseDict(from json: [String: Any]) -> [String: DatabaseValueConvertible?] {
        var dbDict: [String: DatabaseValueConvertible?] = [:]
        
        let modelId = json["ModelID"] as! String
        
        let modelID = modelIDImport(modelId: modelId.toInt())
        
        // Map tất cả các field ngược lại
        dbDict["UserID"] = convertToDatabaseValue(json["UserID"])
        dbDict["DiveSiteID"] = convertToDatabaseValue(json["DiveSiteID"])
        dbDict["ModelID"] = convertToDatabaseValue(modelID)
        dbDict["SerialNo"] = convertToDatabaseValue(json["SerialNo"])
        dbDict["DeviceName"] = convertToDatabaseValue(json["DeviceName"])
        dbDict["AddressID"] = convertToDatabaseValue(json["AddressID"])
        dbDict["ProfileStartAddress"] = convertToDatabaseValue(json["ProfileStartAddress"])
        dbDict["ProfileSizeBytes"] = convertToDatabaseValue(json["ProfileSizeBytes"])
        
        var DiveStartLocalTime = json["DiveStartLocalTime"] as! String
        DiveStartLocalTime = Utilities.convertDateFormat(from: DiveStartLocalTime, fromFormat: "MM/dd/yyyy HH:mm:ss", toFormat: "dd/MM/yyyy HH:mm:ss")
        
        var DiveEndLocalTime = json["DiveEndLocalTime"] as! String
        DiveEndLocalTime = Utilities.convertDateFormat(from: DiveEndLocalTime, fromFormat: "MM/dd/yyyy HH:mm:ss", toFormat: "dd/MM/yyyy HH:mm:ss")
        
        dbDict["DiveStartLocalTime"] = convertToDatabaseValue(DiveStartLocalTime)
        dbDict["DiveEndLocalTime"] = convertToDatabaseValue(DiveEndLocalTime)
        
        dbDict["TotalDiveTime"] = convertToDatabaseValue(json["TotalDiveTime"])
        dbDict["SurfTime"] = convertToDatabaseValue(json["SurfTime"])
        dbDict["LocalTimeZoneID"] = convertToDatabaseValue(json["LocalTimeZoneID"])
        dbDict["DiveMode"] = convertToDatabaseValue(json["DiveMode"])
        dbDict["DiveOfTheDay"] = convertToDatabaseValue(json["DiveOfTheDay"])
        dbDict["DiveNo"] = convertToDatabaseValue(json["DiveNoOfDay"])
        dbDict["IsDecoDive"] = convertToDatabaseValue(json["IsDecoDive"])
        dbDict["MaxDepthFT"] = convertToDatabaseValue(json["MaxDepthFT"])
        dbDict["AvgDepthFT"] = convertToDatabaseValue(json["AvgDepthFT"])
        dbDict["MinTemperatureF"] = convertToDatabaseValue(json["MinTemperatureF"])
        dbDict["MaxTemperatureF"] = convertToDatabaseValue(json["MaxTemperatureF"])
        dbDict["SamplingTime"] = convertToDatabaseValue(json["SamplingTime"])
        dbDict["AltitudeLevel"] = convertToDatabaseValue(json["AltitudeLevel"])
        dbDict["StartingMixIdx"] = convertToDatabaseValue(json["StartingMixIdx"])
        dbDict["EndingMixIdx"] = convertToDatabaseValue(json["EndingMixIdx"])
        dbDict["EndingTlbg"] = convertToDatabaseValue(json["EndingTlbg"])
        dbDict["EndingOxToxPercent"] = convertToDatabaseValue(json["EndingOxToxPercent"])
        dbDict["MaxOxToxPercent"] = convertToDatabaseValue(json["MaxOxToxPercent"])
        dbDict["MaxAscentSpeedLev"] = convertToDatabaseValue(json["MaxAscentSpeedLev"])
        //dbDict["Errors"] = convertToDatabaseValue(Utilities.from8BitBinaryString(json["Errors"] as! String))
        dbDict["Errors"] = convertToDatabaseValue(json["Errors"])
        dbDict["MaxPpo2"] = convertToDatabaseValue(json["MaxPpo2"])
        dbDict["StartDiveTankPressurePSI"] = convertToDatabaseValue(json["StartDiveTankPressurePSI"])
        dbDict["EndDiveTankPressurePSI"] = convertToDatabaseValue(json["EndDiveTankPressurePSI"])
        dbDict["AvgMixConsumption"] = convertToDatabaseValue(json["AvgMixConsumption"])
        dbDict["GPSEndDive"] = convertToDatabaseValue(json["GPSEndDive"])
        dbDict["GfHighPercent"] = convertToDatabaseValue(json["GfHighPercent"])
        dbDict["GfLowPercent"] = convertToDatabaseValue(json["GfLowPercent"])
        dbDict["OxToxAlarmPercent"] = convertToDatabaseValue(json["OxToxAlarmPercent"])
        dbDict["TlbgAlarm"] = convertToDatabaseValue(json["TlbgAlarm"])
        dbDict["AscentSpeedAlarm"] = convertToDatabaseValue(json["AscentSpeedAlarm"])
        dbDict["DiveTimeAlarm"] = convertToDatabaseValue(json["DiveTimeAlarm"])
        dbDict["DepthAlarmFT"] = convertToDatabaseValue(json["DepthAlarmFT"])
        dbDict["DepthAlarmMT"] = convertToDatabaseValue(json["DepthAlarmMT"])
        dbDict["NoDecoTimeAlarm"] = convertToDatabaseValue(json["NoDecoTimeAlarm"])
        dbDict["SafetyStopMode"] = convertToDatabaseValue(json["SafetyStopMode"])
        dbDict["SafetyStopTime"] = convertToDatabaseValue(json["SafetyStopTime"])
        dbDict["SafetyStopDepthFT"] = convertToDatabaseValue(json["SafetyStopDepthFT"])
        dbDict["SafetyStopDepthMT"] = convertToDatabaseValue(json["SafetyStopDepthMT"])
        dbDict["DeepStopMode"] = convertToDatabaseValue(json["DeepStopMode"])
        dbDict["DeepStopTime"] = convertToDatabaseValue(json["DeepStopTime"])
        
        dbDict["Mix1Fo2Percent"] = convertToDatabaseValue(json["Mix1Fo2Percent"])
        dbDict["Mix2Fo2Percent"] = convertToDatabaseValue(json["Mix2Fo2Percent"])
        dbDict["Mix3Fo2Percent"] = convertToDatabaseValue(json["Mix3Fo2Percent"])
        dbDict["Mix4Fo2Percent"] = convertToDatabaseValue(json["Mix4Fo2Percent"])
        dbDict["Mix5Fo2Percent"] = convertToDatabaseValue(json["Mix5Fo2Percent"])
        dbDict["Mix6Fo2Percent"] = convertToDatabaseValue(json["Mix6Fo2Percent"])
        dbDict["Mix7Fo2Percent"] = convertToDatabaseValue(json["Mix7Fo2Percent"])
        
        dbDict["Mix1FHePercent"] = convertToDatabaseValue(json["Mix1FHePercent"])
        dbDict["Mix2FHePercent"] = convertToDatabaseValue(json["Mix2FHePercent"])
        dbDict["Mix3FHePercent"] = convertToDatabaseValue(json["Mix3FHePercent"])
        dbDict["Mix4FHePercent"] = convertToDatabaseValue(json["Mix4FHePercent"])
        dbDict["Mix5FHePercent"] = convertToDatabaseValue(json["Mix5FHePercent"])
        dbDict["Mix6FHePercent"] = convertToDatabaseValue(json["Mix6FHePercent"])
        dbDict["Mix7FHePercent"] = convertToDatabaseValue(json["Mix7FHePercent"])
                                                             
        dbDict["Mix1PpO2Barx100"] = convertToDatabaseValue(json["Mix1PpO2Barx100"])
        dbDict["Mix2PpO2Barx100"] = convertToDatabaseValue(json["Mix2PpO2Barx100"])
        dbDict["Mix3PpO2Barx100"] = convertToDatabaseValue(json["Mix3PpO2Barx100"])
        dbDict["Mix4PpO2Barx100"] = convertToDatabaseValue(json["Mix4PpO2Barx100"])
        dbDict["Mix5PpO2Barx100"] = convertToDatabaseValue(json["Mix5PpO2Barx100"])
        dbDict["Mix6PpO2Barx100"] = convertToDatabaseValue(json["Mix6PpO2Barx100"])
        dbDict["Mix7PpO2Barx100"] = convertToDatabaseValue(json["Mix7PpO2Barx100"])
        
        dbDict["EnabledMixes"] = convertToDatabaseValue(Utilities.from8BitBinaryString(json["EnabledMixes"] as! String))
        
        dbDict["Units"] = convertToDatabaseValue(json["Units"])
        dbDict["MaxGAS"] = convertToDatabaseValue(json["MaxGAS"])
        dbDict["MaxTLBG"] = convertToDatabaseValue(json["MaxTLBG"])
        dbDict["DateFormat"] = convertToDatabaseValue(json["DateFormat"])
        dbDict["TimeFormat"] = convertToDatabaseValue(json["TimeFormat"])
        dbDict["Memo"] = convertToDatabaseValue(json["Memo"])
        
        dbDict["IsFavorite"] = convertToDatabaseValue(json["Favorites"])
        dbDict["Sound"] = convertToDatabaseValue(json["BuzzerMode"])
        dbDict["Water"] = convertToDatabaseValue(json["WaterDensity"])
        
        if modelID == C_DAV {
            dbDict["BacklightDimTime"] = convertToDatabaseValue(json["BacklightLevel"])
        } else {
            dbDict["Light"] = convertToDatabaseValue(json["BacklightLevel"])
        }
        
        dbDict["TankTurnAlarmOn"] = convertToDatabaseValue(json["TankTurnAlarmOn"])
        dbDict["TankEndAlarmOn"] = convertToDatabaseValue(json["TankEndAlarmOn"])
        dbDict["TankTurnAlarmBar"] = convertToDatabaseValue(json["TankTurnAlarmBar"])
        dbDict["TankEndAlarmBar"] = convertToDatabaseValue(json["TankEndAlarmBar"])
        dbDict["TankTurnAlarmPsi"] = convertToDatabaseValue(json["TankTurnAlarmPsi"])
        dbDict["TankEndAlarmPsi"] = convertToDatabaseValue(json["TankEndAlarmPsi"])
        
        /*
         dict["DiveSiteName"] = ""
         dict["LifeTimeDiveNo"] = ""
         dict["ManualDive"] = ""
        */
        
        return dbDict
    }
    
    // MARK: - Insert 1 DiveLog duy nhất, trả về DiveID mới
    static func insert(_ json: [String: Any], db: Database) throws -> Int64 {
        let dict = toDatabaseDict(from: json)
        
        // ✅ Tự động tạo câu SQL từ keys
        let columns = dict.keys.joined(separator: ", ")
        let placeholders = dict.keys.map { ":\($0)" }.joined(separator: ", ")
        
        let sql = """
            INSERT INTO DiveLog (\(columns))
            VALUES (\(placeholders))
            """
        
        try db.execute(sql: sql, arguments: StatementArguments(dict))
        
        // ✅ Lấy DiveID vừa mới insert
        return db.lastInsertedRowID
    }
    
    // MARK: - Helper
    private static func convertToDatabaseValue(_ value: Any?) -> (any DatabaseValueConvertible)? {
        switch value {
        case let v as String: return v
        case let v as Int: return v
        case let v as Double: return v
        case let v as Float: return v
        case let v as Bool: return v
        case let v as Date: return v
        default: return nil
        }
    }
}

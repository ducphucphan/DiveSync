//
//  DiveProfileMapper.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 10/20/25.
//

import Foundation
import GRDB

struct DiveProfileMapper: RowMapper {
    static func from(row: Row) -> [String: Any] {
        
        func safeValue(_ value: String) -> String { value.isEmpty ? "0" : value }
        
        var dict: [String: Any] = [:]
        
        // MARK: - Có trong table
        dict["RowID"] = row.intValue(key: "RowID")
        dict["DiveID"] = row.intValue(key: "DiveID")
        dict["SpeedFpm"] = row.stringValue(key: "SpeedFpm")
        dict["DiveTime"] = row.stringValue(key: "DiveTime")
        dict["DepthMeters"] = String(format: "%.1f", Double(row.stringValue(key: "DepthFT").toInt()) / 10.0)
        dict["TemperatureC"] = String(format: "%.1f", Double(row.stringValue(key: "TemperatureF").toInt()) / 10.0)
        dict["GfLocalPercent"] = row.stringValue(key: "GfLocalPercent")
        dict["Tlbg"] = row.stringValue(key: "Tlbg")
        dict["OxToxPercent"] = row.stringValue(key: "OxToxPercent")
        dict["AlarmID1"] = row.stringValue(key: "AlarmID")
        dict["PpO2Barx100"] = row.stringValue(key: "PpO2Barx100")
        dict["CurrentUsedMixIdx"] = row.stringValue(key: "CurrentUsedMixIdx")
        dict["SwitchMixFlag"] = row.stringValue(key: "SwitchMixFlag")
        dict["NdlMin"] = row.stringValue(key: "NdlMin")
        dict["DecoStopDepthFT"] = row.stringValue(key: "DecoStopDepthFT")
        dict["DecoTime"] = row.stringValue(key: "DecoTime")
        dict["TankPSI"] = row.stringValue(key: "TankPSI")
        dict["TankAtrMin"] = safeValue(row.stringValue(key: "TankAtrMin"))
        dict["ActualTankID"] = safeValue(row.stringValue(key: "ActualTankID"))
        dict["AlarmID2"] = safeValue(row.stringValue(key: "AlarmID2"))
        
        return dict
    }
    
    static func alarmId1ToText(_ alarmId1: Int) -> String {
        var result: [String] = []
        
        let mapping: [Int: String] = [
            0: "ASCENT ALARM",
            1: "NO DECO TIME ALARM",
            2: "MAX DEPTH ALARM",
            3: "DIVE TIME REMAINING ALARM",
            4: "MAX OPERATING DEPTH ALARM",
            5: "OXYGEN TOXICITY ALARM",
            6: "OXYGEN TOXICITY 100% ALARM",
            7: "MISSED DECO STOP ALARM"
        ]
        
        for (bit, text) in mapping {
            if (alarmId1 & (1 << bit)) != 0 {
                result.append(text)
            }
        }
        return result.joined(separator: ", ")
    }
    
    static func alarmTextToId1(_ alarmsText: String) -> Int {
        let mapping: [Int: String] = [
            0: "ASCENT ALARM",
            1: "NO DECO TIME ALARM",
            2: "MAX DEPTH ALARM",
            3: "DIVE TIME REMAINING ALARM",
            4: "MAX OPERATING DEPTH ALARM",
            5: "OXYGEN TOXICITY ALARM",
            6: "OXYGEN TOXICITY 100% ALARM",
            7: "MISSED DECO STOP ALARM"
        ]
        
        // Tách chuỗi theo dấu phẩy và loại bỏ khoảng trắng dư
        let alarms = alarmsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        
        var value = 0
        for (bit, text) in mapping {
            if alarms.contains(text.uppercased()) {
                value |= (1 << bit)
            }
        }
        return value
    }
    
    static func alarmId2ToText(_ alarmId1: Int) -> String {
        var result: [String] = []
        
        let mapping: [Int: String] = [
            0: "DEPTH RANGE ALARM",
            1: "LONG DIVE ALARM",
            2: "DECO STOP 200FT ALARM",
            3: "LOW BATTERY WARNING ALARM",
            4: "LOW BATTERY ALARM",
            5: "PROFALR2_RES_0",
            6: "PROFALR2_RES_1",
            7: "PROFALR2_RES_2"
        ]
        
        for (bit, text) in mapping {
            if (alarmId1 & (1 << bit)) != 0 {
                result.append(text)
            }
        }
        return result.joined(separator: ", ")
    }
    
    static func alarmTextToId2(_ alarmsText: String) -> Int {
        let mapping: [Int: String] = [
            0: "DEPTH RANGE ALARM",
            1: "LONG DIVE ALARM",
            2: "DECO STOP 200FT ALARM",
            3: "LOW BATTERY WARNING ALARM",
            4: "LOW BATTERY ALARM",
            5: "PROFALR2_RES_0",
            6: "PROFALR2_RES_1",
            7: "PROFALR2_RES_2"
        ]
        
        // Tách chuỗi theo dấu phẩy và loại bỏ khoảng trắng dư
        let alarms = alarmsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
        
        var value = 0
        for (bit, text) in mapping {
            if alarms.contains(text.uppercased()) {
                value |= (1 << bit)
            }
        }
        return value
    }
    
    // MARK: - JSON → Dictionary cho DB (1 row)
    static func toDatabaseDict(from json: [String: Any]) -> [String: (any DatabaseValueConvertible)?] {
        var dbDict: [String: (any DatabaseValueConvertible)?] = [:]
        
        func map(_ key: String, _ alias: String? = nil) {
            let value = json[alias ?? key]
            dbDict[key] = convertToDatabaseValue(value)
        }
        
        map("SpeedFpm")
        
        if let meters = json["DepthMeters"] as? Double {
            dbDict["DepthFT"] = meters * 10.0
        } else if let str = json["DepthMeters"] as? String, let meters = Double(str) {
            dbDict["DepthFT"] = meters * 10.0
        } else {
            dbDict["DepthFT"] = nil
        }
        
        if let temperature = json["TemperatureC"] as? Double {
            dbDict["TemperatureF"] = temperature * 10.0
        } else if let str = json["TemperatureC"] as? String, let temperature = Double(str) {
            dbDict["TemperatureF"] = temperature * 10.0
        } else {
            dbDict["TemperatureF"] = nil
        }
        
        map("DiveTime")
        map("GfLocalPercent")
        map("Tlbg")
        map("OxToxPercent")
        
        if let alarmString = json["AlarmID1"] as? String {
            dbDict["AlarmID"] = alarmString
        } else if let intVal = json["AlarmID1"] as? Int {
            // Đã là số bitmask
            dbDict["AlarmID"] = intVal
        } else {
            dbDict["AlarmID"] = 0
        }
        
        map("PpO2Barx100")
        map("CurrentUsedMixIdx")
        map("SwitchMixFlag")
        map("NdlMin")
        map("DecoStopDepthFT")
        map("DecoTime")
        map("TankPSI")
        map("TankAtrMin")
        map("ActualTankID")
        map("AlarmID2")
        
        return dbDict
    }
    
    // MARK: - JSON list → Insert nhiều row vào DB
    static func bulkInsert(forDiveID: Int, profiles: [[String: Any]], db: Database) throws {
        guard !profiles.isEmpty else { return }

        for json in profiles {
            var dict = toDatabaseDict(from: json)
            dict["DiveID"] = "\(forDiveID)"
            
            // ✅ Lấy tất cả key hợp lệ (có giá trị hoặc nil vẫn cần)
            let columns = dict.keys.joined(separator: ", ")
            let placeholders = dict.keys.map { ":\($0)" }.joined(separator: ", ")

            // ✅ Tự động tạo câu SQL
            let sql = """
            INSERT INTO DiveProfile (\(columns))
            VALUES (\(placeholders))
            """

            try db.execute(sql: sql, arguments: StatementArguments(dict))
        }
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

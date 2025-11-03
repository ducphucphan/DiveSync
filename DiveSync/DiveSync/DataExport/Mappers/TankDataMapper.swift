//
//  TankDataMapper.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 10/20/25.
//

import Foundation
import GRDB

struct TankDataMapper: RowMapper {
    static func from(row: Row) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        // Helper lấy giá trị từ row
        func stringValue(_ key: String) -> String {
            row.stringValue(key: key)
        }
        
        func doubleValue(_ key: String) -> Double {
            row.stringValue(key: key).toDouble()
        }
        
        // Lấy TankUnit
        let tankUnit = row.intValue(key: "TankUnit")  // 0 = metric, 1 = imperial
        
        // Convert FT → M
        func convertDepth(_ value: Double) -> Double {
            return (tankUnit == M) ? converFeet2Meter(value) : value
        }
        
        // Convert PSI → BAR
        func convertPressure(_ value: Double) -> Double {
            return (tankUnit == M) ? convertPSI2BAR(value) : value
        }
        
        func convertCylinderSize(_ value: Double) -> Double {
            return (tankUnit == M) ? convertCUFT2L(value) : value   // CUFT -> L
        }
        
        // Fill dữ liệu cơ bản
        dict["TankID"] = row.intValue(key: "TankID")
        dict["TankNo"] = stringValue("TankNo")
        dict["TankUnit"] = tankUnit
        dict["DiveID"] = row.stringValue(key: "DiveID")
        dict["TankType"] = stringValue("TankType")
        dict["BreathingMinutes"] = stringValue("BreathingMinutes")
        dict["BreathingSeconds"] = stringValue("BreathingSeconds")
        
        dict["CylinderSize"] = String(format: "%.0f %@", convertCylinderSize(doubleValue("CylinderSize")), tankUnit == M ? "L" : "CUFT")
        
        // Convert Pressure fields
        dict["WorkingPressure"] = String(format: "%.0f %@", convertPressure(doubleValue("WorkingPressure")), tankUnit == M ? "BAR" : "PSI")
        dict["StartPressure"] = String(format: "%.0f %@", convertPressure(doubleValue("StartPressure")), tankUnit == M ? "BAR" : "PSI")
        dict["EndPressure"] = String(format: "%.0f %@", convertPressure(doubleValue("EndPressure")), tankUnit == M ? "BAR" : "PSI")
        
        // Convert Depth fields
        dict["MaxDepth"] = String(format: "%.0f %@", convertDepth(doubleValue("MaxDepth")), tankUnit == M ? "M" : "FT")
        dict["MinDepth"] = String(format: "%.0f %@", convertDepth(doubleValue("MinDepth")), tankUnit == M ? "M" : "FT")
        dict["AvgDepth"] = String(format: "%.0f %@", convertDepth(doubleValue("AvgDepth")), tankUnit == M ? "M" : "FT")
        
        return dict
    }
    
    // MARK: - JSON → Dictionary cho DB (1 row)
    static func toDatabaseDict(from json: [String: Any]) -> [String: (any DatabaseValueConvertible)?] {
        var dbDict: [String: (any DatabaseValueConvertible)?] = [:]
        
        func stringValue(_ key: String) -> String {
            (json[key] as? String) ?? "\(json[key] ?? "")"
        }
        
        // Lấy đơn vị tank
        let tankUnit = ((json["TankUnit"] as? String) ?? "0").toInt()  // 0 = metric, 1 = imperial (feet/psi)
        
        // Convert M → FT
        func convertDepth(_ value: String) -> Double? {
            guard let number = Double(value.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces).first ?? "") else { return nil }
            return (tankUnit == M) ? convertMeter2Feet(number) : number
        }
        
        // Convert BAR → PSI
        func convertPressure(_ value: String) -> Double? {
            guard let number = Double(value.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces).first ?? "") else { return nil }
            return (tankUnit == M) ? convertUBAR2PSI(number) : number
        }
        
        // Convert L → CUFT
        func convertCylinderSize(_ value: String) -> Double? {
            guard let number = Double(value.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces).first ?? "") else { return nil }
            return (tankUnit == M) ? convertL2CUFT(number) : number
        }
        
        func map(_ key: String, _ alias: String? = nil) {
            let k = alias ?? key
            let rawValue = stringValue(k)
            let value = rawValue.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .first ?? rawValue
            
            // Xử lý theo từng loại field
            switch k {
            case "MaxDepth", "MinDepth", "AvgDepth":
                if let v = convertDepth(rawValue) {
                    dbDict[key] = convertToDatabaseValue(v)
                    return
                }
            case "WorkingPressure", "StartPressure", "EndPressure":
                if let v = convertPressure(rawValue) {
                    dbDict[key] = convertToDatabaseValue(v)
                    return
                }
            case "CylinderSize":
                if let v = convertCylinderSize(rawValue) {
                    dbDict[key] = convertToDatabaseValue(v)
                    return
                }
            default:
                break
            }
            
            dbDict[key] = convertToDatabaseValue(value)
        }
        
        // Map các field
        map("TankNo")
        map("TankUnit")
        map("CylinderSize")
        map("WorkingPressure")
        map("TankType")
        map("StartPressure")
        map("EndPressure")
        map("BreathingMinutes")
        map("BreathingSeconds")
        map("MaxDepth")
        map("MinDepth")
        map("AvgDepth")
        
        return dbDict
    }
    
    // MARK: - JSON list → Insert nhiều row vào DB
    static func bulkInsert(forDiveID: Int, tankDatas: [[String: Any]], db: Database) throws {
        guard !tankDatas.isEmpty else { return }

        for json in tankDatas {
            var dict = toDatabaseDict(from: json)
            dict["DiveID"] = "\(forDiveID)"

            // ✅ Lấy tất cả key hợp lệ (có giá trị hoặc nil vẫn cần)
            let columns = dict.keys.joined(separator: ", ")
            let placeholders = dict.keys.map { ":\($0)" }.joined(separator: ", ")

            // ✅ Tự động tạo câu SQL
            let sql = """
            INSERT INTO TankData (\(columns))
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

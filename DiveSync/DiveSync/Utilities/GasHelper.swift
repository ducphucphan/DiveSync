//
//  GasHelper.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 10/9/26.
//

import Foundation

struct GasHelper {
    /// Danh sách options cho Picker FO2: ["AIR", "EAN22", "EAN23", ..., "EAN99"]
    static let fo2Options: [String] = (21...99).map { $0 == 21 ? "AIR" : "EAN\($0)" }
    
    /// Chuyển từ Int FO2 -> String ("AIR" hoặc "EAN32")
    static func formatFO2(_ fo2: Int) -> String {
        return fo2 <= 21 ? "AIR" : "EAN\(fo2)"
    }
    
    /// Chuyển từ String FO2 ("AIR" hoặc "EAN32") -> Int (21 hoặc 32)
    static func parseFO2(_ string: String) -> Int {
        if string == "AIR" { return 21 }
        let digits = string.replacingOccurrences(of: "EAN", with: "")
        return Int(digits) ?? 21
    }
}

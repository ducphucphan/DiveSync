//
//  DcInfo.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 2/24/25.
//

import Foundation

class DcInfo {
    // Property để lưu danh sách các alarm
    var dcInfos: [String:[String]] = [:]
    
    // Singleton
    static let shared = DcInfo()
    
    // Private initializer để đảm bảo chỉ có một instance
    private init() {
        loadDcInfo()
    }
    
    private func loadDcInfo() {
        if let url = Bundle.main.url(forResource: "dc_info", withExtension: "plist"),
           let data = try? Data(contentsOf: url) {
            do {
                if let plistDict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                    for (key, value) in plistDict {
                        if let array = value as? [String] {
                            dcInfos[key] = array
                        }
                    }
                }
            } catch {
                PrintLog("Lỗi khi đọc file plist: \(error)")
            }
        }
    }
    
    func getValues(forKey key: String? = nil) -> [String]? {
        guard let key = key else { return nil }
        return dcInfos[key]
    }
}

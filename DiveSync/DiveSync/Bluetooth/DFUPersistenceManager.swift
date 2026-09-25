//
//  DFUPendingDevice.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/14/26.
//

import Foundation

struct DFUPendingDevice: Codable {
    let macAddress: String
    let serialNumber: String
    let firmwareVersion: String
    let timestamp: Date
}

final class DFUPersistenceManager {
    static let shared = DFUPersistenceManager()
    private let userDefaultsKey = "BLE_PENDING_DFU_DEVICES_LIST"
    
    private init() {}
    
    // MARK: - 1. Lấy toàn bộ danh sách Pending (Dictionary: [MAC: Device])
    func getAllPendingUpdates() -> [String: DFUPendingDevice] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let dict = try? JSONDecoder().decode([String: DFUPendingDevice].self, from: data) else {
            return [:]
        }
        return dict
    }
    
    // MARK: - 2. Thêm/Cập nhật 1 thiết bị vào danh sách
    func savePendingUpdate(mac: String, serialNo: String, targetVersion: String) {
        var currentDict = getAllPendingUpdates()
        
        let device = DFUPendingDevice(
            macAddress: mac.uppercased(), // Chuẩn hóa chuỗi HOA
            serialNumber: serialNo,
            firmwareVersion: targetVersion,
            timestamp: Date()
        )
        
        currentDict[mac.uppercased()] = device
        saveToUserDefaults(dict: currentDict)
        PrintLog("💾 Đã lưu pending DFU cho MAC: \(mac) | Tổng số thiết bị chờ: \(currentDict.count)")
    }
    
    // MARK: - 3. Tìm 1 thiết bị cụ thể theo MAC Address
    func getPendingDevice(forMAC mac: String) -> DFUPendingDevice? {
        let currentDict = getAllPendingUpdates()
        return currentDict[mac.uppercased()]
    }
    
    // MARK: - 4. Xóa 1 thiết bị sau khi Update thành công
    func clearPendingUpdate(forMAC mac: String) {
        var currentDict = getAllPendingUpdates()
        currentDict.removeValue(forKey: mac.uppercased())
        saveToUserDefaults(dict: currentDict)
        PrintLog("🧹 Đã xóa DFU pending cho MAC: \(mac) | Còn lại: \(currentDict.count)")
    }
    
    // MARK: - 5. Dọn dẹp các thiết bị quá hạn (Ví dụ quá 48 giờ)
    func cleanupExpiredDevices(olderThanHours hours: Double = 48) {
        var currentDict = getAllPendingUpdates()
        let now = Date()
        
        let filtered = currentDict.filter { (_, device) in
            let hoursPassed = now.timeIntervalSince(device.timestamp) / 3600
            return hoursPassed < hours
        }
        
        if filtered.count != currentDict.count {
            saveToUserDefaults(dict: filtered)
            print("🧹 Đã dọn dẹp các thiết bị pending quá hạn.")
        }
    }
    
    // Private Helper
    private func saveToUserDefaults(dict: [String: DFUPendingDevice]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

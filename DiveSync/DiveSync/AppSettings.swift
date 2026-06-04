//
//  AppSettings.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/8/25.
//

import Foundation

enum ListDisplayMode: String {
    case normal = "normal"
    case group = "group"
}

final class AppSettings {
    static let shared = AppSettings()
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Generic Get/Set
    
    func set<T>(_ value: T?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func get<T>(forKey key: String) -> T? {
        return userDefaults.object(forKey: key) as? T
    }
    
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    func exists(forKey key: String) -> Bool {
        return userDefaults.object(forKey: key) != nil
    }
}

extension AppSettings {
    enum Keys {
        static let autosyncDeviceIdentify = "autosyncDeviceIdentify"
        
        static let permissionIdentify = "permissionIdentify"
        
        static let dateFormatIdentify = "dateFormatIdentify"
        
        static let timeFormatIdentify = "timeFormatIdentify"
        
        static let logsDisplayModeIdentify = "logsDisplayModeIdentify"
    }
    
    var logsDisplayMode: ListDisplayMode {
        get {
            // Lấy chuỗi String từ UserDefaults ra
            guard let modeStr: String = get(forKey: Keys.logsDisplayModeIdentify) else {
                return .normal // Mặc định nếu chưa từng lưu
            }
            // Chuyển đổi từ String sang Enum ListDisplayMode
            return ListDisplayMode(rawValue: modeStr) ?? .normal
        }
        set {
            // Lưu giá trị rawValue (String) của Enum vào UserDefaults
            set(newValue.rawValue, forKey: Keys.logsDisplayModeIdentify)
        }
    }
}

//
//  AppSettings.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/8/25.
//

import Foundation

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
    }
}

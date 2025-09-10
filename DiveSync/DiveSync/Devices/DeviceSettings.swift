//
//  DeviceSettings.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 6/11/25.
//

import Foundation



class DeviceSettings {
    static let shared = DeviceSettings()
    
    private init() { }
    
    // Các biến bạn muốn lưu trữ
    var unit: Int = 0 // M = 0, FT = 1
    var useSystemDateTime: Bool = false
    
}

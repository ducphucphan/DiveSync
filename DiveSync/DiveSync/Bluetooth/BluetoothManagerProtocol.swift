//
//  BluetoothManagerProtocol.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 3/6/26.
//

import Foundation

protocol BluetoothManagerProtocol: AnyObject {
    var ModelID: Int { get set } // Hoặc kiểu dữ liệu tương ứng của bạn
    func readAllSettings(completion: (() -> Void)?)
}

// Thêm dòng này:
extension BluetoothDeviceCRManager: BluetoothManagerProtocol {}

extension BluetoothDeviceCR4Manager: BluetoothManagerProtocol {}

extension BluetoothDeviceCR5Manager: BluetoothManagerProtocol {}

// Nếu bạn có class khác cũng có ModelID và readAllSettings:
extension BluetoothDataManager: BluetoothManagerProtocol {}

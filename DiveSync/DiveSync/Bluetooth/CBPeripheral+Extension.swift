//
//  CBPeripheral+Extension.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 8/29/25.
//

import Foundation
import RxBluetoothKit
import CoreBluetooth

extension CBPeripheral {
    /// Tách name thành prefix (chữ) và suffix (số), ví dụ: "SPECTER4" → ("SPECTER", "4")
    func splitDeviceName() -> (bleName: String, serialNumber: String)? {
        guard let name = self.name else { return nil }

        let pattern = #"^([A-Z]+)(\d+)$"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(name.startIndex..., in: name)
            if let match = regex.firstMatch(in: name, range: range),
               let bleNameRange = Range(match.range(at: 1), in: name),
               let serialNumberRange = Range(match.range(at: 2), in: name) {
                let bleName = String(name[bleNameRange])
                let serialNumber = String(name[serialNumberRange])
                return (bleName, serialNumber)
            }
        }
        return nil
    }
}

private var otaKey: UInt8 = 0
extension Peripheral {
    var isOta: Bool {
        get { objc_getAssociatedObject(self, &otaKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &otaKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

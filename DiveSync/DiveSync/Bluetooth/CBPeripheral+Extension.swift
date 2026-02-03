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
    /// Tách name thành prefix (chữ) và suffix (số)
    /// "SPECTER4" → ("SPECTER", "4")
    /// "AAAAAA"   → ("AAAAAA", "0")
    func splitDeviceName() -> (bleName: String, serialNumber: String)? {
        guard let name = self.name else { return nil }

        //let pattern = #"^([A-Z]+)(\d*)$"#   //  \d* = có hoặc không có số
        let pattern = #"^([A-Za-z\-+]+?)(\d*)$"#
        let regex = try? NSRegularExpression(pattern: pattern)

        let range = NSRange(name.startIndex..., in: name)
        guard
            let match = regex?.firstMatch(in: name, range: range),
            let bleNameRange = Range(match.range(at: 1), in: name)
        else {
            return nil
        }

        let bleName = String(name[bleNameRange])
        let serialNumber: String
        if match.range(at: 2).location != NSNotFound,
           let serialRange = Range(match.range(at: 2), in: name),
           !serialRange.isEmpty {
            serialNumber = String(name[serialRange])
        } else {
            serialNumber = "0"
        }

        return (bleName, serialNumber)
    }
}

private var otaKey: UInt8 = 0
extension Peripheral {
    var isOta: Bool {
        get { objc_getAssociatedObject(self, &otaKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &otaKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

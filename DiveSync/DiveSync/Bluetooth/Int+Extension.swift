//
//  Int+Extension.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 3/30/26.
//

import Foundation

extension Int {
    func to2Bytes() -> [UInt8] {
        return [
            UInt8(self & 0xFF),          // Byte thấp
            UInt8((self >> 8) & 0xFF)    // Byte cao
        ]
    }
}

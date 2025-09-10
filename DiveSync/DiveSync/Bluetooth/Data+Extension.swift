//
//  Data+Extension.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 3/18/25.
//

import Foundation

extension Data {
    subscript(int index: Int) -> Int {
        return Int(self[index]) // Chuyển UInt8 thành Int
    }
    
    mutating func setByte(_ value: UInt8, at index: Int) {
        guard index >= 0 && index < self.count else { return }
        self[index] = value
    }
    
    var hexString: String {
        return self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    
    mutating func append<T: FixedWidthInteger>(_ value: T) {
        var val = value.littleEndian
        Swift.withUnsafeBytes(of: &val) { buffer in
            append(contentsOf: buffer)
        }
    }
}

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

extension Data {
    func u8(_ offset: Int) -> Int {
        guard offset < self.count else { return 0 }
        return Int(self[offset])
    }
    
    func u16(_ offset: Int) -> Int {
        guard offset + 2 <= self.count else { return 0 }
        let value = self.subdata(in: offset..<offset+2).withUnsafeBytes {
            $0.load(as: UInt16.self)
        }
        return Int(UInt16(bigEndian: value))
    }
    
    func u32(_ offset: Int) -> Int {
        guard offset + 4 <= self.count else { return 0 }
        let value = self.subdata(in: offset..<offset+4).withUnsafeBytes {
            $0.load(as: UInt32.self)
        }
        return Int(UInt32(bigEndian: value))
    }
    
    func u16LE(_ offset: Int) -> Int {
        guard offset + 2 <= self.count else { return 0 }
        let value = self.subdata(in: offset..<offset+2).withUnsafeBytes {
            $0.load(as: UInt16.self)
        }
        return Int(UInt16(littleEndian: value))
    }
    
    func u32LE(_ offset: Int) -> Int {
        guard offset + 4 <= self.count else { return 0 }
        let value = self.subdata(in: offset..<offset+4).withUnsafeBytes {
            $0.load(as: UInt32.self)
        }
        return Int(UInt32(littleEndian: value))
    }
}

//
//  UInt8+Extension.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 7/7/25.
//

import Foundation

extension UInt8 {
    /// Trả về chuỗi số thập phân (ví dụ: "123")
    var decimalString: String {
        return String(self)
    }

    /// Trả về chuỗi hex (ví dụ: "FF")
    var hexString: String {
        return String(format: "%02X", self)
    }

    /// Trả về ký tự ASCII nếu hợp lệ (ví dụ: "A" nếu self là 65)
    var asciiCharacter: String {
        return String(UnicodeScalar(self))
    }
}

extension UInt16 {
    /// Trả về chuỗi số thập phân (ví dụ: "12345")
    var decimalString: String {
        return String(self)
    }

    /// Trả về chuỗi hex (ví dụ: "ABCD")
    var hexString: String {
        return String(format: "%04X", self)
    }

    /// Trả về ký tự Unicode nếu hợp lệ, ví dụ "A" nếu self == 65, hoặc nil nếu không hợp lệ
    var asciiCharacter: String? {
        guard let scalar = UnicodeScalar(self) else { return nil }
        return String(scalar)
    }

    /// Trả về chuỗi nhị phân
    var binaryString: String {
        return String(self, radix: 2)
    }
}

extension UInt32 {
    /// Trả về chuỗi thập phân (decimal string)
    var decimalString: String {
        return String(self)
    }

    /// Trả về chuỗi hex (ví dụ: "00000041")
    var hexString: String {
        return String(format: "%08X", self)
    }

    /// Trả về ký tự Unicode nếu hợp lệ (ví dụ: "A" nếu self == 65)
    var unicodeCharacter: String? {
        guard let scalar = UnicodeScalar(self) else { return nil }
        return String(scalar)
    }

    /// Trả về chuỗi nhị phân
    var binaryString: String {
        return String(self, radix: 2)
    }
    
}

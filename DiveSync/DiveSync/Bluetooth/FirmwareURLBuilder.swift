//
//  FirmwareURLBuilder.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/18/25.
//

import Foundation

struct FirmwareURLBuilder {
    static let base = "https://www.pelagicservices.com/firmware"
    
    static func iniFile() -> String {
        return "\(base)/PADAV_EN_Released.ini"
    }
    
    static func readmeFile() -> String {
        return "\(base)/PADAV_EN_Released.Readme"
    }
    
    static func binFile(version: String) -> String {
        // version: "1_0_74"
        return "\(base)/PROASIA/PADAV.\(version).bin"
    }
}

//
//  FirmwareURLBuilder.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/18/25.
//

import Foundation

struct FirmwareURLBuilder {
    static let base = "https://www.divesync.io"
    
    static func iniFile(modelId: Int) -> String {
        var fileName = "CREDAV"
        switch modelId {
        case C_SKI:
            fileName = "XSCSKI"
        case C_SPI:
            fileName = "OCESPI"
        default:
            fileName = "CREDAV"
        }
        
        return "\(base)/verifyfw.php?file=\(fileName)_EN_Released.ini"
    }
    
    static func readmeFile(modelId: Int) -> String {
        var fileName = "CREDAV"
        switch modelId {
        case C_SKI:
            fileName = "XSCSKI"
        case C_SPI:
            fileName = "OCESPI"
        default:
            fileName = "CREDAV"
        }
        
        return "\(base)/verifyfw.php?file=\(fileName)_EN_Released.Readme"
    }
    
    static func binFile(modelId: Int, version: String) -> String {
        
        var companyName = ""
        var fileName = ""
        switch modelId {
        case C_SKI:
            companyName = "XS_SCUBA"
            fileName = "XSCSKI.\(version)"
        case C_SPI:
            companyName = "OCEANPRO"
            fileName = "OCESPI.\(version)"
        default:
            companyName = "CRESSI"
            fileName = "CREDAV.\(version)"
        }
        
        // version: "1_0_74"
        
        ///getfile.php?file=COMPANY_NAME/filename.bin
        return "\(base)/getfile.php?file=\(companyName)/\(fileName).bin"
    }
}

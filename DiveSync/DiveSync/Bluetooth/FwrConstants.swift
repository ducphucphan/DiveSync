//
//  FwrConstants.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 9/15/25.
//

import Foundation

public struct FlashMemoryLayout {
    public let fistSector: UInt16
    public let nSector: UInt16
    public let sectorSize: UInt16

    public init(fistSector: UInt16, nSector: UInt16, sectorSize: UInt16) {
        self.fistSector = fistSector
        self.nSector = nSector
        self.sectorSize = sectorSize
    }
}


public let REBOOT_OTA_MODE: UInt8 = 0x01

public let APPLICATION_MEMORY: [FlashMemoryLayout] = [
    FlashMemoryLayout(fistSector: 0x00, nSector: 0x00, sectorSize: 0x0000), // Undef
    FlashMemoryLayout(fistSector: 0x07, nSector: 0xD0, sectorSize: 0x1000), // WB55 (4k)
    FlashMemoryLayout(fistSector: 0x0E, nSector: 0x44, sectorSize: 0x0800), // WB15 (2k)
    FlashMemoryLayout(fistSector: 0x40, nSector: 0x3D, sectorSize: 0x2000), // WBA
    FlashMemoryLayout(fistSector: 0x7F, nSector: 0x100, sectorSize: 0x0800), // WB09 (4k)
    FlashMemoryLayout(fistSector: 0x80, nSector: 0x7A, sectorSize: 0x2000)  // WBA6 ???
]

public let BLE_MEMORY: [FlashMemoryLayout] = [
    FlashMemoryLayout(fistSector: 0x000, nSector: 0x00, sectorSize: 0x0000), // Undef
    FlashMemoryLayout(fistSector: 0x11, nSector: 0xD0, sectorSize: 0x1000),  // WB55 (4k)
    FlashMemoryLayout(fistSector: 0x0E, nSector: 0x44, sectorSize: 0x0800),  // WB15 (2k)
    FlashMemoryLayout(fistSector: 0x7D, nSector: 0x3D, sectorSize: 0x2000),  // WBA (App&BLE chung binary)
    FlashMemoryLayout(fistSector: 0xFC, nSector: 0x100, sectorSize: 0x0800), // WB09 (2k)
    FlashMemoryLayout(fistSector: 0xFA, nSector: 0x7A, sectorSize: 0x2000)   // WBA6 (App&BLE chung binary)
]

// MARK: - Helper functions
public func getSectorToDelete() -> UInt16 {
    let mWB_board = 1
    return APPLICATION_MEMORY[mWB_board].fistSector
}

public func getNSectorToDelete(fileURL: URL) -> UInt16 {
    let mWB_board = 1
    
    // File size in Bytes
    let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.uint64Value ?? 0

    // File size in sectors
    let sectorSize = UInt64(APPLICATION_MEMORY[mWB_board].sectorSize)
    let sectorsForFileDimension = UInt16((fileSize + sectorSize - 1) / sectorSize)

    let maxSectorSelected = APPLICATION_MEMORY[mWB_board].nSector
    return sectorsForFileDimension < maxSectorSelected ? sectorsForFileDimension : maxSectorSelected
}

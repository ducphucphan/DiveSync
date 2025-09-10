//
//  SettingsSection.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 5/29/25.
//

import Foundation

struct SettingsSection: Codable {
    let title: String
    let rows: [SettingsRow]
}

class SettingsRow: Codable {
    let id: String?
    let title: String
    let type: SettingsRowType
    var value: String?
    let options: [String]?
    let options_ft: [String]?
    let safetyStopDepth_m: [String]?
    let safetyStopDepth_ft: [String]?
    let safetyStopTime: [String]?
    let icon: String?
    let destination: String? // nếu là dạng submenu thì dùng file json khác
    var disable: Int?
    var hidden: Int?
    var gasMod: Int?
    
    // ✅ Thêm dòng này để load được subRows
    var subRows: [SettingsRow]?
}

enum SettingsRowType: String, Codable {
    case subSection
    case date
    case time
    case modeSelector
    case gasSelector
    case twoValueSelector
    case action
    case toggle
    case inputText

    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = SettingsRowType(rawValue: value) ?? .unknown
    }
}

//
//  SortOptions.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 7/23/25.
//

import Foundation

enum SortDirection: String, Codable {
    case increasing
    case decreasing
}

enum SortField: String, Codable {
    case date
    case maxDepth
    case diveTime
}

struct SortOptions: Codable {
    var direction: SortDirection
    var field: SortField
    var favoritesOnly: Bool
}


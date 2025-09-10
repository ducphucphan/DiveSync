//
//  SortPreferences.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 7/23/25.
//

import Foundation

class SortPreferences {
    private static let key = "SortOptions"

    static func save(_ options: SortOptions) {
        if let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> SortOptions {
        if let data = UserDefaults.standard.data(forKey: key),
           let options = try? JSONDecoder().decode(SortOptions.self, from: data) {
            return options
        }

        // Default values
        return SortOptions(direction: .decreasing, field: .date, favoritesOnly: false)
    }
}

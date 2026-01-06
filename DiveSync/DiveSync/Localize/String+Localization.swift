//
//  String+Localization.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/22/25.
//

import Foundation

extension String {
    var localized: String {
        LocalizationManager.shared.localizedString(for: self)
    }
}

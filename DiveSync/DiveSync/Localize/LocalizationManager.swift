//
//  LocalizationManager.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/22/25.
//

import Foundation

final class LocalizationManager {

    static let shared = LocalizationManager()

    private let languageKey = "app_language"

    var currentLanguage: String {
        get {
            UserDefaults.standard.string(forKey: languageKey)
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: languageKey)
            NotificationCenter.default.post(
                name: .languageDidChange,
                object: nil
            )
        }
    }

    func localizedString(for key: String) -> String {
        guard let path = Bundle.main.path(
            forResource: currentLanguage,
            ofType: "lproj"
        ),
        let bundle = Bundle(path: path)
        else {
            return key
        }

        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

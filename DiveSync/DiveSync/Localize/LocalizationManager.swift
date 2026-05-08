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

extension LocalizationManager {
    // Định nghĩa danh sách cố định
    static let supportedLanguages: [(name: String, code: String)] = [
        ("🇺🇸 English", "en"),
        ("🇫🇷 French", "fr"),
        ("🇨🇳 简体中文", "zh-Hans"),
        ("🇩🇪 German", "de"),
        ("🇹🇷 Turkish", "tr"),
        ("🇮🇹 Italian", "it"),
        ("🇰🇷 한국어", "ko"),
        ("🇹🇼 繁體中文", "zh-Hant"),
        ("🇯🇵 日本語", "ja"),
        ("🇪🇸 Spanish", "es"),
        ("🇵🇹 Portuguese", "pt-PT")
    ]
    
    // Hàm bổ trợ để lấy tên hiển thị từ mã code (dùng cho Settings)
    func getLanguageName(for code: String) -> String {
        return LocalizationManager.supportedLanguages.first(where: { $0.code == code })?.name ?? "🇺🇸 English"
    }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

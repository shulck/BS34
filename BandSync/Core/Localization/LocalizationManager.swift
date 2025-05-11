//
//  LocalizationManager.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  LocalizationManager.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: Language = .english {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
            Bundle.setLanguage(currentLanguage.code)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "selectedLanguage")
        currentLanguage = Language(rawValue: saved ?? Language.english.rawValue) ?? .english
        Bundle.setLanguage(currentLanguage.code)
    }

    enum Language: String, CaseIterable, Identifiable {
        case english = "en"
        case ukrainian = "uk"
        case german = "de"

        var id: String { rawValue }

        var name: String {
            switch self {
            case .english: return "English"
            case .ukrainian: return "Українська"
            case .german: return "Deutsch"
            }
        }

        var code: String {
            rawValue
        }
    }
}

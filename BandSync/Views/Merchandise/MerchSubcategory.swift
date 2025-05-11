//
//  MerchSubcategory.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


import Foundation

enum MerchSubcategory: String, Codable, CaseIterable, Identifiable {
    // Subcategories for clothing
    case tshirt = "T-shirt"
    case hoodie = "Hoodie"
    case jacket = "Jacket"
    case cap = "Cap"

    // Subcategories for music
    case vinyl = "Vinyl Record"
    case cd = "CD"
    case tape = "Tape"

    // Subcategories for accessories
    case poster = "Poster"
    case sticker = "Sticker"
    case pin = "Pin"
    case keychain = "Keychain"

    // Other
    case other = "Other"

    var id: String { rawValue }

    // Add icon property used in the app
    var icon: String {
        switch self {
        case .tshirt: return "tshirt"
        case .hoodie: return "person.crop.circle"
        case .jacket: return "person.crop.square"
        case .cap: return "face.smiling"
        case .vinyl: return "opticaldiscdrive"
        case .cd: return "disc"
        case .tape: return "rectangle"
        case .poster: return "doc.richtext"
        case .sticker: return "note.text"
        case .pin: return "pin"
        case .keychain: return "key"
        case .other: return "ellipsis"
        }
    }

    // Get subcategories for a specific category
    static func subcategories(for category: MerchCategory) -> [MerchSubcategory] {
        switch category {
        case .clothing:
            return [.tshirt, .hoodie, .jacket, .cap]
        case .music:
            return [.vinyl, .cd, .tape]
        case .accessory:
            return [.poster, .sticker, .pin, .keychain]
        case .other:
            return [.other]
        }
    }
}